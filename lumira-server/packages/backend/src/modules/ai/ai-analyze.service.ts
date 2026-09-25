// lumira-server/packages/backend/src/modules/ai/ai-analyze.service.ts
// AI 识别编排（Task 5，Task 3 多输入增强）：示例图（可选）+ 文字描述（可选）→
// 有图走 visionChat（文字作补充要求）/ 仅文字走 textChat → extractJson → normalizeDraft
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第三节/第五节

import { Injectable, BadRequestException } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { templateCategories } from '../../database/schema';
import { MAX_IMAGE_BYTES, UploadFile } from '../templates/admin-templates.service';
import { AiConfigService } from './ai-config.service';
import { visionChat, textChat } from './llm-client';
import {
  buildAnalyzeSystemPrompt,
  buildAnalyzeUserPrompt,
  buildTextOnlySystemPrompt,
  buildTextOnlyUserPrompt,
} from './analyze.prompt';
import { extractJson, normalizeDraft, CategoryNode } from './normalize';
import { AiOrchestratorService } from './ai-orchestrator.service';
import type { OrchestratorInput, OrchestratorTraceEntry } from './ai-orchestrator.service';
import type { ResearchItem } from './trend-research/research-item';
import { renderResearchBrief } from './trend-research/research-brief';
import { buildResearchDigest } from './trend-research/research-digest';
import { TrendResearchService } from './trend-research/trend-research.service';
import { traceNote, traceStep } from './llm-trace';

/** 允许的示例图 mimetype */
const ALLOWED_IMAGE_MIMES = ['image/jpeg', 'image/png', 'image/webp'];

export interface AiAnalyzeResult {
  draft: Record<string, unknown>;
  warnings: string[];
  /** 研究管线开启时由 orchestrator 返回；未开启/未接入时为 []（向后兼容） */
  trace: OrchestratorTraceEntry[];
  /** LLM 直接吐出的原始结构化 JSON（extractJson 后、normalizeDraft 前） */
  raw: Record<string, unknown>;
  /** 趋势研究阶段命中的来源（含 url） */
  research: ResearchItem[];
}

@Injectable()
export class AiAnalyzeService {
  constructor(
    private readonly dbService: DatabaseService,
    private readonly aiConfigService: AiConfigService,
    private readonly trendResearch: TrendResearchService,
    private readonly orchestrator?: AiOrchestratorService,
  ) {}

