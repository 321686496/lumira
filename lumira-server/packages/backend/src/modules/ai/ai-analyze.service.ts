// lumira-server/packages/backend/src/modules/ai/ai-analyze.service.ts
// AI 识别编排（Task 5，Task 3 多输入增强）：示例图（可选）+ 文字描述（可选）→
// 有图走 visionChatJson（文字作补充要求）/ 仅文字走 textChatJson → normalizeDraft
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第三节/第五节

import { Injectable, BadRequestException, Optional } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { templateCategories } from '../../database/schema';
import { MAX_IMAGE_BYTES, UploadFile } from '../templates/admin-templates.service';
import { AiConfigService } from './ai-config.service';
import { visionChatJson, textChatJson, LlmJsonError } from './llm-json';
import {
  buildAnalyzeSystemPrompt,
  buildAnalyzeUserPrompt,
  buildTextOnlySystemPrompt,
  buildTextOnlyUserPrompt,
  inferSubjectCountHint,
} from './analyze.prompt';
import { normalizeDraft, CategoryNode } from './normalize';
import { AiOrchestratorService } from './ai-orchestrator.service';
import type { OrchestratorInput, OrchestratorTraceEntry } from './ai-orchestrator.service';
import type { ResearchItem } from './trend-research/research-item';
import type { ResearchBrief } from './trend-research/research-brief';
import { renderResearchBrief } from './trend-research/research-brief';
import type { ResearchImage } from './trend-research/research-image';
import type { ResearchVision } from './trend-research/research-vision';
import { buildResearchDigest, renderUserReferenceItems } from './trend-research/research-digest';
import { TrendResearchService, extractExplicitUrls } from './trend-research/trend-research.service';
import { renderResearchVision, visionHasContent } from './trend-research';
import { StyleProfileService, type StyleProfileResolveResult } from './style-profile.service';
import { traceNote, traceStep } from './llm-trace';

/** 允许的示例图 mimetype */
const ALLOWED_IMAGE_MIMES = ['image/jpeg', 'image/png', 'image/webp'];

/** 明确要求联网检索的意图词（命中 → 即使给了参考 URL 也走搜索） */
const SEARCH_INTENT_RE = /(搜索|联网|搜一|查一下|查一查|查找|上网搜|参考网络|网络趋势|看看网上)/;

/**
 * 联网检索必要性判定（纯启发式，规则即用户口径，零额外 LLM 调用）：
 * - 明确要求搜索 → 搜（无论是否给了参考 URL）；
 * - 提供了参考 URL 且未要求搜索 → 不搜（直接爬 URL 按网页内容创作）；
 * - 常规要求（无 URL）→ 搜。
 */
export function searchDecided(creationReq: string | null | undefined, textDesc: string): boolean {
  const req = `${creationReq ?? ''} ${textDesc}`;
  if (SEARCH_INTENT_RE.test(req)) return true;
  return extractExplicitUrls(req).length === 0;
}

export interface AiAnalyzeResult {
  draft: Record<string, unknown>;
  warnings: string[];
  /** 研究管线开启时由 orchestrator 返回；未开启/未接入时为 []（向后兼容） */
  trace: OrchestratorTraceEntry[];
  /** LLM 直接吐出的原始结构化 JSON（wrapper 解析后、normalizeDraft 前） */
  raw: Record<string, unknown>;
  /** 趋势研究阶段命中的来源（含 url） */
  research: ResearchItem[];
  /** 趋势研究二次整理后的结构化结论（供生图阶段复用）；未启用/未命中 → null */
  brief?: ResearchBrief | null;
  /** 抓取落盘的参考图（供后台时间线/结果弹窗展示；未启用为空数组） */
  researchImages?: ResearchImage[];
  /** 参考图多模态解读结论（未启用/失败为 null） */
  researchVision?: ResearchVision | null;
}

@Injectable()
export class AiAnalyzeService {
  constructor(
    private readonly dbService: DatabaseService,
    private readonly aiConfigService: AiConfigService,
    private readonly trendResearch: TrendResearchService,
    private readonly orchestrator?: AiOrchestratorService,
    @Optional() private readonly styleProfileService?: StyleProfileService,
  ) {}

