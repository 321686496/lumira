// src/types/admin.ts
// 后台专用类型（与 @lumira/shared 互补）

export interface StatsResponse {
  totalDevices: number;
  todayNewDevices: number;
  totalInvites: number;
  todayNewInvites: number;
  totalRedemptions: number;
  todayRedeemed: number;
  totalRewardUnlocks: number;
  totalCodesGenerated: number;
  totalCodesUsed: number;
  totalCodesRemaining: number;
}

export interface InviteListResponse {
  data: Array<{
    id: number;
    inviterDeviceId: string;
    inviteeDeviceId: string;
    inviteCode: string;
    channel: string;
    activatedAt: number;
    inviterIp: string | null;
    inviteeIp: string | null;
  }>;
  total: number;
  page: number;
  pageSize: number;
}

export interface Batch {
  batchId: number;
  campaignName: string;
  rewardPoints: number;
  rewardTemplates: string;
  maxUsesPerCode: number;
  totalGenerated: number;
  totalUsed: number;
  validFrom: number | null;
  validUntil: number | null;
  isActive: number;
  createdAt: number;
}

export interface BatchDetail extends Batch {
  codes: Array<{
    code: string;
    batchId: number;
    usedCount: number;
    maxUses: number;
  }>;
}

export interface CreateBatchResponse {
  batchId: number;
  campaignName: string;
  totalGenerated: number;
  rewardPoints: number;
  rewardTemplates: string[];
}

export interface RewardListResponse {
  data: Array<{
    id: number;
    deviceId: string;
    tier: number;
    source: string;
    sourceDetail: string | null;
    status: string;
    unlockedAt: number;
    claimedAt: number | null;
  }>;
  total: number;
  page: number;
  pageSize: number;
}

export interface CreateBatchInput {
  campaignName: string;
  codes: string[];
  rewardPoints: number;
  rewardTemplates?: string[];
  maxUsesPerCode: number;
  validFrom?: number;
  validUntil?: number;
}

export interface TemplateOption {
  id: string;
  name: string;
  price: number;
  coverUrl: string;
}

// 问卷数据类型（与 @lumira/shared 一致，admin 端单独定义避免跨包依赖）
export interface QuestionnaireRecord {
  id: number;
  deviceId: string;
  answersJson: string;
  submittedAt: number;
  clientIp: string | null;
}

export interface QuestionnaireListItem extends QuestionnaireRecord {
  deviceAlias: string | null;
}

export interface QuestionnaireListResponse {
  data: QuestionnaireListItem[];
  total: number;
  page: number;
  pageSize: number;
}

export interface QuestionnaireHistoryResponse {
  data: QuestionnaireRecord[];
  total: number;
}

export interface QuestionnaireStats {
  totalRespondents: number;
  source: Record<string, number>;
  favorite_categories: Record<string, number>;
  pain_points: Record<string, number>;
  skill_level: Record<string, number>;
  expectations: Record<string, number>;
  common_scenes: Record<string, number>;
  shoot_frequency: Record<string, number>;
}

// ===== 模板与分类管理（后端动态模板上传） =====
// 注：与 @lumira/shared 的 RemoteTemplate/TemplateCategory 类型对齐，
// 此处单独定义以避免在 shared 类型尚未落地时产生跨包依赖断裂。

export interface TemplateCategory {
  id: number;
  key: string;
  name: string;
  parentKey: string | null;
  level: number; // 1=type / 2=style / 3=method
  iconUrl: string;
  sortOrder: number;
  isSystem: boolean;
  isActive: boolean;
  updatedAt: number;
}

export interface TemplateCategoryTreeNode extends TemplateCategory {
  children: TemplateCategoryTreeNode[];
}

export interface TemplateCategoryListResponse {
  categories: TemplateCategory[];
}

export interface TemplateCategoryTreeResponse {
  tree: TemplateCategoryTreeNode[];
}

export interface AdminTemplateListItem {
  id: string;
  name: string;
  category: string;
  categoryName: string;
  price: number;
  coverUrl: string;
  isActive: boolean;
  sortOrder: number;
  createdAt: number;
  updatedAt: number;
}

export interface AdminTemplateListResponse {
  data: AdminTemplateListItem[];
  total: number;
  page: number;
  pageSize: number;
}

export interface AdminTemplateDetail extends AdminTemplateListItem {
  author: string;
  version: string;
  description: string;
  referenceSource: string;
  tags: string[];
  tagIds: string[];
  classification: { type: string; style: string; method: string };
  composition: Record<string, unknown>;
  pose: Record<string, unknown>;
  camera: Record<string, unknown>;
  sceneGuide: Record<string, unknown>;
  postProcess: Record<string, unknown>;
}

export interface CreateTemplateRequest {
  name: string;
  author?: string;
  version?: string;
  category: string;
  price: number;
  description?: string;
  referenceSource?: string;
  tags?: string[];
  tagIds?: string[];
  classification?: { type: string; style: string; method: string };
  sortOrder?: number;
  isActive?: boolean;
  composition?: Record<string, unknown>;
  pose?: Record<string, unknown>;
  camera?: Record<string, unknown>;
  sceneGuide?: Record<string, unknown>;
  postProcess?: Record<string, unknown>;
}

export interface UpdateTemplateRequest extends Partial<CreateTemplateRequest> {}

export interface CreateCategoryRequest {
  key: string;
  name: string;
  parentKey: string | null; // 一级为 null
  level: number; // 1/2/3
  iconUrl?: string;
  sortOrder?: number;
  isActive?: boolean;
}

export interface UpdateCategoryRequest extends Partial<Omit<CreateCategoryRequest, 'key'>> {}
