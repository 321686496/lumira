// 参考图多模态转述产物（结构化）：由多模态模型看图后产出可注入生图提示词的视觉结论。
// 与 research-brief.ts 同构：宽松归一化 + 渲染为分节文本块。

/** 参考图多模态解读结论 */
export interface ResearchVision {
  /** 一句话结论（时间线 resultBrief / 后台展示） */
  summary: string;
  styles: string[];
  colorLight: string[];
  composition: string[];
  /** 人物动作姿势：每张图里人物的身体姿态/动作/手势/朝向/站位（如侧身回眸、手扶栏杆） */
  poseIdeas: string[];
  wardrobe: string[];
  scene: string[];
  /** 真正被采纳的图（id 对应 ResearchImage.id）+ 采纳理由 */
  adopted: { id: string; reason: string }[];
}

/** 渲染总长上限 */
const TOTAL_CAP = 1200;
/** 单项条目上限 */
const ITEM_CAP = 60;
/** 单个数组最多条目数 */
const LIST_CAP = 10;
/** summary 长度上限 */
const SUMMARY_CAP = 160;
/** adopted 最多条数 */
const ADOPTED_CAP = 8;

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

/** 是否含有效内容（全空 → 视为解读失败） */
export function visionHasContent(v: ResearchVision): boolean {
  return Boolean(
    v.summary ||
      v.styles.length ||
      v.colorLight.length ||
      v.composition.length ||
      v.poseIdeas.length ||
      v.wardrobe.length ||
      v.scene.length,
  );
}

/**
 * 模型原始 JSON → ResearchVision。
 * allowedIds 提供时（真实存在的图片 id），adopted 只保留其中的项，防止模型编造 id。
 */
export function normalizeVision(raw: unknown, allowedIds?: Iterable<string>): ResearchVision | null {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return null;
  const rec = raw as Record<string, unknown>;
  const allow = allowedIds ? new Set(allowedIds) : null;

  const adopted: { id: string; reason: string }[] = [];
  const seen = new Set<string>();
  if (Array.isArray(rec.adopted)) {
    for (const item of rec.adopted) {
      if (typeof item !== 'object' || item === null) continue;
      const it = item as Record<string, unknown>;
      const id = toStr(it.id, 64);
      const reason = toStr(it.reason, ITEM_CAP);
      if (!id || !reason || seen.has(id)) continue;
      if (allow && !allow.has(id)) continue;
      seen.add(id);
      adopted.push({ id, reason });
      if (adopted.length >= ADOPTED_CAP) break;
    }
  }

  const vision: ResearchVision = {
    summary: toStr(rec.summary, SUMMARY_CAP),
    styles: toStrList(rec.styles),
    colorLight: toStrList(rec.colorLight),
    composition: toStrList(rec.composition),
    poseIdeas: toStrList(rec.poseIdeas),
    wardrobe: toStrList(rec.wardrobe),
    scene: toStrList(rec.scene),
    adopted,
  };
  return visionHasContent(vision) ? vision : null;
}

/** 分节定义（顺序即渲染顺序，非空才输出） */
const SECTIONS: { label: string; pick: (v: ResearchVision) => string[] }[] = [
  { label: '风格倾向', pick: (v) => v.styles },
  { label: '色彩与光影', pick: (v) => v.colorLight },
  { label: '构图', pick: (v) => v.composition },
  { label: '动作姿势', pick: (v) => v.poseIdeas ?? [] },
  { label: '穿搭/妆造', pick: (v) => v.wardrobe },
  { label: '场景', pick: (v) => v.scene },
];

/** 渲染为带分节小标题的文本块（注入生图提示词） */
export function renderResearchVision(v: ResearchVision): string {
  const lines: string[] = [];
  for (const { label, pick } of SECTIONS) {
    const vals = pick(v);
    if (vals.length) lines.push(`- ${label}：${vals.join('；')}`);
  }
  if (v.summary) lines.push(`- 综合结论：${v.summary}`);
  return lines.join('\n').slice(0, TOTAL_CAP);
}
