// lumira-server/packages/backend/src/modules/ai/normalize.ts
// AI 草稿归一化纯函数（识别 / 生图共用）
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第五节
//
// 枚举值数组 + 中文标签表已迁至 ./enums（Task 4），本文件仅保留归一化函数逻辑。

import {
  LUTS,
  LUT_LABELS,
  OVERLAY_TYPES,
  OVERLAY_TYPE_LABELS,
  ASPECT_RATIOS,
  ASPECT_RATIO_LABELS,
  ISO_MODES,
  ISO_MODE_LABELS,
  WHITE_BALANCES,
  WHITE_BALANCE_LABELS,
  FLASH_MODES,
  FLASH_MODE_LABELS,
  FOCUS_MODES,
  FOCUS_MODE_LABELS,
  LENS_SUGGESTIONS,
  LENS_SUGGESTION_LABELS,
  SEASONS,
  SEASON_LABELS,
  WEATHERS,
  WEATHER_LABELS,
  TIME_TONES,
  TIME_TONE_LABELS,
} from './enums';

export interface CategoryNode {
  key: string;
  name: string;
  parentKey: string | null;
  level: number;
}

export interface NormalizeResult {
  draft: Record<string, unknown>;
  warnings: string[];
}

// ===== 基础工具 =====

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

/** 宽松 string 化：字符串 trim；有限数字转字符串；其余 undefined */
function toStr(v: unknown): string | undefined {
  if (typeof v === 'string') return v.trim();
  if (typeof v === 'number' && Number.isFinite(v)) return String(v);
  return undefined;
}

/** 字段值是否视为「未提供」（undefined / null / 空白字符串） */
function isAbsent(v: unknown): boolean {
  if (v === undefined || v === null) return true;
  return typeof v === 'string' && v.trim() === '';
}

/** 宽松数值化：有限数字；非空数字字符串；其余 undefined */
function toFiniteNumber(v: unknown): number | undefined {
  if (typeof v === 'number') return Number.isFinite(v) ? v : undefined;
  if (typeof v === 'string' && v.trim() !== '') {
    const n = Number(v);
    if (Number.isFinite(n)) return n;
  }
  return undefined;
}

// ===== 导出 API =====

/**
 * LLM 输出容错提取：剥 code fence → 首个 { 到末个 } 截取 → JSON.parse；失败返回 null。
 * 仅接受 plain object（数组 / 标量一律 null）。
 */
export function extractJson(text: string): Record<string, unknown> | null {
  if (typeof text !== 'string' || text.trim() === '') return null;

  // 1. 直接解析（模型开了 response_format: json_object 时的常态路径）
  try {
    const direct = JSON.parse(text);
    if (isPlainObject(direct)) return direct;
  } catch {
    // 继续走容错提取
  }

  // 2. 剥 code fence（```json ... ``` 或 ``` ... ```）
  const fence = text.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  const candidate = fence ? fence[1] : text;

  // 3. 首个 { 到末个 } 截取（容忍前后废话）
  const start = candidate.indexOf('{');
  const end = candidate.lastIndexOf('}');
  if (start === -1 || end <= start) return null;
  try {
    const parsed = JSON.parse(candidate.slice(start, end + 1));
    if (isPlainObject(parsed)) return parsed;
  } catch {
    // fallthrough
  }
  return null;
}

/**
 * 枚举校验：精确 key 命中 → 中文标签反查命中 → 否则 undefined（调用方记 warning）。
 */
export function mapEnumValue(
  raw: unknown,
  allowed: readonly string[],
  labels: Record<string, string>,
): string | undefined {
  if (typeof raw !== 'string') return undefined;
  const v = raw.trim();
  if (!v) return undefined;
  if (allowed.includes(v)) return v;
  for (const key of allowed) {
    if (labels[key] === v) return key;
  }
  return undefined;
}

