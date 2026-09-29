// lumira-server/packages/backend/src/modules/ai/trend-research/research-digest.ts
// 研究摘要共享构造：识别阶段注入草稿生成提示词（buildResearchDigest）与
// 生图阶段「网络趋势参考」分节（buildResearchLines）共用同一套挑选与截断规则。
//
// 挑选规则：有摘要（snippet 非空）的条目排前——域名裸链类 title-only 条目不再挤占榜单，
// 联网综述 / 有效搜索摘要优先进入提示词；同组内保持原顺序（sort 稳定）。

import type { ResearchItem } from './research-item';

/** 单条截断上限（snippet 较旧版 120 字放宽，容纳联网综述正文核心信息） */
const TITLE_CAP = 60;
const SNIPPET_CAP = 300;
/** digest 总长上限（lines 版由消费方自行约束） */
const TOTAL_CAP = 2400;
/** 用户显式指定 URL 的网页正文上限（接近全文；识别/生图阶段都按此透传，不再 300 字截断） */
export const USER_REFERENCE_SNIPPET_CAP = 20_000;

function bySnippetFirst(a: ResearchItem, b: ResearchItem): number {
  const aHas = (a.snippet || '').trim() ? 0 : 1;
  const bHas = (b.snippet || '').trim() ? 0 : 1;
  return aHas - bHas;
}

/** 挑选：有摘要（snippet 非空）的条目排前，最多 maxItems 条（同组内保持原顺序，sort 稳定） */
export function selectResearchItems(items: ResearchItem[], maxItems = 8): ResearchItem[] {
  return items.slice().sort(bySnippetFirst).slice(0, maxItems);
}

/** 渲染「用户指定参考网页」正文区块：snippet 不截断（上限 USER_REFERENCE_SNIPPET_CAP），
 *  标题作为行首，供识别阶段注入草稿提示词——让大模型能按用户 URL 的实际摄影内容创作。 */
export function renderUserReferenceItems(items: ResearchItem[]): string {
  return items
    .map((it) => {
      const title = (it.title || '').trim().slice(0, 200);
      const snippet = (it.snippet || '').trim().slice(0, USER_REFERENCE_SNIPPET_CAP);
      return title && snippet ? `${title}\n${snippet}` : (title || snippet);
    })
    .filter(Boolean)
    .join('\n\n---\n\n');
}

/** 挑选 + 渲染为「标题：摘要」行数组（有摘要排前，最多 maxItems 条；user-reference 条目全文透传） */
export function buildResearchLines(items: ResearchItem[], maxItems = 8): string[] {
  return selectResearchItems(items, maxItems)
    .map((it) => {
      const title = (it.title || '').trim().slice(0, TITLE_CAP);
      const raw = (it.snippet || '').trim();
      const snippet = it.source === 'user-reference' ? raw.slice(0, USER_REFERENCE_SNIPPET_CAP) : raw.slice(0, SNIPPET_CAP);
      return title && snippet ? `${title}：${snippet}` : (title || snippet);
    })
    .filter(Boolean);
}

/** 研究摘要：Top maxItems 条「标题：摘要」，总长上限 2400 字（注入草稿生成提示词） */
export function buildResearchDigest(items: ResearchItem[], maxItems = 8): string {
  return buildResearchLines(items, maxItems).join('\n').slice(0, TOTAL_CAP);
}
