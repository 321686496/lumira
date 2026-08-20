// lumira-server/packages/shared/src/types/usage.ts
export type UsageItemType = 'template' | 'scene';
export type UsageEventType = 'open_detail' | 'use_shoot' | 'scene_select';
export type TemplateSource = 'builtin' | 'remote';

export interface UsageEventInput {
  /** App 生成的唯一 ID，用于上报幂等去重 */
  clientEventId: string;
  itemType: UsageItemType;
  itemId: string;
  /** 模板来源 builtin/remote；场景固定为 'system' */
  itemSource: string;
  eventType: UsageEventType;
  occurredAt: number;
}

export interface UsageStatsItem {
  itemId: string;
  itemType: UsageItemType;
  useShoot: number;
  openDetail: number;
  sceneSelect: number;
}

export interface UsageStatsResponse {
  items: UsageStatsItem[];
}

// ===== 系统内置场景 =====
export interface SystemScene {
  id: string;
  name: string;
  category: string; // light | outdoor | indoor | mood
  style: string;
  icon: string;
  vibe: string;
  description: string;
  filter: Record<string, unknown>;
  tips: string[];
  exampleImages: string[];
  whereToShoot: string;
  bestTime: string;
  relatedCategory: string;
  recommendedTagIds: string[];
  sortOrder: number;
  isActive: boolean;
  updatedAt: number;
}

export interface SystemSceneListResponse {
  scenes: SystemScene[];
}

export interface CreateSceneRequest {
  id: string;
  name: string;
  category: string;
  style?: string;
  icon?: string;
  vibe?: string;
  description?: string;
  filter?: Record<string, unknown>;
  tips?: string[];
  exampleImages?: string[];
  whereToShoot?: string;
  bestTime?: string;
  relatedCategory?: string;
  recommendedTagIds?: string[];
  sortOrder?: number;
  isActive?: boolean;
}

export interface UpdateSceneRequest extends Partial<Omit<CreateSceneRequest, 'id'>> {}