/** 数值夹取：非数值返回 undefined，否则 clamp 到 [min, max]。 */
export function clampNumber(raw: unknown, min: number, max: number): number | undefined {
  const n = toFiniteNumber(raw);
  if (n === undefined) return undefined;
  return Math.min(max, Math.max(min, n));
}

// ===== normalizeDraft 字段级助手 =====

/** 枚举字段：未提供跳过；非法丢弃 + warning；合法（含标签反查）写入 */
function setEnumField(
  target: Record<string, unknown>,
  key: string,
  raw: unknown,
  allowed: readonly string[],
  labels: Record<string, string>,
  path: string,
  warnings: string[],
): void {
  if (isAbsent(raw)) return;
  const mapped = mapEnumValue(raw, allowed, labels);
  if (mapped === undefined) {
    warnings.push(`${path} 值 "${String(raw)}" 不是合法枚举，已丢弃`);
    return;
  }
  target[key] = mapped;
}

/** 枚举数组字段：逐项校验，非法项丢弃 + warning */
function setEnumArrayField(
  target: Record<string, unknown>,
  key: string,
  raw: unknown,
  allowed: readonly string[],
  labels: Record<string, string>,
  path: string,
  warnings: string[],
): void {
  if (!Array.isArray(raw)) return;
  const kept: string[] = [];
  for (const item of raw) {
    const mapped = mapEnumValue(item, allowed, labels);
    if (mapped === undefined) {
      warnings.push(`${path} 值 "${String(item)}" 不是合法枚举，已丢弃`);
    } else {
      kept.push(mapped);
    }
  }
  target[key] = kept;
}

/** 数值字段：未提供跳过；非数值丢弃 + warning；越界夹取 + warning */
function setClampField(
  target: Record<string, unknown>,
  key: string,
  raw: unknown,
  min: number,
  max: number,
  path: string,
  warnings: string[],
): void {
  if (isAbsent(raw)) return;
  const clamped = clampNumber(raw, min, max);
  if (clamped === undefined) {
    warnings.push(`${path} 值 "${String(raw)}" 不是数值，已丢弃`);
    return;
  }
  const orig = toFiniteNumber(raw)!;
  if (orig !== clamped) {
    warnings.push(`${path} 值 ${orig} 超出 [${min}, ${max}]，已夹取为 ${clamped}`);
  }
  target[key] = clamped;
}

/** 数值字段（带默认值）：未提供用默认；非数值用默认 + warning；越界夹取 + warning */
function clampOrDefault(
  raw: unknown,
  min: number,
  max: number,
  dflt: number,
  path: string,
  warnings: string[],
): number {
  if (isAbsent(raw)) return dflt;
  const clamped = clampNumber(raw, min, max);
  if (clamped === undefined) {
    warnings.push(`${path} 值 "${String(raw)}" 不是数值，已使用默认值 ${dflt}`);
    return dflt;
  }
  const orig = toFiniteNumber(raw)!;
  if (orig !== clamped) {
    warnings.push(`${path} 值 ${orig} 超出 [${min}, ${max}]，已夹取为 ${clamped}`);
  }
  return clamped;
}

/** pose 数量上限：与提示词约定 1~6 个一致，防 LLM 失控输出（表单姿势编辑器规模也按 6 设计） */
const MAX_POSES = 6;

// ===== 草稿归一化主入口 =====

/**
 * 草稿归一化主入口：枚举校验、分类链校验、数值夹取，非法值丢弃并收集 warnings。
 *
 * - 非 object 输入 → throw（调用方转 400）
 * - 输出 draft 顶层固定为 meta / composition / pose / camera / sceneGuide / postProcess 六段，
 *   未知顶层键忽略；price / silhouette / author / sortOrder / isActive 等 AI 不填字段强制不写入
 * - 分类链校验（majorStyle → style → method 逐级父子校验，任一层断裂 → 该层及以下全部丢弃）：
 *   未提供的层直接跳过、以最后保留的节点为父级继续校验后续层，
 *   兼容非人像浅树（majorStyle 为空串、style 直接挂一级分类的 L2、method 为 L3）
 */
