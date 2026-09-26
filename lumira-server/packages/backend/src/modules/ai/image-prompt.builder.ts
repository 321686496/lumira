// lumira-server/packages/backend/src/modules/ai/image-prompt.builder.ts
// 生图提示词纯函数：从模板草稿 JSON 合成中文一段式 prompt（Task 6，TDD）
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第三节（生成效果图）
//
// Task 7（ai-generate-image.service）消费：prompt 由后端统一构建，前端不拼 prompt。
// 纯函数、无 DB 依赖：草稿 classification 链只有 key（拿不到 DB 分类树），
// 主体类型用一级 key → 中文名的小型内置映射（migration 003 预置 7 类），未知 key 跳过；tags 本身是中文直接用。

import { LUT_LABELS, WHITE_BALANCE_LABELS } from './enums';

/** 一级分类 key → 中文主体类型（migration 003 预置 7 类，与 Flutter 内置 7 类严格对齐） */
const CATEGORY_SUBJECT_LABELS: Record<string, string> = {
  portrait: '人像',
  landscape: '风景',
  food: '美食',
  street: '街拍',
  night: '夜景',
  macro: '微距',
  'still-life': '静物',
};

/** 画幅比例 → 构图取向词（fullscreen / 未知比例无取向词，仅保留比例值） */
const ASPECT_ORIENTATIONS: Record<string, string> = {
  '3:4': '竖构图',
  '9:16': '竖构图',
  '4:3': '横构图',
  '16:9': '横构图',
  '1:1': '方形构图',
};

/** 颗粒感强度分界：grain ≥ 30 描述为「明显」，否则「轻微」 */
const GRAIN_STRONG_THRESHOLD = 30;

/** 空草稿（无任何可用字段）兜底 prompt */
const FALLBACK_PROMPT = '一张 3:4 竖构图的人像摄影作品，自然光线，柔和氛围，画面干净通透';

const INCONSISTENT_POSE_PROMPT_PATTERN = /(不同场景|不同人物|不同造型|不同风格|不需要保持一致|可以不一致|允许不一致)/;

// ===== 基础工具（与 normalize.ts 同款口径，模块私有） =====

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

/** 宽松 string 化：字符串 trim；有限数字转字符串；其余 undefined */
function toStr(v: unknown): string | undefined {
  if (typeof v === 'string') {
    const s = v.trim();
    return s !== '' ? s : undefined;
  }
  return undefined;
}

/** 字符串数组提取：非 string 项剔除，trim 后为空的项剔除 */
function toStrArray(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  return v.filter((t): t is string => typeof t === 'string' && t.trim() !== '').map((t) => t.trim());
}

/** 有限数字提取 */
function toNum(v: unknown): number | undefined {
  return typeof v === 'number' && Number.isFinite(v) ? v : undefined;
}

/** composition.subjectFrame（左上角 + 宽高，归一化 0~1）→「主体落在画面左/中/右…」落位描述 */
function describeSubjectFrame(frame: unknown): string | undefined {
  if (!isPlainObject(frame)) return undefined;
  const x = toNum(frame.x);
  const y = toNum(frame.y);
  const w = toNum(frame.w);
  const h = toNum(frame.h);
  if (x === undefined || y === undefined || w === undefined || h === undefined) return undefined;
  const cx = x + w / 2;
  const cy = y + h / 2;
  const horizontal = cx < 0.38 ? '左侧' : cx > 0.62 ? '右侧' : '中部';
  const vertical = cy < 0.38 ? '偏上' : cy > 0.62 ? '偏下' : '纵向居中';
  return `主体落在画面${horizontal}${vertical}，横向占画幅约 ${Math.round(w * 100)}%、纵向约占 ${Math.round(h * 100)}%`;
}

/** camera 草稿 → 「以 85mm f/1.8、快门 1/400、ISO 200、日光白平衡 拍摄」参数短语 */
function describeCamera(camera: Record<string, unknown>): string | undefined {
  const parts: string[] = [];
  const lensType = toStr(camera.lensType);
  if (lensType !== undefined) parts.push(lensType);
  const shutterSpeed = toStr(camera.shutterSpeed);
  if (shutterSpeed !== undefined) parts.push(`快门 ${shutterSpeed}`);
  const iso = toNum(camera.iso);
  if (iso !== undefined) parts.push(`ISO ${Math.round(iso)}`);
  const wbKey = toStr(camera.whiteBalance);
  const wbLabel = wbKey !== undefined ? WHITE_BALANCE_LABELS[wbKey] : undefined;
  if (wbLabel !== undefined) parts.push(`${wbLabel}白平衡`);
  const exposure = toNum(camera.exposureCompensation);
  if (exposure !== undefined && exposure !== 0) parts.push(`曝光补偿 ${exposure > 0 ? '+' : ''}${exposure}EV`);
  return parts.length > 0 ? `以 ${parts.join('、')} 拍摄` : undefined;
}

