// lumira-server/packages/backend/src/modules/ai/image-describe.service.ts
// T2 穷尽式图像识别服务（Task 5）：visionChatJson 穷尽识别（jsonMode + 有界重试）→ 解析 ImageDescription（字段兜底）
// 设计文档：docs/superpowers/specs/2026-09-21-ai-template-trend-orchestrator-design.md T2

import { Injectable } from '@nestjs/common';
import { AiConfigService } from './ai-config.service';
import { visionChatJson } from './llm-json';
import { buildExhaustiveSystemPrompt } from './image-describe.prompt';

// ===== ImageDescription 契约（全字段双引号，缺失以 unknown 兜底）=====

export interface ImageDescriptionSubjectFrame { x: number; y: number; w: number; h: number }

export interface ImageGlobal {
  subject: string;
  mood: string;
  /** 整体风格取向 + 精修程度（可选，缺失兜底 unknown） */
  styleRead?: string;
  season: string;
  timeOfDay: string;
  palette: { dominant: string[]; tone: string; brightness: string };
  light: Record<string, string>;
  composition: {
    leadLines: string;
    framing: string;
    symmetry: string;
    subjectFrame: Partial<ImageDescriptionSubjectFrame>;
    cropRatio: string;
    negativeSpace: string;
    depthOfField: string;
  };
  reproducibility: { level: string; reason: string; enableFillLight: boolean; lightHint: string };
}

export interface Person {
  role: string;
  /** 该人物表情与眼神（可选，缺失兜底 unknown） */
  expression?: string;
  /** 该人物妆造与穿搭质感（可选，缺失兜底 unknown） */
  styling?: string;
  face: Record<string, unknown>;
  body: Record<string, unknown>;
  limbs: Record<string, unknown>;
  outfit: Record<string, unknown>;
  anchors: { positionInFrame: { x: number; y: number }; scaleRatio: number; rotationDegree: number };
  lightOnPerson: Record<string, string>;
}

export interface ImageScene {
  location: string;
  depthLayers: { near: string[]; middle: string[]; far: string[] };
  props: string[];
  furniture: string[];
  texture: string;
  cleanliness: string;
}

export interface CameraLike {
  lightSuggestion: string;
  wbSuggestion: string;
  evSuggestion: string;
  focusDepth: string;
}

export interface ImageDescription {
  global: ImageGlobal;
  people: Person[];
  scene: ImageScene;
  cameraLike: CameraLike;
}

// ===== 兜底 =====

const UNKNOWN = 'unknown';

/** 宽松 string：string trim；否则 unknown */
function str(v: unknown): string {
  return typeof v === 'string' && v.trim() ? v.trim() : UNKNOWN;
}

/** 宽松 string[] */
function strArr(v: unknown): string[] {
  return Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : [];
}

/** 宽松数字（finite 才能用，否则 0） */
function num(v: unknown): number {
  return typeof v === 'number' && Number.isFinite(v) ? v : 0;
}

function numField(obj: Record<string, unknown>, key: string): number {
  return num(obj[key]);
}

function unknownKeys(obj: unknown, keys: string[]): Record<string, string> {
  const o = obj && typeof obj === 'object' ? obj : {};
  const out: Record<string, string> = {};
  for (const k of keys) out[k] = str((o as Record<string, unknown>)[k]);
  return out;
}

const LIGHT_FIELDS = ['dir', 'kind', 'colorTemp', 'tone', 'contrast', 'key', 'softness', 'shadowDir'];
const FACE_FIELDS = ['expression', 'gazeDir', 'headTilt', 'angle', 'openMouth'];
const BODY_FIELDS = ['posture', 'shoulders', 'hips', 'legStretchSuggest'];
const LIMB_FIELDS = ['armL', 'armR', 'handL', 'handR', 'legL', 'legR', 'weightShift'];
const CAMERA_FIELDS = ['lightSuggestion', 'wbSuggestion', 'evSuggestion', 'focusDepth'];