export function normalizeDraft(raw: unknown, categories: CategoryNode[]): NormalizeResult {
  if (!isPlainObject(raw)) {
    throw new Error('normalizeDraft: 输入必须是 JSON 对象');
  }

  const warnings: string[] = [];
  const src = raw;
  const draft: Record<string, unknown> = {};

  // ===== meta =====
  const rawMeta = isPlainObject(src.meta) ? src.meta : {};
  const meta: Record<string, unknown> = {};

  // name：string 化 + trim；12~30 之外仅 warning 不丢弃；超 100 字截断（表单 schema max(100)）
  let name = toStr(rawMeta.name) ?? '';
  if (name.length > 100) {
    warnings.push(`meta.name 长度 ${name.length} 超过 100 字，已截断为前 100 字`);
    name = name.slice(0, 100);
  }
  meta.name = name;
  if (name.length < 12 || name.length > 30) {
    warnings.push(`meta.name 长度 ${name.length} 不在 12~30 字范围内，已保留请复核`);
  }

  // category：必须在分类树 level=1 key 集合，非法回退 portrait
  const level1Keys = new Set(categories.filter((c) => c.level === 1).map((c) => c.key));
  const rawCategory = toStr(rawMeta.category);
  let category = 'portrait';
  if (rawCategory && level1Keys.has(rawCategory)) {
    category = rawCategory;
  } else {
    warnings.push(`meta.category "${String(rawMeta.category)}" 不是分类树一级节点，已回退为 portrait`);
  }
  meta.category = category;

  // shortDesc：string 化 + 超 20 字截断（表单 schema max(20)，超字提交会静默校验失败）
  const shortDescRaw = toStr(rawMeta.shortDesc);
  if (shortDescRaw !== undefined) {
    if (shortDescRaw.length > 20) {
      warnings.push(`meta.shortDesc 长度 ${shortDescRaw.length} 超过 20 字，已截断为前 20 字`);
      meta.shortDesc = shortDescRaw.slice(0, 20);
    } else {
      meta.shortDesc = shortDescRaw;
    }
  }
  const description = toStr(rawMeta.description);
  if (description !== undefined) meta.description = description;

  // tags：过滤非 string
  if (Array.isArray(rawMeta.tags)) {
    meta.tags = rawMeta.tags.filter((t): t is string => typeof t === 'string');
  }

  // ambience：seasons / weathers / timeTones 各自枚举过滤
  if (isPlainObject(rawMeta.ambience)) {
    const ambience: Record<string, unknown> = {};
    setEnumArrayField(ambience, 'seasons', rawMeta.ambience.seasons, SEASONS, SEASON_LABELS, 'meta.ambience.seasons', warnings);
    setEnumArrayField(ambience, 'weathers', rawMeta.ambience.weathers, WEATHERS, WEATHER_LABELS, 'meta.ambience.weathers', warnings);
    setEnumArrayField(ambience, 'timeTones', rawMeta.ambience.timeTones, TIME_TONES, TIME_TONE_LABELS, 'meta.ambience.timeTones', warnings);
    if (Object.keys(ambience).length > 0) meta.ambience = ambience;
  }

  // classification：category 一律用已校验的 meta.category（不信任 classification.type）
  const rawCls = isPlainObject(rawMeta.classification) ? rawMeta.classification : null;
  const classification: Record<string, unknown> = { type: category };
  let lastKey = category;
  let lastLevel = 1;
  let chainBroken = false;
  const chainFields: Array<'majorStyle' | 'style' | 'method'> = ['majorStyle', 'style', 'method'];
  for (const field of chainFields) {
    if (chainBroken) break;
    const val = rawCls ? toStr(rawCls[field]) : undefined;
    if (!val) continue; // 未提供该层：跳过，继续校验后续提供的层（浅树场景）
    const node = categories.find(
      (c) => c.key === val && c.parentKey === lastKey && c.level === lastLevel + 1,
    );
    if (node) {
      classification[field] = val;
      lastKey = val;
      lastLevel += 1;
    } else {
      warnings.push(`meta.classification.${field} "${val}" 不是 "${lastKey}" 的合法子分类，已丢弃该层及以下`);
      chainBroken = true;
    }
  }
  meta.classification = classification;

  draft.meta = meta;

  // ===== composition =====
  const rawComp = isPlainObject(src.composition) ? src.composition : {};
  const composition: Record<string, unknown> = {};
  setEnumField(composition, 'overlayType', rawComp.overlayType, OVERLAY_TYPES, OVERLAY_TYPE_LABELS, 'composition.overlayType', warnings);
  setEnumField(composition, 'aspectRatio', rawComp.aspectRatio, ASPECT_RATIOS, ASPECT_RATIO_LABELS, 'composition.aspectRatio', warnings);
  setClampField(composition, 'opacity', rawComp.opacity, 0, 1, 'composition.opacity', warnings);
  const compDescription = toStr(rawComp.description);
  if (compDescription !== undefined) composition.description = compDescription;
  if (isPlainObject(rawComp.subjectFrame)) {
    const subjectFrame: Record<string, unknown> = {};
    setClampField(subjectFrame, 'x', rawComp.subjectFrame.x, 0, 1, 'composition.subjectFrame.x', warnings);
    setClampField(subjectFrame, 'y', rawComp.subjectFrame.y, 0, 1, 'composition.subjectFrame.y', warnings);
    setClampField(subjectFrame, 'w', rawComp.subjectFrame.w, 0, 1, 'composition.subjectFrame.w', warnings);
    setClampField(subjectFrame, 'h', rawComp.subjectFrame.h, 0, 1, 'composition.subjectFrame.h', warnings);
    if (Object.keys(subjectFrame).length > 0) composition.subjectFrame = subjectFrame;
  }
  draft.composition = composition;

  // ===== pose =====
  // 非数组包装成数组；空 → 默认单姿势骨架；
  // 每项只保留 name / description / position / scale / rotation（silhouette 等 AI 不填字段一律剔除）
  const rawPose = src.pose;
  const poseList: unknown[] = Array.isArray(rawPose)
    ? rawPose
    : rawPose === undefined || rawPose === null
      ? []
      : [rawPose];
  const poses: Array<Record<string, unknown>> = [];
  poseList.forEach((item, idx) => {
    if (!isPlainObject(item)) {
      warnings.push(`pose[${idx}] 不是对象，已丢弃`);
      return;
    }
    const pose: Record<string, unknown> = {};
    pose.name = toStr(item.name) ?? '';
    pose.description = toStr(item.description) ?? '';
    const rawPosition = isPlainObject(item.position) ? item.position : {};
    pose.position = {
      x: clampOrDefault(rawPosition.x, 0, 1, 0.5, `pose[${idx}].position.x`, warnings),
      y: clampOrDefault(rawPosition.y, 0, 1, 0.5, `pose[${idx}].position.y`, warnings),
    };
    pose.scale = clampOrDefault(item.scale, 0.1, 3, 1, `pose[${idx}].scale`, warnings);
    pose.rotation = clampOrDefault(item.rotation, -180, 180, 0, `pose[${idx}].rotation`, warnings);
    poses.push(pose);
  });
  if (poses.length > MAX_POSES) {
    warnings.push(`pose 数量 ${poses.length} 超过上限 ${MAX_POSES}，已截断`);
    poses.length = MAX_POSES;
  }
  if (poses.length === 0) {
    poses.push({ name: '', description: '', position: { x: 0.5, y: 0.5 }, scale: 1, rotation: 0 });
  }
  draft.pose = poses;

  // ===== camera =====
  const rawCam = isPlainObject(src.camera) ? src.camera : {};
  const camera: Record<string, unknown> = {};
  setClampField(camera, 'exposureCompensation', rawCam.exposureCompensation, -3, 3, 'camera.exposureCompensation', warnings);
  setEnumField(camera, 'isoMode', rawCam.isoMode, ISO_MODES, ISO_MODE_LABELS, 'camera.isoMode', warnings);
  setClampField(camera, 'iso', rawCam.iso, 50, 25600, 'camera.iso', warnings);
  const shutterSpeed = toStr(rawCam.shutterSpeed);
  if (shutterSpeed !== undefined) camera.shutterSpeed = shutterSpeed;
  setEnumField(camera, 'whiteBalance', rawCam.whiteBalance, WHITE_BALANCES, WHITE_BALANCE_LABELS, 'camera.whiteBalance', warnings);
  setClampField(camera, 'whiteBalanceK', rawCam.whiteBalanceK, 2000, 10000, 'camera.whiteBalanceK', warnings);
  setEnumField(camera, 'flashMode', rawCam.flashMode, FLASH_MODES, FLASH_MODE_LABELS, 'camera.flashMode', warnings);
  setEnumField(camera, 'focusMode', rawCam.focusMode, FOCUS_MODES, FOCUS_MODE_LABELS, 'camera.focusMode', warnings);
  const lensType = toStr(rawCam.lensType);
  if (lensType !== undefined) camera.lensType = lensType;
  setEnumField(camera, 'lensSuggestion', rawCam.lensSuggestion, LENS_SUGGESTIONS, LENS_SUGGESTION_LABELS, 'camera.lensSuggestion', warnings);
  draft.camera = camera;

  // ===== sceneGuide =====
  const rawScene = isPlainObject(src.sceneGuide) ? src.sceneGuide : {};
  const sceneGuide: Record<string, unknown> = {};
  for (const field of ['lightDirection', 'shootingDistance', 'background', 'bestTime'] as const) {
    const v = toStr(rawScene[field]);
    if (v !== undefined) sceneGuide[field] = v;
  }
  if (Array.isArray(rawScene.props)) {
    sceneGuide.props = rawScene.props.filter((t): t is string => typeof t === 'string');
  }
  if (Array.isArray(rawScene.tips)) {
    sceneGuide.tips = rawScene.tips.filter((t): t is string => typeof t === 'string');
  }
  draft.sceneGuide = sceneGuide;

  // ===== postProcess =====
  const rawPost = isPlainObject(src.postProcess) ? src.postProcess : {};
  const postProcess: Record<string, unknown> = {};
  setEnumField(postProcess, 'cropRatio', rawPost.cropRatio, ASPECT_RATIOS, ASPECT_RATIO_LABELS, 'postProcess.cropRatio', warnings);
  if (isPlainObject(rawPost.color)) {
    const color: Record<string, unknown> = {};
    for (const field of [
      'brightness', 'contrast', 'saturation', 'temperature', 'tint', 'highlights', 'shadows',
    ] as const) {
      setClampField(color, field, rawPost.color[field], -100, 100, `postProcess.color.${field}`, warnings);
    }
    if (Object.keys(color).length > 0) postProcess.color = color;
  }
  setClampField(postProcess, 'smoothStrength', rawPost.smoothStrength, 0, 100, 'postProcess.smoothStrength', warnings);
  setClampField(postProcess, 'sharpen', rawPost.sharpen, 0, 100, 'postProcess.sharpen', warnings);
  setClampField(postProcess, 'vignette', rawPost.vignette, 0, 100, 'postProcess.vignette', warnings);
  setClampField(postProcess, 'grain', rawPost.grain, 0, 100, 'postProcess.grain', warnings);
  setEnumField(postProcess, 'lut', rawPost.lut, LUTS, LUT_LABELS, 'postProcess.lut', warnings);
  draft.postProcess = postProcess;

  return { draft, warnings };
}
