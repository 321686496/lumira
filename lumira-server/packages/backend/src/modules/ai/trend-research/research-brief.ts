// lumira-server/packages/backend/src/modules/ai/trend-research/research-brief.ts
// 研究资料二次整理产物（结构化）：由文本模型把联网检索命中的原始条目提炼成
// 可写进模板字段的结论，供「生成模板结构数据」的提示词注入（renderResearchBrief）
// 与后台时间线展示（summary）。
//
// 与 research-digest.ts（纯规则摘要）的关系：规则版保留为整理失败时的降级路径。

/** 结构化研究结论（模型二次整理产出；条目不足以支撑的维度留空） */
export interface ResearchBrief {
  /** 一句话结论（后台展示 / 时间线 resultBrief） */
  summary: string;
  /** 交叉验证的流行主题 / 题材 */
  themes: string[];
  /** 风格倾向 */
  styles: string[];
  /** 色彩与光影倾向 */
  colorLight: string[];
  /** 可复现的视觉元素（场景 / 道具 / 服装 / 妆容） */
  visualElements: string[];
  /** 时令 / 节日 / 档期（含年份月份，可检索） */
  seasons: string[];
  /** 姿势 / 构图灵感 */
  poseIdeas: string[];
  /** 实际采纳的可信来源（供人工核对） */
  sources: { title: string; url?: string }[];
}

/** 渲染总长上限（与规则摘要口径一致） */
const TOTAL_CAP = 2400;
/** 单项条目上限 */
const ITEM_CAP = 80;
/** 单个数组最多条目数 */
const LIST_CAP = 12;
/** summary 长度上限 */
const SUMMARY_CAP = 200;

function toStr(v: unknown, cap: number): string {
  if (typeof v !== 'string') return '';
  const s = v.trim();
  return s.length > cap ? s.slice(0, cap) : s;
}

/** 字符串数组归一化：去空、去重、限长、限条目数 */
function toStrList(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  const out: string[] = [];
  const seen = new Set<string>();
  for (const raw of v) {
    const s = toStr(raw, ITEM_CAP);
    if (!s || seen.has(s)) continue;
    seen.add(s);
    out.push(s);
    if (out.length >= LIST_CAP) break;
  }
  return out;
}

/** 来源归一化：只保留有 title 的项，title+url 去重 */
function toSources(v: unknown): { title: string; url?: string }[] {
  if (!Array.isArray(v)) return [];
  const out: { title: string; url?: string }[] = [];
  const seen = new Set<string>();
  for (const raw of v) {
    if (typeof raw !== 'object' || raw === null) continue;
    const rec = raw as Record<string, unknown>;
    const title = toStr(rec.title, ITEM_CAP);
    if (!title) continue;
    const url = toStr(rec.url, 300) || undefined;
    const key = `${title}|${url ?? ''}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(url ? { title, url } : { title });
    if (out.length >= 8) break;
  }
  return out;
}

/** 是否含有效内容（全空 → 视为整理失败，调用方回退规则摘要） */
export function briefHasContent(b: ResearchBrief): boolean {
  return Boolean(
    b.summary ||
      b.themes.length ||
      b.styles.length ||
      b.colorLight.length ||
      b.visualElements.length ||
      b.seasons.length ||
      b.poseIdeas.length,
  );
}

/** 模型原始 JSON → ResearchBrief；结构不合法或无有效内容 → null */
export function normalizeBrief(raw: unknown): ResearchBrief | null {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return null;
  const rec = raw as Record<string, unknown>;
  const brief: ResearchBrief = {
    summary: toStr(rec.summary, SUMMARY_CAP),
    themes: toStrList(rec.themes),
    styles: toStrList(rec.styles),
    colorLight: toStrList(rec.colorLight),
    visualElements: toStrList(rec.visualElements),
    seasons: toStrList(rec.seasons),
    poseIdeas: toStrList(rec.poseIdeas),
    sources: toSources(rec.sources),
  };
  return briefHasContent(brief) ? brief : null;
}

/** 分节定义（顺序即渲染顺序，非空才输出） */
const SECTIONS: { label: string; pick: (b: ResearchBrief) => string[] }[] = [
  { label: '流行主题', pick: (b) => b.themes },
  { label: '风格倾向', pick: (b) => b.styles },
  { label: '色彩与光影', pick: (b) => b.colorLight },
  { label: '视觉元素', pick: (b) => b.visualElements },
  { label: '时令 / 节日', pick: (b) => b.seasons },
  { label: '姿势灵感', pick: (b) => b.poseIdeas },
];

/** 渲染为带分节小标题的文本块（注入模板生成提示词；总长上限 2400） */
export function renderResearchBrief(brief: ResearchBrief): string {
  const lines: string[] = [];
  for (const { label, pick } of SECTIONS) {
    const vals = pick(brief);
    if (vals.length) lines.push(`- ${label}：${vals.join('；')}`);
  }
  if (brief.summary) lines.push(`- 综合结论：${brief.summary}`);
  if (brief.sources.length) {
    lines.push(`- 采纳来源（供核对，勿写入模板文案）：${brief.sources.map((s) => (s.url ? `${s.title}（${s.url}）` : s.title)).join('；')}`);
  }
  return lines.join('\n').slice(0, TOTAL_CAP);
}