/**
 * 从草稿合成生图 prompt（中文，一段式描述）。前端不拼 prompt。
 *
 * 拼接顺序：classification 主体类型 + aspectRatio 画幅 → tags 风格 → 构图描述 →
 * 光线（方向 + 最佳时段）→ 背景 + 道具 → 后期（LUT 标签 + 颗粒感）→ 氛围（shortDesc / description）→
 * 额外要求（extraPrompt，用户显式补充，置于末尾权重最高）。
 * 格式固定为「一张{画幅}{主体类型}摄影作品，风格{…}，{光线}，背景{…}，{氛围/后期}」，
 * 字段缺失跳过，空草稿走兜底模板。
 */
export function buildImagePrompt(draft: Record<string, unknown>, extraPrompt?: string | null): string {
  const meta = isPlainObject(draft.meta) ? draft.meta : {};
  const composition = isPlainObject(draft.composition) ? draft.composition : {};
  const sceneGuide = isPlainObject(draft.sceneGuide) ? draft.sceneGuide : {};
  const postProcess = isPlainObject(draft.postProcess) ? draft.postProcess : {};
  const classification = isPlainObject(meta.classification) ? meta.classification : {};
  const isSinglePose = draft.singlePose === true;
  const consistency = isPlainObject(draft.consistency) ? draft.consistency : {};
  const rawPose = Array.isArray(draft.pose)
    ? (isPlainObject(draft.pose[0]) ? draft.pose[0] : undefined)
    : isPlainObject(draft.pose)
      ? draft.pose
      : undefined;
  const poseName = isSinglePose && rawPose ? toStr(rawPose.name) : undefined;
  const poseDescription = isSinglePose && rawPose ? toStr(rawPose.description) : undefined;
  const posePhrase = [poseName, poseDescription].filter(Boolean).join('：');

  // 主体类型：classification.type → meta.category 兜底，均未命中内置映射则跳过
  const subject =
    CATEGORY_SUBJECT_LABELS[toStr(classification.type) ?? ''] ??
    CATEGORY_SUBJECT_LABELS[toStr(meta.category) ?? ''];

  // 画幅短语：比例 + 取向词（如「3:4 竖构图」）；未知比例仅保留比例值
  const ratio = toStr(composition.aspectRatio);
  const orientation = ratio !== undefined ? ASPECT_ORIENTATIONS[ratio] : undefined;
  const aspectPhrase =
    ratio !== undefined ? (orientation !== undefined ? `${ratio} ${orientation}` : ratio) : undefined;

  const segments: string[] = [];

  // ① 开场：一张{画幅}{主体类型}摄影作品
  if (subject !== undefined && aspectPhrase !== undefined) {
    segments.push(`一张 ${aspectPhrase}的${subject}摄影作品`);
  } else if (subject !== undefined) {
    segments.push(`一张${subject}摄影作品`);
  } else if (aspectPhrase !== undefined) {
    segments.push(`一张 ${aspectPhrase}摄影作品`);
  }

  // ② 风格：tags（中文直接用）
  const tags = toStrArray(meta.tags);
  if (tags.length > 0) segments.push(`风格${tags.join('、')}`);

  // ③ 构图描述 + 主体落位（构图落位是「拍得好看」的关键，必须交给生图模型）
  const compDescription = !isSinglePose ? toStr(composition.description) : undefined;
  if (compDescription !== undefined) segments.push(compDescription);
  const subjectFrameDesc = describeSubjectFrame(composition.subjectFrame);
  if (subjectFrameDesc !== undefined) segments.push(subjectFrameDesc);

  // ④ 光线：最佳时段 + 方向（如「午后4-6点的侧逆光」）
  const lightDirection = toStr(sceneGuide.lightDirection);
  const bestTime = toStr(sceneGuide.bestTime);
  if (lightDirection !== undefined && bestTime !== undefined) {
    segments.push(`${bestTime}的${lightDirection}`);
  } else if (lightDirection !== undefined) {
    segments.push(lightDirection);
  } else if (bestTime !== undefined) {
    segments.push(`${bestTime}的光线`);
  }

  // ⑤ 背景 + 道具
  const background = toStr(sceneGuide.background);
  if (background !== undefined) segments.push(`背景为${background}`);
  const props = toStrArray(sceneGuide.props);
  if (props.length > 0) segments.push(`可搭配${props.join('、')}`);

  // ⑤.5 相机参数：草稿里的镜头/快门/感光度/白平衡/曝光补偿必须落进 prompt（原先整段丢失 → 表现为「没有参数优化」）
  const camera = isPlainObject(draft.camera) ? draft.camera : {};
  const cameraPhrase = describeCamera(camera);
  if (cameraPhrase !== undefined) segments.push(cameraPhrase);

  // ⑥ 后期：LUT 中文标签（none/未知 key 跳过）+ 颗粒感
  const lut = toStr(postProcess.lut);
  const lutLabel = lut !== undefined && lut !== 'none' ? LUT_LABELS[lut] : undefined;
  if (lutLabel !== undefined) segments.push(`整体呈${lutLabel}色调`);
  const grain = postProcess.grain;
  if (typeof grain === 'number' && Number.isFinite(grain) && grain > 0) {
    segments.push(`带${grain >= GRAIN_STRONG_THRESHOLD ? '明显' : '轻微'}颗粒感`);
  }

  // ⑦ 氛围：shortDesc 优先，缺失时回退 description
  const shortDesc = toStr(meta.shortDesc);
  const description = !isSinglePose ? toStr(meta.description) : undefined;
  if (shortDesc !== undefined) {
    segments.push(`传递「${shortDesc}」的情绪`);
  } else if (description !== undefined) {
    segments.push(description);
  }

  if (isSinglePose) {
    segments.push(
      posePhrase
        ? `画面中只有一个人物，只呈现姿势${posePhrase}`
        : '画面中只有一个人物，只呈现一个姿势',
    );
    segments.push('不要合并多个姿势，不要生成连拍、多宫格或姿势对比图');
  }

  // ⑧ 真实感约束：抑制 AI 合成/精修感，向「真实相机随手抓拍」靠拢（人像额外强调真实人的质感与自然光）。
  // 仅在已有真实草稿内容时追加；空草稿仍走兜底文案。
  if (segments.length > 0) {
    segments.push('构图讲究：主体落位与留白经设计，视平线保持水平、主体不被画面边缘随意裁切、肢体线条舒展不互相粘连，机位高度与景别服务于主体');
    segments.push('真实相机直出的摄影质感，画面像朋友用手机或相机随手抓拍的实拍照片，而非插画、3D 建模渲染、AI 合成、影楼写真或精修广告片');
    segments.push('画面带自然噪点与轻微白平衡偏移（随拍感只作用于质感与瞬间，不作用于构图与画面水平）');
    if (subject === 'portrait') {
      segments.push(
        '人物是街上随处可见的普通年轻人而非精修模特：肤色不均匀、T 区微泛油光而脸颊哑光，皮肤保留毛孔、纹理与细小绒毛，不做美颜磨皮，绝不光滑发亮的塑料质感',
      );
      segments.push(
        '头发有几缕碎发，衣服有自然褶皱，表情松弛自然像被抓拍的瞬间；光影来自真实环境与自然光，明暗过渡自然可信',
      );
      segments.push(
        '五官、头发、衣服纹理与手部细节贴合真实人体结构，无肢体或手指畸变；姿势是经过设计的：身体朝向与重心明确、肩胯有错位、双手落点具体，画面水平',
      );
      segments.push(
        '避免典型 AI 感：不过度磨皮、不完美对称脸、不锥子脸卡通化、不高饱和炫彩、不镜面质感、不影棚式浮夸打光、不精致摆拍',
      );
    } else if (subject) {
      segments.push('画面像随手抓拍的实拍照片而非精修广告图，颜色与光线自然不夸张，无塑料或镜面质感');
    }
  }

  // ⑨ 额外要求：用户显式补充的附加提示词（Step3 输入），置于末尾权重最高
  const extra = typeof extraPrompt === 'string' ? extraPrompt.trim() : '';
  const allowInconsistentPose =
    consistency.mode === 'loose' || (extra.length > 0 && INCONSISTENT_POSE_PROMPT_PATTERN.test(extra));
  if (isSinglePose && !allowInconsistentPose) {
    segments.push(
      consistency.anchor === 'first'
        ? '参考图是同一套模板的第一张姿势图：严格复用参考图中的同一人物长相、服装、发型、体型，以及场景、道具、光线和摄影风格；本张只改变姿势'
        : '同一套模板的连续拍摄：保持同一人物的长相、服装、发型、体型，以及场景、道具、光线和摄影风格一致；本张只改变姿势',
    );
  }
  if (extra) segments.push(`额外要求：${extra}`);

  if (segments.length === 0) return FALLBACK_PROMPT;
  return `${segments.join('，')}。`;
}
