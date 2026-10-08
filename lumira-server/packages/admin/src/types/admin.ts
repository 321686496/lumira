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
  // 活跃度
  dau: number;
  mau: number;
  newDevicesThisMonth: number;
  // 平台分布
  platformBreakdown: Array<{ platform: string; count: number }>;
  // 用户画像
  profileBreakdown: {
    gender: Record<string, number>;
    skillLevel: Record<string, number>;
    shootFrequency: Record<string, number>;
  };
  // 积分健康
  totalPointsEarned: number;
  totalPointsSpent: number;
  totalPointsBalance: number;
  todaySignIns: number;
  todayPointEvents: number;
  // 内容健康度
  totalTemplates: number;
  activeTemplates: number;
  paidTemplates: number;
  pendingFeedbacks: number;
  inviteSuccessRate: number;
  totalBatches: number;
}

export interface TrendPoint {
  date: string; // "MM-DD"
  newDevices: number;
  dau: number;
  invites: number;
  redemptions: number;
  rewardUnlocks: number;
}

export interface TrendResponse {
  days: TrendPoint[];
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
  /** 该用户作为邀请人邀请的新用户数 */
  invitedCount: number;
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
    reason: string | null;
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
    /** 'pending'（待成片，奖励未发放）| 'success'（已达成，奖励已发放） */
    status: string;
    /** 达成成片时间（unix 秒），未达成时为 null */
    achievedAt: number | null;
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
  /** 适用性别（spec 2026-09-14）：'unisex'（通用）| 'male'（男）| 'female'（女） */
  gender?: string;
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
  gender?: 'unisex' | 'male' | 'female';
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
  /** 目标模板 id（route=/templates/detail 时必填） */
  templateId?: string;
  /** 配图完整 URL（空串 = 无配图） */
  imageUrl: string;
  /** 背景图焦点：0-1，缺失时 App 居中 */
  focusX?: number;
  focusY?: number;
  /** 背景图缩放：1-3，缺失时 App 使用 1 */
  focusZoom?: number;
  condition: string;
  /** 条目类型：operation=条件触达运营位 / ad=活动广告曝光 */
  kind: string;
  /** 广告位绝对槽位下标（0 起）；null=放最后 */
  position?: number | null;
  /** 广告点击跳转的外部 URL（kind=ad 时必填） */
  externalUrl?: string | null;
  /** App 内搜索关键字（kind=search 时必填） */
  searchKeyword?: string | null;
  /** 搜索范围：all=全部 / template=模板 / scene=场景 / academy=美学院 */
  searchScope?: string;
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
  /** 目标模板 id（route=/templates/detail 时必填） */
  templateId?: string;
  /** 配图 URL：空串清除配图 */
  imageUrl?: string;
  focusX?: number;
  focusY?: number;
  focusZoom?: number;
  condition?: string;
  /** 条目类型：operation / ad */
  kind?: string;
  /** 广告位绝对槽位下标（0 起）；留空/越界=放最后 */
  position?: number | null;
  /** 广告点击跳转的外部 URL（kind=ad 时必填） */
  externalUrl?: string | null;
  searchKeyword?: string | null;
  searchScope?: string;
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
  /** 剪影模态独立平台（null = 跟随生图模态） */
  silhouettePlatform: AiPlatformOverride | null;
  /** 剪影专用模型：null = 与生图模型一致 */
  silhouetteModel: string | null;
  enabled: boolean;
  /** 研究管线开关：true=启用；false=关闭 */
  searchEnabled: boolean;
  /** 网页爬取工具开关：true=启用（文本模型可调用 crawl_website）；false=关闭 */
  crawlEnabled: boolean;
  /** 网页爬取：单会话最大调用次数（1~6） */
  crawlMaxPerSession: number;
  /** 爬取静态失败时是否降级到无头渲染 */
  crawlRenderEnabled: boolean;
  /** 单次无头渲染超时（毫秒，5000~60000） */
  crawlRenderTimeoutMs: number;
  /** 已配置 cookie 的域名列表（只回显域名，值不回传） */
  crawlCookieDomains: string[];
  /** 搜索服务商：'general'（通用搜索 API）| 'vendor'（厂商联网检索）| 'qwen'（三方 MaaS）| 'qwen-official'（官方百炼）| null（未启用） */
  searchProvider: 'general' | 'vendor' | 'qwen' | 'qwen-official' | null;
  /** 通用搜索 API baseUrl（searchProvider=general 时使用） */
  searchBaseUrl: string;
  /** 通用搜索 API key（脱敏） */
  searchApiKeyMasked: string;
  /** 启用的搜索来源（searxng/vendor/baidu/qwen/qwen-official） */
  searchSources: string[];
  /** 站点限定（searxng 时使用，'' = 全站搜索） */
  searchSite: string;
  /** Qwen 模型自带搜索端点（searchProvider=qwen 时使用） */
  searchQwenBaseUrl: string;
  /** Qwen 搜索 API key（脱敏） */
  searchQwenApiKeyMasked: string;
  /** Qwen 搜索模型（缺省 = qwen-plus） */
  searchQwenModel: string;
  /** Qwen 官方百炼搜索端点（searchProvider=qwen-official 时使用） */
  searchQwenOfficialBaseUrl: string;
  /** Qwen 官方百炼搜索 API key（脱敏） */
  searchQwenOfficialApiKeyMasked: string;
  /** Qwen 官方百炼搜索模型（缺省 = qwen-plus） */
  searchQwenOfficialModel: string;
  /** 迭代上限（预算护栏） */
  maxIterations: number;
  /** 识别稳定性：失败后额外重试次数（默认 2） */
  llmRetryCount: number;
  /** 识别稳定性：单次 LLM 调用超时（毫秒，默认 300000） */
  llmTimeoutMs: number;
  /** 识别稳定性：单次 LLM 输出 token 上限（默认 8192） */
  llmMaxTokens: number;
  /** 生成任务并发上限（1~5） */
  jobConcurrency: number;
  /** 参考图抓取：开关 */
  researchImagesEnabled: boolean;
  /** 参考图抓取：最多保留张数 */
  researchImagesMax: number;
  /** 参考图抓取：命中页面 og:image 抓取 */
  researchImagesPageFetch: boolean;
  /** 参考图抓取：图片搜索兜底 */
  researchImagesSearchFallback: boolean;
  /** 参考图抓取：多模态解读 */
  researchImagesVision: boolean;
  /** 参考图抓取：图片保留天数 */
  researchImagesTtlDays: number;
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
  /** 剪影模态独立平台：语义同上 */
  silhouetteProvider?: string;
  silhouetteBaseUrl?: string;
  silhouetteApiKey?: string;
  /** 研究管线开关：true=启用；false/缺省 = 关闭 */
  searchEnabled?: boolean;
  /** 网页爬取工具开关：true=启用；false/缺省 = 关闭 */
  crawlEnabled?: boolean;
  /** 网页爬取：单会话最大调用次数（1~6，缺省沿用原值） */
  crawlMaxPerSession?: number;
  /** 是否降级到无头渲染；缺省 = 沿用原值 */
  crawlRenderEnabled?: boolean;
  /** 无头渲染超时（毫秒，5000~60000）；缺省 = 沿用原值 */
  crawlRenderTimeoutMs?: number;
  /** 按域名隔离的 cookie；缺省 = 保留存量，传入对象 = 整体覆盖 */
  crawlCookies?: Record<string, string>;
  /** 搜索服务商：'general' | 'vendor' | 'qwen' | 'qwen-official' | 'off'（关闭） */
  searchProvider?: string;
  searchBaseUrl?: string;
  searchApiKey?: string;
  /** 启用的搜索来源（searxng/vendor/baidu/qwen/qwen-official） */
  searchSources?: string[];
  /** 站点限定（searxng 时使用，空串/缺省 = 全站搜索） */
  searchSite?: string;
  searchQwenBaseUrl?: string;
  searchQwenApiKey?: string;
  searchQwenModel?: string;
  searchQwenOfficialBaseUrl?: string;
  searchQwenOfficialApiKey?: string;
  searchQwenOfficialModel?: string;
  /** 迭代上限（预算护栏 1~3） */
  maxIterations?: number;
  /** 识别稳定性：失败后额外重试次数（0~3） */
  llmRetryCount?: number;
  /** 识别稳定性：单次 LLM 调用超时（毫秒，10000~600000） */
  llmTimeoutMs?: number;
  /** 识别稳定性：单次 LLM 输出 token 上限（1024~16384） */
  llmMaxTokens?: number;
  /** 生成任务并发上限（1~5）；缺省 = 沿用原值 */
  jobConcurrency?: number;
  /** 参考图抓取：开关 */
  researchImagesEnabled?: boolean;
  /** 参考图抓取：最多保留张数（1~12） */
  researchImagesMax?: number;
  /** 参考图抓取：命中页面 og:image 抓取 */
  researchImagesPageFetch?: boolean;
  /** 参考图抓取：图片搜索兜底 */
  researchImagesSearchFallback?: boolean;
  /** 参考图抓取：多模态解读 */
  researchImagesVision?: boolean;
  /** 参考图抓取：图片保留天数（1~90） */
  researchImagesTtlDays?: number;
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
  /** 研究管线（orchestrator）启用时返回的 trace 轨迹；旧后端/关闭时缺省 */
  trace?: AiAnalyzeTraceEntry[];
  /** 参考图抓取管线产出的图片（旧后端/未启用时缺省） */
  researchImages?: AiResearchImage[];
  /** 参考图多模态解读结论（旧后端/未启用时缺省） */
  researchVision?: AiResearchVision | null;
}