  /**
   * 示例图（可选）+ 文字描述（可选）+ Step1 附加输入 → 模板草稿：
   * 校验（至少一项；text ≤ 500 字；poseCount 1~6）→ 读活跃分类树 → 取启用配置（未配置 503）→
   * 图存在走 visionChat（extras 注入识别指令）/ 仅文字走 textChat → JSON 容错提取 → 归一化
   */
  async analyze(
    image: UploadFile | undefined,
    text: string | undefined,
    extra: { textDesc?: string | null; creationReq?: string | null; poseCount?: string | null } = {},
  ): Promise<AiAnalyzeResult> {
    // 0. 姿势个数：'1'~'6' 整数字符串合法；其余（空/非法）= AI 自动判断
    let poseCount: number | null = null;
    if (extra.poseCount !== null && extra.poseCount !== undefined && extra.poseCount !== '') {
      const n = Number(extra.poseCount);
      if (!Number.isInteger(n) || n < 1 || n > 6) {
        throw new BadRequestException('poseCount 必须是 1~6 的整数（留空则由 AI 自动判断）');
      }
      poseCount = n;
    }

    // 1. 输入校验：至少一项；text 长度；图 mimetype / 大小
    const trimmedText = (text ?? '').trim();
    if (!image && !trimmedText) {
      throw new BadRequestException('请至少提供示例图或文字描述之一');
    }
    if (trimmedText.length > 500) {
      throw new BadRequestException('文字描述不能超过 500 字');
    }
    if (image) {
      if (!ALLOWED_IMAGE_MIMES.includes(image.mimetype)) {
        throw new BadRequestException('仅支持 jpg/png/webp 图片');
      }
      if (image.buffer.byteLength > MAX_IMAGE_BYTES) {
        const mb = (MAX_IMAGE_BYTES / 1024 / 1024).toFixed(0);
        throw new BadRequestException(`示例图不能超过 ${mb}MB（当前${(image.buffer.byteLength / 1024 / 1024).toFixed(2)}MB）`);
      }
    }

    // 2. 读 DB 活跃分类树（行结构直接匹配 CategoryNode）
    const db = this.dbService.getDb();
    const rows = await db.select().from(templateCategories).where(eq(templateCategories.isActive, 1));
    const categories: CategoryNode[] = rows.map((r) => ({
      key: r.key,
      name: r.name,
      parentKey: r.parentKey,
      level: r.level,
    }));

    // 3. 取启用配置（未配置/未启用 → 503 透传）
    const cfg = await this.aiConfigService.getActiveConfig();

    // 3.5 研究前置：搜索开启且主题非空 → 先搜后写草稿。
    //     检索命中后由文本模型二次整理成结构化结论（ResearchBrief），再把整理后的资料注入
    //     草稿生成提示词，让结构性数据（主题/风格/场景/姿势描述）贴合当下趋势；
    //     整理失败回退规则摘要，搜索失败静默降级（均不阻断识别）。
    //     主题口径与 orchestrator 一致：创作要求 ?? 文字描述。
    let research: ResearchItem[] = [];
    let researchDigest = '';
    /** 搜索开启且主题非空、但本次没取到任何条目（失败或空结果）→ 下游禁止编造时效信息 */
    let researchUnavailable = false;
    if (cfg.search?.enabled) {
      const topic = (extra.creationReq?.trim() || trimmedText).trim();
      if (topic) {
        try {
          const r = await traceStep(
            'research',
            '趋势研究（联网检索）',
            () => this.trendResearch.research(topic, { limitPerSource: 5 }),
            (res) => (res.items.length ? `${res.items.length} 条参考来源${res.brief ? '（已二次整理）' : ''}` : '未取到来源'),
          );
          research = r.items;
          const brief = r.brief ?? null;
          researchDigest = brief ? renderResearchBrief(brief) : buildResearchDigest(r.items);
        } catch {
          // 搜索失败 → 无摘要，草稿生成回到无研究参考的原路径
        }
        researchUnavailable = research.length === 0;
      }
    }

    // 4. 按输入组合分叉：有图走视觉模型（extras 注入识别指令），仅文字走文本模型
    let content: string;
    if (image) {
      content = await traceStep(
        'analyze',
        '识图生成模板草稿',
        () =>
          visionChat(cfg.vision, {
            systemPrompt: buildAnalyzeSystemPrompt(categories),
            userText: buildAnalyzeUserPrompt({
              textDesc: extra.textDesc?.trim() || trimmedText || undefined,
              creationReq: extra.creationReq,
              poseCount,
              researchDigest,
              researchUnavailable,
            }),
            imageBase64: image.buffer.toString('base64'),
            imageMime: image.mimetype,
            temperature: 0.3,
            jsonMode: true,
          }),
        (c) => `模型输出 ${c.length} 字`,
      );
    } else {
      content = await traceStep(
        'analyze',
        '文字构思模板草稿',
        () =>
          textChat(cfg.text, {
            systemPrompt: buildTextOnlySystemPrompt(categories),
            userText: buildTextOnlyUserPrompt({
              textDesc: trimmedText,
              creationReq: extra.creationReq,
              poseCount,
              researchDigest,
              researchUnavailable,
            }),
            temperature: 0.3,
            jsonMode: true,
          }),
        (c) => `模型输出 ${c.length} 字`,
      );
    }

    // 5. 容错提取 JSON（失败 → 400 引导重试识别）
    const json = extractJson(content);
    if (!json) {
      throw new BadRequestException('模型输出无法解析为 JSON，请重试识别');
    }

    // 6. 归一化（枚举校验 / 分类链校验 / 数值夹取，非法值丢弃并收集 warnings）
    const normalized = normalizeDraft(json, categories);

    // 7. 研究管线开启（orchestrator 已接入）→ 走 Agentic 再判：以单次识别草稿为基，
    //    由 orchestrator 追加 趋势研究 / 姿势面片 / 参数校准 / 评分闸门，返回 {draft,warnings,trace}。
    //    否则（研究关闭 / 未接入）保留原单次路径，向后兼容。
    if (cfg.search?.enabled && this.orchestrator) {
      const input: OrchestratorInput = {
        imageBase64: image ? image.buffer.toString('base64') : undefined,
        imageMime: image ? image.mimetype : undefined,
        text: trimmedText,
        creationReq: extra.creationReq ?? undefined,
        poseCount: poseCount ?? undefined,
      };
      const r = await this.orchestrator.run(input, { categories, draft: json, research });
      return { draft: r.draft, warnings: r.warnings, trace: r.trace, raw: json, research: r.research ?? [] };
    }

    traceNote('finalize', '定稿归一化', `草稿就绪；修正提示 ${normalized.warnings.length} 条`);
    return { ...normalized, trace: [], raw: json, research };
  }
}