/** 字段级兜底：缺 global.people/scene/cameraLike 补默认，字段级 unknown，保证 shape 稳定 */
export function normalizeImageDescription(raw: unknown): ImageDescription {
  const o = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>;

  const rawGlobal = (o.global && typeof o.global === 'object' ? o.global : {}) as Record<string, unknown>;
  const palette = (rawGlobal.palette && typeof rawGlobal.palette === 'object' ? rawGlobal.palette : {}) as Record<string, unknown>;
  const composition = (rawGlobal.composition && typeof rawGlobal.composition === 'object' ? rawGlobal.composition : {}) as Record<string, unknown>;
  const subjectFrame = (composition.subjectFrame && typeof composition.subjectFrame === 'object' ? composition.subjectFrame : {}) as Record<string, unknown>;
  const repro = (rawGlobal.reproducibility && typeof rawGlobal.reproducibility === 'object' ? rawGlobal.reproducibility : {}) as Record<string, unknown>;

  const global: ImageGlobal = {
    subject: str(rawGlobal.subject),
    mood: str(rawGlobal.mood),
    styleRead: str(rawGlobal.styleRead),
    season: str(rawGlobal.season),
    timeOfDay: str(rawGlobal.timeOfDay),
    palette: {
      dominant: strArr(palette.dominant),
      tone: str(palette.tone),
      brightness: str(palette.brightness),
    },
    light: unknownKeys(rawGlobal.light, LIGHT_FIELDS),
    composition: {
      leadLines: str(composition.leadLines),
      framing: str(composition.framing),
      symmetry: str(composition.symmetry),
      subjectFrame: {
        x: numField(subjectFrame, 'x'),
        y: numField(subjectFrame, 'y'),
        w: numField(subjectFrame, 'w'),
        h: numField(subjectFrame, 'h'),
      },
      cropRatio: str(composition.cropRatio),
      negativeSpace: str(composition.negativeSpace),
      depthOfField: str(composition.depthOfField),
    },
    reproducibility: {
      level: str(repro.level),
      reason: str(repro.reason),
      enableFillLight: typeof repro.enableFillLight === 'boolean' ? repro.enableFillLight : false,
      lightHint: str(repro.lightHint),
    },
  };

  const people: Person[] = Array.isArray(o.people)
    ? o.people
        .filter((p) => p && typeof p === 'object')
        .map((p) => {
          const pp = p as Record<string, unknown>;
          const anchors = (pp.anchors && typeof pp.anchors === 'object' ? pp.anchors : {}) as Record<string, unknown>;
          const positionInFrame = (anchors.positionInFrame && typeof anchors.positionInFrame === 'object' ? anchors.positionInFrame : {}) as Record<string, unknown>;
          return {
            role: str(pp.role),
            expression: str(pp.expression),
            styling: str(pp.styling),
            face: unknownKeys(pp.face, FACE_FIELDS),
            body: unknownKeys(pp.body, BODY_FIELDS),
            limbs: unknownKeys(pp.limbs, LIMB_FIELDS),
            outfit: pp.outfit && typeof pp.outfit === 'object' ? (pp.outfit as Record<string, unknown>) : {},
            anchors: {
              positionInFrame: { x: numField(positionInFrame, 'x'), y: numField(positionInFrame, 'y') },
              scaleRatio: num(anchors.scaleRatio) || 1,
              rotationDegree: numField(anchors, 'rotationDegree'),
            },
            lightOnPerson: unknownKeys(pp.lightOnPerson, ['dir', 'keyVsFill', 'faceShadow']),
          };
        })
    : [];

  const rawScene = (o.scene && typeof o.scene === 'object' ? o.scene : {}) as Record<string, unknown>;
  const depthLayers = (rawScene.depthLayers && typeof rawScene.depthLayers === 'object' ? rawScene.depthLayers : {}) as Record<string, unknown>;
  const scene: ImageScene = {
    location: str(rawScene.location),
    depthLayers: { near: strArr(depthLayers.near), middle: strArr(depthLayers.middle), far: strArr(depthLayers.far) },
    props: strArr(rawScene.props),
    furniture: strArr(rawScene.furniture),
    texture: str(rawScene.texture),
    cleanliness: str(rawScene.cleanliness),
  };

  const rawCam = (o.cameraLike && typeof o.cameraLike === 'object' ? o.cameraLike : {}) as Record<string, unknown>;
  const cameraLike: CameraLike = {
    lightSuggestion: str(rawCam.lightSuggestion),
    wbSuggestion: str(rawCam.wbSuggestion),
    evSuggestion: str(rawCam.evSuggestion),
    focusDepth: str(rawCam.focusDepth),
  };

  return { global, people, scene, cameraLike };
}

@Injectable()
export class ImageDescribeService {
  constructor(private readonly aiConfigService: AiConfigService) {}

  /** 穷尽式识别：visionChatJson（jsonMode + 有界重试）→ normalizeImageDescription（缺字段兜底） */
  async describe(image: { base64: string; mime: string }): Promise<ImageDescription> {
    const cfg = await this.aiConfigService.getActiveConfig();
    const json = await visionChatJson(
      cfg.vision,
      {
        systemPrompt: buildExhaustiveSystemPrompt(),
        userText: '请对这张图片做穷尽式识别：按九宫格逐格描述，并输出 JSON。',
        imageBase64: image.base64,
        imageMime: image.mime,
        temperature: 0.4,
      },
      cfg.runtime,
    );
    return normalizeImageDescription(json);
  }

  /** 多图穷尽识别：用户上传多张参考图时逐张识别后合并为一份描述
   *  （全局/相机取第一张，人物取并集，场景道具/层次取并集；任一张失败由调用方整体兜底）。 */
  async describeMany(images: { base64: string; mime: string }[]): Promise<ImageDescription> {
    const list: ImageDescription[] = [];
    for (const img of images) {
      list.push(await this.describe(img));
    }
    return mergeImageDescriptions(list);
  }
}

/** 去重保留顺序的字符串数组并集 */
function uniqStr(arr: string[]): string[] {
  return [...new Set(arr)];
}

/** 合并多份穷尽识别描述：全局/相机取第一张（同风格多图共享一份基调），人物 concat，场景道具/家具/层次取并集 */
export function mergeImageDescriptions(list: ImageDescription[]): ImageDescription {
  if (list.length === 0) {
    throw new Error('无可合并的图片描述');
  }
  if (list.length === 1) return list[0];
  const [first, ...rest] = list;
  const scene = {
    location: first.scene.location,
    depthLayers: {
      near: uniqStr([...first.scene.depthLayers.near, ...rest.flatMap((d) => d.scene.depthLayers.near)]),
      middle: uniqStr([...first.scene.depthLayers.middle, ...rest.flatMap((d) => d.scene.depthLayers.middle)]),
      far: uniqStr([...first.scene.depthLayers.far, ...rest.flatMap((d) => d.scene.depthLayers.far)]),
    },
    props: uniqStr([...first.scene.props, ...rest.flatMap((d) => d.scene.props)]),
    furniture: uniqStr([...first.scene.furniture, ...rest.flatMap((d) => d.scene.furniture)]),
    texture: first.scene.texture,
    cleanliness: first.scene.cleanliness,
  };
  return {
    global: first.global,
    people: list.flatMap((d) => d.people),
    scene,
    cameraLike: first.cameraLike,
  };
}