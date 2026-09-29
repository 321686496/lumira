// lumira-server/packages/backend/src/modules/ai/trend-research/research-vision.service.ts
// 参考图多模态解读（spec 第 6 章）：把抓到的 N 张参考图交给多模态模型，
// 产出结构化视觉结论（ResearchVision），失败/超时/解析失败一律 null（静默降级，不阻断识别）。

import { Injectable } from '@nestjs/common';
import { AiConfigService } from '../ai-config.service';
import { visionChatMulti } from '../llm-client';
import type { LlmEndpoint } from '../llm-client';
import { extractJson } from '../normalize';
import { describeTodayUtc8 } from '../../../common/utils/date.util';
import { traceStep } from '../llm-trace';
import { normalizeVision } from './research-vision';
import type { ResearchVision } from './research-vision';
import type { ResearchImage } from './research-image';

/** 单次解读最多带入的图片数（与抓取上限解耦，防止载荷过大） */
const MAX_IMAGES = 6;

const SYSTEM_PROMPT = [
  '你是资深人像摄影指导。用户会提供一组「从参考网站抓取到的图片」以及本次模板的创作意图。',
  '## 任务',
  '对照创作意图先逐张筛选值得参考的图，再只基于被采纳的图提炼结构化结论，用于指导拍摄/生图。',
  '## 规则',
  '1. 绝不编造：图片里没有的题材、人物、场景、道具一律不得出现；看不清就留空。',
  '2. 相关性筛选：逐张判断每张图「是否与创作意图相关且画面有可参考价值」（构图讲究、光线自然、美感在线、清晰可辨；截图/水印图/低质模糊/无关配图一律不采纳）。',
  '3. 每条结论写成简短名词短语（≤30 字），同义合并去重；不要整句照抄任何文案，也不要引用图中的文字/水印/账号名。',
  '4. 描述摄影语言而非评价好坏：风格倾向、色彩与光影、构图与机位、人物动作姿势、穿搭与妆造、场景与道具。人物动作姿势要具体（如侧身回眸、手扶栏杆、背靠墙面、蹲姿），不要写笼统的「摆 pose」。',
  '5. adopted 只登记「与创作意图相关且值得参考」的图：id 必须来自给定图片列表的 id，reason 用一句话说明为什么值得参考（可空数组）。',
  '6. 提炼铁律：styles / colorLight / composition / poseIdeas / wardrobe / scene 只能从 adopted 采纳的图中提炼，未被采纳的图不得贡献任何要点；adopted 为空则这些字段全部输出空数组、summary 输出空串。',
  '7. summary 用一句话概括被采纳参考图最有价值的共性（≤60 字）；没有价值就输出空串。',
  '## 输出',
  '只输出 JSON，不要 markdown 代码块或解释：',
  '{"summary":"","styles":[],"colorLight":[],"composition":[],"poseIdeas":[],"wardrobe":[],"scene":[],"adopted":[{"id":"","reason":""}]}',
].join('\n');

/** 渲染送入模型图片的 id 清单（让模型能按 id 采纳） */
function renderImageList(images: { image: ResearchImage; base64: string; mime: string }[]): string {
  return images
    .map((it, i) => `${i + 1}. id=${it.image.id}｜来源=${it.image.source}${it.image.query ? `｜检索词=${it.image.query}` : ''}`)
    .join('\n');
}

@Injectable()
export class ResearchVisionService {
  /** 测试可替换：默认走 visionChatMulti */
  chat: (
    images: { image: ResearchImage; base64: string; mime: string }[],
    topic: string,
    model: { text: LlmEndpoint },
  ) => Promise<string> = async (images, topic, model) =>
    visionChatMulti(model.text, {
      systemPrompt: SYSTEM_PROMPT,
      userText: [
        describeTodayUtc8(),
        `创作意图：${(topic || '').trim() || '（未提供）'}`,
        '',
        `参考图列表（共 ${images.length} 张，按顺序随消息附带）：`,
        renderImageList(images),
      ].join('\n'),
      images: images.map((it) => ({ base64: it.base64, mime: it.mime })),
      temperature: 0.3,
      jsonMode: true,
      // 多图解读可能慢响应（实测评审类调用可达 ~174s），120s 窗口会误杀导致解读静默失败，
      // 直接拉长到 10 分钟（失败仍由调用方 catch → null 兜底，不阻断流程）
      timeoutMs: 600_000,
    });

  constructor(private readonly aiConfigService: AiConfigService) {}

  /**
   * 多模态解读参考图。无图 / 未配置 / 失败 / 解析失败 → null。
   */
  async interpret(
    topic: string,
    images: { image: ResearchImage; base64: string; mime: string }[],
  ): Promise<ResearchVision | null> {
    if (!images.length) return null;
    const used = images.slice(0, MAX_IMAGES);
    try {
      const cfg = await this.aiConfigService.getActiveConfig();
      const vision = await traceStep(
        'researchVision',
        '参考图解读',
        async () => {
          const content = await this.chat(used, topic, { text: cfg.text });
          const allowed = new Set(used.map((it) => it.image.id));
          return normalizeVision(extractJson(content), allowed);
        },
        (v) =>
          v
            ? `采纳 ${v.adopted.length} 张 / 提炼 ${v.styles.length + v.colorLight.length + v.composition.length + v.poseIdeas.length + v.wardrobe.length + v.scene.length} 条视觉要点`
            : '解读失败（跳过）',
        (v) => ({ adoptedImageIds: v ? v.adopted.map((a) => a.id) : [] }),
      );
      return vision;
    } catch {
      return null;
    }
  }
}
