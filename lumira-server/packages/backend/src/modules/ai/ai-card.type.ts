// lumira-server/packages/backend/src/modules/ai/ai-card.type.ts
// Task 9 契约扩展：AI 模板草稿新增字段类型（fillLight / legStretch / cameraDirection / poseRefSheet）。
// 仅新增，不删改既有字段，保持向后兼容。与 normalize.ts 白名单 / enums.ts 口径对齐。

/** App 补光（仿屏补光，暖色+强度）：暗部/夜景/室内默认开启 */
export interface FillLightConfig {
  /** 是否开启补光 */
  enabled: boolean;
  /** 补光颜色（如 'warm'）；缺省 warm */
  color?: string;
  /** 补光强度 0~1（normalize clamp [0,1]） */
  intensity?: number;
}

/** 单姿势相机方向：'front'（前置）| 'back'（后置），套用模板时据此自动切换前后摄 */
export type PoseCameraDirection = 'front' | 'back';

/** 姿势参考面片（T3 产出，透传存储）：多姿势共享锚点 + 各姿势差异项 */
export interface PoseRefSheetData {
  shared: {
    outfit?: string;
    scene?: string;
    light?: string;
    aspectRatio?: string;
    mood?: string;
    palette?: string;
  };
  perPose: Array<{
    name: string;
    differentiationNote?: string;
    subjectPose?: Record<string, unknown>;
    camera?: Record<string, unknown>;
    frame?: Record<string, unknown>;
    lightOnPose?: Record<string, unknown>;
  }>;
}

/** normalizeDraft 输出的新增字段可选类型（放心用泛型 Record 时也可强类型化对照） */
export interface AiDraftExtended {
  postProcess?: { fillLight?: FillLightConfig; legStretch?: number };
  poseRefSheet?: PoseRefSheetData;
}