  /**
   * 示例图（可选）+ 文字描述（可选）+ Step1 附加输入 → 模板草稿：
   * 校验（至少一项；text ≤ 1500 字；poseCount 1~9）→ 读活跃分类树 → 取启用配置（未配置 503）→
   * 图存在走 visionChatJson（extras 注入识别指令）/ 仅文字走 textChatJson → JSON 容错提取 → 归一化
   */
  async analyze(
    image: UploadFile | undefined,
    text: string | undefined,
    extra: { textDesc?: string | null; creationReq?: string | null; poseCount?: string | null; subjectCount?: string | null } = {},
  ): Promise<AiAnalyzeResult> {
    // 0. 姿势个数：'1'~'9' 整数字符串合法；其余（空/非法）= AI 自动判断
    let poseCount: number | null = null;
    if (extra.poseCount !== null && extra.poseCount !== undefined && extra.poseCount !== '') {
      const n = Number(extra.poseCount);
      if (!Number.isInteger(n) || n < 1 || n > 9) {
        throw new BadRequestException('poseCount 必须是 1~9 的整数（留空则由 AI 自动判断）');
      }
      poseCount = n;
    }

    const trimmedText = (text ?? '').trim();

    // 0.5 主体人数：'1'~'8' 整数字符串合法；其余（空/非法）= AI 自动推断
    let subjectCount: number | null = null;
    if (extra.subjectCount !== null && extra.subjectCount !== undefined && extra.subjectCount !== '') {
      const n = Number(extra.subjectCount);
      if (!Number.isInteger(n) || n < 1 || n > 8) {
        throw new BadRequestException('subjectCount 必须是 1~8 的整数（留空则由 AI 自动推断）');
      }
      subjectCount = n;
    }
    // 系统提示的措辞分档：显式指定优先，否则从用户输入预判（情侣/全家福等关键词）
    const subjectCountHint = subjectCount ?? inferSubjectCountHint(extra.creationReq, extra.textDesc, trimmedText);

    // 1. 输入校验：至少一项；text 长度；图 mimetype / 大小
    if (!image && !trimmedText) {
      throw new BadRequestException('请至少提供示例图或文字描述之一');
    }
    if (trimmedText.length > 1500) {
      throw new BadRequestException('文字描述不能超过 1500 字');
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

    // 3.4 风格定位：只判定一次，供草稿生成 / 编排 / 评审 / 生图分流（失败降级不阻断链路）
    let styleResolve: StyleProfileResolveResult | undefined;
    if (this.styleProfileService) {
      styleResolve = await this.styleProfileService.resolve({
        text: trimmedText,
        creationReq: extra.creationReq ?? undefined,
      });
    }
    const styleProfile = styleResolve?.profile;

    // 3.5 研究前置：搜索开启且主题非空 → 先搜后写草稿。
    //     检索命中后由文本模型二次整理成结构化结论（ResearchBrief），再把整理后的资料注入
    //     草稿生成提示词，让结构性数据（主题/风格/场景/姿势描述）贴合当下趋势；
    //     整理失败回退规则摘要，搜索失败静默降级（均不阻断识别）。
    //     主题口径与 orchestrator 一致：创作要求 ?? 文字描述。
    //     是否真正走搜索由 searchDecided 判定：明确要求搜索 → 搜；提供了参考 URL 且未要求
    //     搜索 → 跳过（直接依赖 3.6 参考网页抓取，按网页内容创作）；常规要求 → 搜。
    let research: ResearchItem[] = [];
    let researchBrief: ResearchBrief | null = null;
    let researchDigest = '';
    /** 抓取落盘的参考图 + 多模态解读结论（搜索/图片/解读任一未启用 → 空数组 / null） */
    let researchImages: ResearchImage[] = [];
    let researchVision: ResearchVision | null = null;
    /** 搜索开启且主题非空、但本次没取到任何条目（失败或空结果）→ 下游禁止编造时效信息 */
    let researchUnavailable = false;
    if (cfg.search?.enabled) {
      const topic = (extra.creationReq?.trim() || trimmedText).trim();
      if (topic && searchDecided(extra.creationReq, trimmedText)) {
        try {
          const r = await traceStep(
            'research',
            '趋势研究（联网检索）',
            () => this.trendResearch.research(topic, { limitPerSource: 5 }),
            (res) => (res.items.length ? `${res.items.length} 条参考来源${res.brief ? '（已二次整理）' : ''}` : '未取到来源'),
          );
          research = r.items;
          researchBrief = r.brief ?? null;
          researchImages = r.images ?? [];
          researchVision = r.vision ?? null;
          researchDigest = researchBrief ? renderResearchBrief(researchBrief) : buildResearchDigest(r.items);
        } catch {
          // 搜索失败 → 无摘要，草稿生成回到无研究参考的原路径
        }
        researchUnavailable = research.length === 0;
      } else if (topic) {
        // 提供了参考 URL 且未要求搜索：跳过联网检索，让面板可见原因
        traceNote('research', '跳过联网检索', '已提供参考 URL，直接按网页内容创作');
      }
    }

    // 3.6 用户显式参考页面：创作要求里直接给出的 URL（如「参考这个网站制作模板：https://...」）。
    //     这是用户的确定性指定来源，不受 search/images 开关限制：整页文本条目 + 整页多图落盘 +
    //     多模态解读一并合并进 research / researchImages / researchVision，
    //     并把网页图片解读结论注入草稿提示词（researchDigest），让大模型在构思时「看得到」网页内容。
    const explicitUrls = extractExplicitUrls(extra.creationReq ?? '');
    let userVision: ResearchVision | null = null;
    if (explicitUrls.length) {
      const topic = (extra.creationReq?.trim() || trimmedText).trim();
      try {
        const ref = await traceStep(
          'userReference',
          '参考网页抓取',
          () => this.trendResearch.userReference(explicitUrls, topic),
          (res) => `抓取 ${res.items.length} 条文本 / ${res.images.length} 张图${res.vision ? '（已解读）' : ''}`,
        );
        research.push(...ref.items);
        researchImages.push(...ref.images);
        if (ref.vision) userVision = ref.vision;
        // 用户指定 URL 的网页正文（接近全文）优先注入草稿提示词：模型必须按该网页的实际
        // 摄影内容创作（含服装/场景/动作/光线/参数等细节），其他趋势参考仅作部分加强
        if (ref.items.length) {
          const body = renderUserReferenceItems(ref.items);
          if (body) {
            researchDigest += researchDigest ? '\n' : '';
            researchDigest +=
              `【用户指定参考网页（必须严格遵守）】\n` +
              `创作要求的来源为以下网页，必须按其实际摄影内容创建模板，包括人物衣着、动作姿势、` +
              `场景与拍摄参数等细节；与下方其他网络趋势参考冲突时，以本网页为准，其余仅作部分加强：\n${body}`;
          }
        }
        if (ref.vision && visionHasContent(ref.vision)) {
          researchDigest += researchDigest ? '\n' : '';
          // 姿势优先级：网页正文已明确描述姿势时以正文为准；正文未描述姿势时，以配图解读为准
          researchDigest +=
            `【参考网页图片解读】（动作姿势优先级：上方正文已明确描述人物姿势时以正文为准；` +
            `正文未描述姿势时，以下方解读的「动作姿势」为准）\n${renderResearchVision(ref.vision)}`;
        }
        // 参考网页提供了一条确定性内容来源 → 不再视为「无参考」
        if (ref.items.length || ref.images.length) researchUnavailable = false;
      } catch {
        // 参考网页抓取失败：静默降级，不阻断识别
      }
      // 结果只携带一份解读：用户显式参考网页（确定性来源）优先，检索参考图解读兜底
      researchVision = userVision ?? researchVision;
    }

    // 4. 按输入组合分叉：有图走视觉模型，仅文字走文本模型；两者均带 JSON 有界重试
    let json: Record<string, unknown>;
    try {
      if (image) {
        json = await traceStep(
          'analyze',
          '识图生成模板草稿',
          () =>
            visionChatJson(
              cfg.vision,
              {
                systemPrompt: buildAnalyzeSystemPrompt(categories, styleProfile, subjectCountHint),
                userText: buildAnalyzeUserPrompt({
                  textDesc: extra.textDesc?.trim() || trimmedText || undefined,
                  creationReq: extra.creationReq,
                  poseCount,
                  subjectCount,
                  researchDigest,
                  researchUnavailable,
                }),
                imageBase64: image.buffer.toString('base64'),
                imageMime: image.mimetype,
                temperature: 0.3,
              },
              cfg.runtime,
            ),
          (r) => `模型输出 ${Object.keys(r).length} 个字段`,
        );
      } else {
        json = await traceStep(
          'analyze',
          '文字构思模板草稿',
          () =>
            textChatJson(
              cfg.text,
              {
                systemPrompt: buildTextOnlySystemPrompt(categories, styleProfile, subjectCountHint),
                userText: buildTextOnlyUserPrompt({
                  textDesc: trimmedText,
                  creationReq: extra.creationReq,
                  poseCount,
                  subjectCount,
                  researchDigest,
                  researchUnavailable,
                }),
                temperature: 0.3,
                // 不携带工具上下文：文字构思是单次 JSON 生成，若开启爬取工具，模型可能对创作要求里的
                // URL 反复发起 crawl 工具调用，一次草稿最多拖出多轮 LLM 调用（每轮 300s）导致「动不动超时」。
                // 用户显式 URL 的内容已由「参考网页抓取」确定性管线（userReference）预抓进 researchDigest，
                // 无需模型再主动爬取。
              },
              cfg.runtime,
            ),
          (r) => `模型输出 ${Object.keys(r).length} 个字段`,
        );
      }
    } catch (err) {
      // 重试用尽仍无法解析 → 保持原 400 引导重试语义
      if (err instanceof LlmJsonError) {
        throw new BadRequestException('模型输出无法解析为 JSON，请重试识别');
      }
      throw err;
    }

    // 6. 归一化（枚举校验 / 分类链校验 / 数值夹取，非法值丢弃并收集 warnings）
    //    风格档案写入草稿顶层，normalizeDraft 白名单已放行
    if (styleResolve) json.styleProfile = styleResolve.profile;
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
      const r = await this.orchestrator.run(input, { categories, draft: json, research, styleProfile: styleResolve });
      return {
        draft: r.draft,
        warnings: r.warnings,
        trace: r.trace,
        raw: json,
        research: r.research ?? [],
        brief: researchBrief,
        researchImages,
        researchVision,
      };
    }

    traceNote('finalize', '定稿归一化', `草稿就绪；修正提示 ${normalized.warnings.length} 条`);
    return { ...normalized, trace: [], raw: json, research, brief: researchBrief, researchImages, researchVision };
  }
}