/** AI 画像编排单步 trace（研究 / 识别 / 姿势面片 / 评分等阶段） */
export interface AiAnalyzeTraceEntry {
  step: string;
  tool?: string;
  resultBrief: string;
  score?: number;
}

/** 趋势研究命中的参考来源（供数据分析：AI 参考了哪些 URL） */
export interface AiResearchRef {
  source: string;
  title: string;
  snippet?: string;
  url?: string;
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

/** 提交批量姿势任务 → 立即返回批次 id（前端只轮询 GET batch/:batchId 一个接口） */
export interface AiImageBatchTaskId {
  batchId: string;
}

/** 批次内单张姿势图结果项（按 index 排序） */
export interface AiBatchResultItem {
  index: number;
  status: 'pending' | 'running' | 'done' | 'error';
  image?: string;
  mimeType?: string;
  error?: string;
  startedAt?: number;
  finishedAt?: number;
  prompt?: string;
  model?: string;
}

/** 批量姿势图的单条实时 trace 事件（seq 增量拉取与去重依据） */
export interface AiBatchImageTraceEvent {
  seq: number;
  ts: number;
  index: number;
  title: string;
  status: 'pending' | 'running' | 'done' | 'error';
  /** 事件种类：缺省 'pose'（姿势图生命周期）；'llm'/'search' 为该张图生成过程中的模型调用 */
  kind?: 'pose' | 'llm' | 'search';
  /** 一次调用的关联标识（kind=llm/search）：并发同名调用的 running/done 精确配对 */
  callId?: string;
  prompt?: string;
  model?: string;
  /** 模型调用的原始数据（kind='llm'/'search'） */
  systemPrompt?: string;
  userPrompt?: string;
  response?: string;
  rawResponse?: string;
  attempts?: number;
  error?: string;
  durationMs?: number;
}

/** 批量姿势图进度（total/completed/current/status/results/events；status=done 即全部处理完毕） */
export interface AiBatchStatusResult {
  batchId: string;
  total: number;
  completed: number;
  current: number;
  status: 'pending' | 'running' | 'done' | 'error';
  results: AiBatchResultItem[];
  createdAt: number;
  events: AiBatchImageTraceEvent[];
  lastSeq: number;
}

/** 查询生图任务状态（done 带 image/mimeType，error 带 error） */
export interface AiImageStatusResult {
  taskId: string;
  status: 'pending' | 'running' | 'done' | 'error';
  image?: string;
  mimeType?: string;
  error?: string;
}

/** 提交剪影异步任务 → 立即返回 taskId */
export interface AiSilhouetteTaskId {
  taskId: string;
}

/** 查询剪影任务状态（done 带 image/mimeType，error 带 error） */
export interface AiSilhouetteStatusResult {
  taskId: string;
  status: 'pending' | 'running' | 'done' | 'error';
  image?: string;
  mimeType?: string;
  error?: string;
}

/** 提交 AI 识别任务 → 立即返回 taskId（异步任务式，前端轮询状态） */
export interface AiAnalyzeTaskId {
  taskId: string;
}

/** 识别流程事件类型：阶段 / LLM 调用 / 联网检索 / 说明性节点 */
export type AiTraceEventType = 'step' | 'llm' | 'search' | 'note';
export type AiTraceEventStatus = 'running' | 'done' | 'fail';

/** 一条识别流程事件（后端 llm-trace 产出；前端按 seq 增量拉取，像聊天一样实时渲染） */
export interface AiTraceEvent {
  /** 递增序号（增量拉取与去重依据） */
  seq: number;
  /** 记录时间（ms epoch） */
  ts: number;
  type: AiTraceEventType;
  /** 阶段标识：reorganize / research / analyze / describe / poseRefSheet / paramValidate / imageScore / draftRefine / finalize */
  step: string;
  /** 父阶段标识（嵌套阶段 / 阶段内调用与说明）；顶层事件缺省 */
  parentStep?: string;
  /** 一次调用的关联标识（type=llm/search）：并发同名调用的 running/done 精确配对 */
  callId?: string;
  /** 阶段中文名 */
  title: string;
  status: AiTraceEventStatus;
  /** LLM 模型名 / 检索来源名 */
  model?: string;
  systemPrompt?: string;
  userPrompt?: string;
  /** 附带图片时的字节数（不展开 base64） */
  imageBytes?: number;
  /** 响应正文（LLM 输出 / 检索命中摘要） */
  response?: string;
  /** 上游原始响应体全文（LLM 为原始 JSON 文本；检索为原始返回） */
  rawResponse?: string;
  /** 实际发出的请求次数（含降级/重试；1 表示一次成功） */
  attempts?: number;
  /** 阶段结论简述 */
  resultBrief?: string;
  error?: string;
  durationMs?: number;
  /** 参考图抓取阶段产出的图片 */
  images?: Array<{ id: string; url: string; sourceUrl?: string; pageUrl?: string; source: string; query?: string }>;
  /** 参考图解读阶段被采纳的图片 id */
  adoptedImageIds?: string[];
}

/** 识别流程中展示的参考图（trace 事件 / 结果接口共用） */
export interface AiTraceImage {
  id: string;
  url: string;
  sourceUrl?: string;
  pageUrl?: string;
  source: string;
  query?: string;
}

/** 参考图抓取管线产出的图片（含尺寸与层级元信息） */
export interface AiResearchImage extends AiTraceImage {
  layer: string;
  width?: number;
  height?: number;
  bytes: number;
}

/** 参考图多模态解读结论 */
export interface AiResearchVision {
  summary: string;
  styles: string[];
  colorLight: string[];
  composition: string[];
  wardrobe: string[];
  scene: string[];
  adopted: { id: string; reason: string }[];
}

/** 趋势研究二次整理后的结构化结论（与后端 ResearchBrief 对齐） */
export interface AiResearchBrief {
  summary: string;
  themes: string[];
  styles: string[];
  colorLight: string[];
  visualElements: string[];
  seasons: string[];
  poseIdeas: string[];
  sources: { title: string; url?: string }[];
}

/** 查询 AI 识别任务状态（done 带 draft/warnings/trace/raw/research，error 带 error） */
export interface AiAnalyzeStatusResult {
  taskId: string;
  status: 'pending' | 'running' | 'done' | 'error';
  draft?: Record<string, unknown>;
  warnings?: string[];
  /** 研究管线（orchestrator）启用时返回的 trace 轨迹；旧后端/关闭时缺省 */
  trace?: AiAnalyzeTraceEntry[];
  /** LLM 直接吐出的原始结构化 JSON（extractJson 后、normalizeDraft 前） */
  raw?: Record<string, unknown>;
  /** 趋势研究命中的参考来源（含 URL） */
  research?: AiResearchRef[];
  /** 趋势研究结构化结论（生图阶段复用；旧后端/未启用时缺省） */
  researchBrief?: AiResearchBrief | null;
  /** 参考图抓取管线产出的图片（旧后端/未启用时缺省） */
  researchImages?: AiResearchImage[];
  /** 参考图多模态解读结论（旧后端/未启用时缺省） */
  researchVision?: AiResearchVision | null;
  /** 识别流程实时事件流（含每步提示词与响应，按 seq 递增） */
  events?: AiTraceEvent[];
  /** 已产生的最大 seq（下一次增量拉取的 since） */
  lastSeq?: number;
  error?: string;
}

// ===== AI 流水线 job（识别 → 姿势图 → 剪影；后端内存 job 承载，前端只持 jobId）=====
// 字段与后端 AiPipelineJobService.serialize() 的返回结构一一对应，勿单边改名。

/** 流水线阶段：analyze 示例图识别 / image 批量姿势图 / silhouette 剪影 */
export type AiPipelineStage = 'analyze' | 'image' | 'silhouette';
/** 单阶段状态 */
export type AiPipelineStageStatus = 'pending' | 'running' | 'done' | 'error';
/** job 整体状态（后端仅维护三态） */
export type AiPipelineJobStatus = 'running' | 'done' | 'error';
/** job 模式：auto 全自动（识别→姿势图→剪影）/ analyze-only 仅识别 */
export type AiPipelineJobMode = 'auto' | 'analyze-only';

/** 中断分类错误码（前端据此选文案与建议，不再靠中文正则猜） */
export type AiInterruptionCode =
  | 'job_missing'
  | 'upstream_timeout'
  | 'upstream_http'
  | 'upstream_empty'
  | 'poll_timeout'
  | 'network'
  | 'payload_too_large'
  | 'aborted'
  | 'invalid_input'
  | 'internal';

/** 一次中断的分层详情（后端 job 失败时权威给出；传输层失败由前端合成） */
export interface AiInterruptionInfo {
  code: AiInterruptionCode;
  stage: AiPipelineStage;
  /** 运营可读的粗粒度原因（保留上游原文中的关键信息） */
  message: string;
  /** 上游原始响应/异常文案（截断后） */
  upstream?: string;
  /** 上游 HTTP 状态码 */
  status?: number;
  /** 该阶段已耗时（ms） */
  elapsedMs?: number;
  /** 失败下标（示例图/姿势图/剪影，0-based） */
  failedIndexes?: number[];
  /** 处置建议 */
  hint?: string;
  /** 发生时间（ms epoch） */
  at: number;
}

/** 单阶段运行状态 */
export interface AiPipelineStageState {
  status: AiPipelineStageStatus;
  startedAt?: number;
  finishedAt?: number;
  error?: AiInterruptionInfo;
}

/** 流水线事件：在既有 AiTraceEvent 之上补 stage / index / prompt */
export interface AiPipelineEvent extends AiTraceEvent {
  stage: AiPipelineStage;
  /** 姿势图 / 剪影下标（0-based） */
  index?: number;
  /** 姿势图完成后的最终生图提示词 */
  prompt?: string;
}

/** 序列化返回的单张产物（base64） */
export interface AiPipelinePoseFile {
  index: number;
  base64: string;
  mimeType: string;
}

/** 单张产物的结构化失败 */
export interface AiPipelineStageFailure {
  index: number;
  error: string;
}

/** 查询流水线 job 状态（与后端 serialize() 返回结构一致） */
export interface AiPipelineStatusResult {
  jobId: string;
  status: AiPipelineJobStatus;
  mode: AiPipelineJobMode;
  stages: Record<AiPipelineStage, AiPipelineStageState>;
  error: AiInterruptionInfo | null;
  events: AiPipelineEvent[];
  lastSeq: number;
  draft: Record<string, unknown> | null;
  warnings: string[];
  trace: AiAnalyzeTraceEntry[];
  raw: Record<string, unknown> | null;
  research: AiResearchRef[];
  researchBrief: AiResearchBrief | null;
  researchImages: AiResearchImage[];
  researchVision: AiResearchVision | null;
  poseImages: AiPipelinePoseFile[];
  poseErrors: AiPipelineStageFailure[];
  silhouetteImages: AiPipelinePoseFile[];
  silhouetteErrors: AiPipelineStageFailure[];
}

/** 提交流水线 job → 立即返回 jobId */
export interface AiPipelineJobId {
  jobId: string;
}

/** resume 结果（resumed=false + status=running 表示任务仍在跑，前端只需重连） */
export interface AiPipelineResumeResult {
  resumed: boolean;
  status: AiPipelineJobStatus;
}

// ===== 图片存储迁移（R2 迁移）=====

export type StorageCategory = 'templates' | 'categories' | 'banners' | 'feedback' | 'users';

export type StorageId = 'local' | 'r2' | 'aliyun' | 'tencent' | 'qiniu';

export const STORAGE_OPTIONS: { value: StorageId; label: string }[] = [
  { value: 'local', label: '本地磁盘' },
  { value: 'r2', label: 'Cloudflare R2' },
  { value: 'aliyun', label: '阿里云 OSS' },
  { value: 'tencent', label: '腾讯云 COS' },
  { value: 'qiniu', label: '七牛云 Kodo' },
];

export interface StorageConfigView {
  id: StorageId;
  isActive: boolean;
  configured: boolean;
  endpoints: { endpoint?: string; bucket?: string; region?: string; publicUrl?: string };
  hasCredentials: boolean;
  secretMasked: string;
  updatedAt: number | null;
}

export interface StorageConfigPayload {
  endpoint?: string;
  accessKeyId?: string;
  secretAccessKey?: string;
  bucket?: string;
  region?: string;
  publicUrl?: string;
}

export interface CategoryReport {
  category: StorageCategory;
  dbTotal: number;
  diskTotal: number;
  migrated: number;
  copied: number;
  missingTarget: number;
  danglingDb: number;
  orphans: number;
  failed: number;
}

export interface MigrationTotals {
  db: number;
  disk: number;
  migrated: number;
  copied: number;
  missingTarget: number;
  danglingDb: number;
  orphans: number;
  failed: number;
}

export interface MigrationSummary {
  success: boolean;
  byCategory: Record<string, CategoryReport>;
  totals: MigrationTotals;
}

export interface FailureRecord {
  phase: 'copy' | 'verify';
  storageKey: string;
  entityLabel?: string;
  reason: string;
  at: number;
}

export interface MigrationRecordView {
  id: string;
  status: 'running' | 'success' | 'failed' | 'stopped';
  triggerBy: string;
  sourceId: StorageId;
  targetId: StorageId;
  startedAt: number;
  finishedAt: number | null;
  error: string | null;
  summary: MigrationSummary | null;
  failureFile: string | null;
  createdAt: number;
  failureDetail?: FailureRecord[];
}

export interface MigrationRunningView {
  running: boolean;
  id?: string;
  phase?: string;
  done?: number;
  total?: number;
  copied?: number;
}
