// src/types/admin.ts
// 后台专用类型（与 @lumira/shared 互补）

import type { TemplateImage, TemplatePose } from '@lumira/shared';

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

export interface DeviceRecord {
  deviceId: string;
  alias: string | null;
  platform: string | null;
  osVersion: string | null;
  deviceModel: string | null;
  appVersion: string | null;
  firstSeenAt: number;
  lastSeenAt: number;
  ipRegion: string | null;
  username: string | null;
  avatarSeed: string | null;
  // 个人资料（个人中心 + 问卷同步）
  gender: string | null;
  favoriteCategories: string[];
  painPoints: string[];
  skillLevel: string | null;
  expectations: string[];
  commonScenes: string[];
  shootFrequency: string | null;
  avatarUrl: string | null;
  profileUpdatedAt: number | null;
  pointsBalance: number | null;
}

export interface UserPointsDetail {
  deviceId: string;
  balance: number;
  totalEarned: number;
  totalSpent: number;
  transactions: Array<{
    id: number;
    deviceId: string;
    delta: number;
    type: string;
    refId: string | null;
    createdAt: number;
  }>;
}

export interface GrantPointsResponse {
  success: boolean;
  balance: number;
}

export interface DeviceListResponse {
  data: DeviceRecord[];
  total: number;
  page: number;
  pageSize: number;
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
  level: number; // 1=type / 2=majorStyle / 3=subStyle / 4=method
  iconUrl: string;
  /** 简短描述（可为空，仅一/二级分类使用） */
  description: string;
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

export interface TemplateAmbience {
  seasons: string[];
  weathers: string[];
  timeTones: string[];
}

export interface AdminTemplateDetail extends AdminTemplateListItem {
  author: string;
  version: string;
  description: string;
  referenceSource: string;
  tags: string[];
  tagIds: string[];
  classification: { type: string; majorStyle: string; style: string; subStyle?: string; method?: string };
  composition: Record<string, unknown>;
  pose: Record<string, unknown>;
  poses?: TemplatePose[];
  images?: TemplateImage[];
  camera: Record<string, unknown>;
  sceneGuide: Record<string, unknown>;
  postProcess: Record<string, unknown>;
  ambience: TemplateAmbience;
  shortDesc: string;
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
  classification?: { type: string; majorStyle: string; style: string; subStyle?: string; method?: string };
  ambience?: TemplateAmbience;
  shortDesc?: string;
  sortOrder?: number;
  isActive?: boolean;
  composition?: Record<string, unknown>;
  pose?: Record<string, unknown>;
  poses?: TemplatePose[];
  images?: TemplateImage[];
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
  /** 简短描述（可为空，仅一/二级分类使用） */
  description?: string;
  sortOrder?: number;
  isActive?: boolean;
}

export interface UpdateCategoryRequest extends Partial<Omit<CreateCategoryRequest, 'key'>> {}

// ===== 意见反馈管理 =====
export interface FeedbackAdminItem {
  id: string;
  deviceId: string;
  type: string;
  content: string;
  contact: string | null;
  status: string;
  screenshots: string[];
  createdAt: number;
  clientIp: string | null;
}

export interface FeedbackListResponse {
  data: FeedbackAdminItem[];
  total: number;
  page: number;
  pageSize: number;
}

// ===== 通知公告管理 =====
export interface NotificationAdminItem {
  id: string; title: string; body: string;
  iconKey: string; category: string;
  targetScope: 'all' | 'devices' | 'criteria';
  targetDeviceIds: string[];        // 从 targetDeviceIdsJson 解析
  targetCriteria: Record<string, string[]>;
  startAt?: number | null; endAt?: number | null;
  isActive: number; sortOrder: number;
  createdAt: number; updatedAt: number;
}

/** 通知公告 payload（发送给后端时，JSON 字段需序列化为字符串键 targetDeviceIdsJson / targetCriteriaJson） */
export interface NotificationPayload {
  id?: string;
  title?: string;
  body?: string;
  iconKey?: string;
  category?: string;
  targetScope?: 'all' | 'devices' | 'criteria';
  targetDeviceIdsJson?: string;
  targetCriteriaJson?: string;
  startAt?: number | null;
  endAt?: number | null;
  isActive?: boolean;
  sortOrder?: number;
}

// ===== 运营 Banner 管理 =====
/** 后端 /admin/banners 返回的原始行（isActive 为 0/1、时间为秒级 INT） */
export interface BannerAdminItem {
  id: string;
  title: string;
  subtitle: string;
  tag: string;
  route: string;
  /** 配图完整 URL（空串 = 无配图） */
  imageUrl: string;
  condition: string;
  isActive: number;
  sortOrder: number;
  createdAt: number;
  updatedAt: number;
}

/** 运营 Banner 新建/编辑 payload（id 仅新建时可传） */
export interface BannerPayload {
  id?: string;
  title?: string;
  subtitle?: string;
  tag?: string;
  route?: string;
  /** 配图 URL：空串清除配图 */
  imageUrl?: string;
  condition?: string;
  isActive?: boolean;
  sortOrder?: number;
}

// ===== AI 一键模板录入 =====

/** 模态独立平台（GET/PUT /admin/ai-config 视图；apiKey 脱敏） */
export interface AiPlatformOverride {
  provider: string;
  baseUrl: string;
  apiKeyMasked: string;
}

/** GET/PUT /admin/ai-config 返回（apiKey 脱敏；未配置时 configured=false） */
export interface AiProviderConfigView {
  configured: boolean;
  provider: string;
  baseUrl: string;
  apiKeyMasked: string;
  visionModel: string;
  imageModel: string;
  /** 存储值（'' = 未配置独立文本模型） */
  textModel: string;
  /** 有效文本模型 = textModel || visionModel */
  effectiveTextModel: string;
  /** 文本模态独立平台（null = 跟随共享平台） */
  textPlatform: AiPlatformOverride | null;
  /** 生图模态独立平台（null = 跟随共享平台） */
  imagePlatform: AiPlatformOverride | null;
  /** 剪影专用模型：null = 与生图模型一致 */
  silhouetteModel: string | null;
  enabled: boolean;
}

/** PUT /admin/ai-config 请求体（apiKey 空串/缺省 = 不修改原值，首次保存必填） */
export interface UpdateAiConfigPayload {
  provider: string;
  baseUrl: string;
  apiKey?: string;
  visionModel: string;
  imageModel: string;
  /** 空串/缺省 = 清除（回退视觉模型） */
  textModel?: string;
  /** 剪影专用模型：空串/缺省 = 与生图模型一致 */
  silhouetteModel?: string;
  enabled: boolean;
  /** 文本模态独立平台：提供 provider = 启用（需 textBaseUrl + textModel + 首次需 apiKey）；缺省 = 清除 */
  textProvider?: string;
  textBaseUrl?: string;
  textApiKey?: string;
  /** 生图模态独立平台：语义同上 */
  imageProvider?: string;
  imageBaseUrl?: string;
  imageApiKey?: string;
}

/** POST /admin/ai-config/test 可选目标（缺省 = 全部） */
export type AiConfigTestTarget = 'vision' | 'text' | 'image' | 'silhouette';

/** POST /admin/ai-config/test 结果（只包含请求的目标） */
export interface AiConfigTestResult {
  vision?: { ok: boolean; latencyMs?: number; error?: string };
  text?: { ok: boolean; latencyMs?: number; error?: string };
  image?: { ok: boolean; latencyMs?: number; error?: string };
  silhouette?: { ok: boolean; latencyMs?: number; error?: string };
  note: string;
}

/** POST /admin/templates/ai-analyze 结果（草稿 + 归一化警告） */
export interface AiAnalyzeResult {
  draft: Record<string, unknown>;
  warnings: string[];
}

/** POST /admin/templates/ai-generate-silhouette 结果（同步，image = base64） */
export interface AiImageResult {
  image: string;
  mimeType: string;
}

/** 提交生图任务 → 立即返回 taskId（异步任务式，前端轮询状态） */
export interface AiImageTaskId {
  taskId: string;
}

/** 查询生图任务状态（done 带 image/mimeType，error 带 error） */
export interface AiImageStatusResult {
  taskId: string;
  status: 'pending' | 'running' | 'done' | 'error';
  image?: string;
  mimeType?: string;
  error?: string;
}
