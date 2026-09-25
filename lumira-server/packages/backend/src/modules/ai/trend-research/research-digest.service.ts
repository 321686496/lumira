// lumira-server/packages/backend/src/modules/ai/trend-research/research-digest.service.ts
// 研究资料二次整理（LLM）：把联网检索命中的原始条目交给文本模型，提炼成结构化结论
// （ResearchBrief），避免「裸域名 / 排版残留 / 无关摘要」原样进入模板生成提示词。
//
// 工程约束：进程内 LRU 缓存（同主题重复识别不重复调用）；失败/超时/解析失败一律返回 null，
// 由调用方回退到规则摘要（research-digest.ts），不阻断识别。

import { Injectable } from '@nestjs/common';
import { AiConfigService } from '../ai-config.service';
import { textChat } from '../llm-client';
import { extractJson } from '../normalize';
import { describeTodayUtc8 } from '../../../common/utils/date.util';
import { traceStep } from '../llm-trace';
import { LruCache } from './lru-cache';
import { normalizeBrief } from './research-brief';
import type { ResearchBrief } from './research-brief';
import { selectResearchItems } from './research-digest';
import type { ResearchItem } from './research-item';

/** 整理结果缓存容量 */
const CACHE_MAX = 100;
/** 送入整理提示词的条目数上限 */
const MAX_SOURCE_ITEMS = 24;
/** 送入整理提示词的标题 / 摘要截断 */
const IN_TITLE_CAP = 80;
const IN_SNIPPET_CAP = 240;

const briefCache = new LruCache<ResearchBrief>(CACHE_MAX);

/** 清空整理结果缓存（测试隔离 / 维护用） */
export function clearResearchBriefCache(): void {
  briefCache.clear();
}

/** 简易 djb2 指纹（用于缓存 key，无需密码学强度） */
function fingerprint(s: string): string {
  let h = 5381;
  for (let i = 0; i < s.length; i++) h = ((h << 5) + h + s.charCodeAt(i)) | 0;
  return (h >>> 0).toString(36);
}

/** 缓存 key：主题 + 条目标题/摘要指纹（同主题同条目 → 命中缓存） */
export function buildBriefCacheKey(topic: string, items: ResearchItem[]): string {
  const body = items.map((i) => `${i.title || ''}|${i.snippet || ''}`).join('\n');
  return `${(topic || '').trim()}|${items.length}|${fingerprint(body)}`;
}

const SYSTEM_PROMPT = [
  '你负责把「联网检索命中的原始条目」二次整理成可直接用于摄影模板构思的结构化结论。',
  '## 规则',
  '1. 剔除无效内容：纯域名/导航页标题、只有站名没有正文的条目、排版残留（表格符号、栏目名、「阅读全文」「查看更多」等）、',
  '与创作意图明显无关的内容。这些绝不允许进入结论。',
  '2. 只保留能落到摄影模板字段上的信息：流行题材/主题、风格倾向、色彩与光线、可复现的视觉元素（场景/道具/服装/妆容）、',
  '时令与节日、姿势与构图灵感。',
  '3. 时间/节日/时令类信息必须换算成具体的年月表述（按今天的日期推算），不要保留「最近」「当下」「即将到来」这类无法检索的相对说法。',
  '4. 每条结论写成简短名词短语，不要整句照抄原文摘要；同义合并去重。',
  '5. 绝不编造条目中不存在的信息；条目不足以支撑某个维度时，该字段输出空数组。',
  '6. summary 用一句话概括这批资料对模板构思最有价值的结论（≤60 字）；没有价值就输出空串。',
  '7. sources 只登记你实际采纳的条目（title + url，url 缺失就省略 url 字段），最多 8 条。',
  '## 输出',
  '只输出 JSON，不要 markdown 代码块或解释：',
  '{"summary":"","themes":[],"styles":[],"colorLight":[],"visualElements":[],"seasons":[],"poseIdeas":[],"sources":[{"title":"","url":""}]}',
].join('\n');

/** 渲染送入整理提示词的条目清单（有摘要条目排前，带来源与链接便于核验） */
function renderSourceItems(items: ResearchItem[]): string {
  return selectResearchItems(items, MAX_SOURCE_ITEMS)
    .map((it, idx) => {
      const title = (it.title || '').trim().slice(0, IN_TITLE_CAP);
      const snippet = (it.snippet || '').trim().slice(0, IN_SNIPPET_CAP);
      const url = (it.url || '').trim();
      return `${idx + 1}. [${it.source}] ${title}${snippet ? `：${snippet}` : ''}${url ? `（${url}）` : ''}`;
    })
    .join('\n');
}

@Injectable()
export class ResearchDigestService {
  constructor(private readonly aiConfigService: AiConfigService) {}

  /**
   * 把检索条目二次整理成结构化结论。
   * 空条目 / 未配置文本模型 / 调用失败 / 解析失败 / 无有效内容 → null（调用方回退规则摘要）。
   */
  async summarize(topic: string, items: ResearchItem[]): Promise<ResearchBrief | null> {
    if (!items.length) return null;
    const key = buildBriefCacheKey(topic, items);
    const cached = briefCache.get(key);
    if (cached) return cached;

    try {
      const cfg = await this.aiConfigService.getActiveConfig();
      const brief = await traceStep(
        'researchDigest',
        '资料整理',
        async () => {
          const content = await textChat(cfg.text, {
            systemPrompt: SYSTEM_PROMPT,
            userText: `${describeTodayUtc8()}\n创作意图：${(topic || '').trim() || '（未提供）'}\n\n检索条目（共 ${items.length} 条）：\n${renderSourceItems(items)}`,
            temperature: 0.3,
            jsonMode: true,
            timeoutMs: 30_000,
          });
          return normalizeBrief(extractJson(content));
        },
        (b) => (b ? `整理出 ${b.summary ? '结论 + ' : ''}${b.themes.length + b.styles.length + b.colorLight.length + b.visualElements.length + b.seasons.length + b.poseIdeas.length} 条要点` : '整理失败（回退规则摘要）'),
      );
      if (!brief) return null;
      briefCache.set(key, brief);
      return brief;
    } catch {
      // 未配置文本模型 / 超时 / 网络错误 → 回退规则摘要
      return null;
    }
  }
}