// src/lib/api.ts
import { cookies } from 'next/headers';
import { AUTH_COOKIE_NAME, UnauthenticatedError } from './auth';
import { buildCategoryTree } from './category-tree';
import type {
  StatsResponse,
  DeviceListResponse,
  InviteListResponse,
  Batch,
  BatchDetail,
  CreateBatchResponse,
  CreateBatchInput,
  RewardListResponse,
  QuestionnaireListResponse,
  QuestionnaireHistoryResponse,
  QuestionnaireStats,
  AdminTemplateListResponse,
  AdminTemplateDetail,
  TemplateCategoryListResponse,
  TemplateCategoryTreeResponse,
  TemplateCategory,
  TemplateOption,
  UserPointsDetail,
  GrantPointsResponse,
  FeedbackAdminItem,
  FeedbackListResponse,
  NotificationAdminItem,
  NotificationPayload,
  BannerAdminItem,
  BannerPayload,
  AiProviderConfigView,
  UpdateAiConfigPayload,
  AiConfigTestResult,
  AiConfigTestTarget,
  AiAnalyzeResult,
  AiImageResult,
  AiImageTaskId,
  AiImageStatusResult,
  AiSilhouetteTaskId,
  AiSilhouetteStatusResult,
} from '@/types/admin';

// 重新导出纯函数，供 server-only 调用方使用（客户端组件请直接从 @/lib/category-tree 导入）
export { buildCategoryTree };

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';

/** AI 端点超时：生图内部 120s 请求 + 60s 轮询、剪影本地 ONNX CPU 推理均可能很慢，给足 5 分钟 */
const AI_ENDPOINT_TIMEOUT_MS = 300_000;

/**
 * 后端请求统一封装。
 * @param timeoutMs 可选超时（毫秒）：AI 生图 / 剪影等长耗时端点必须传，
 *   避免后端慢（ONNX CPU 推理）或网络中断时 fetch 永久挂起 → 前端按钮卡在"生成中"。
 */
async function adminFetch<T>(
  path: string,
  init?: RequestInit,
  timeoutMs?: number,
): Promise<T> {
  const token = cookies().get(AUTH_COOKIE_NAME)?.value;
  if (!token) {
    throw new UnauthenticatedError('No admin token');
  }

  const isFormData = init?.body instanceof FormData;
  const headers: Record<string, string> = {
    Authorization: `Bearer ${token}`,
    // FormData 时不设 Content-Type，让 fetch 自动设置 multipart boundary
    ...(!isFormData ? { 'Content-Type': 'application/json' } : {}),
    ...(init?.headers as Record<string, string> | undefined),
  };

  let res: Response;
  try {
    res = await fetch(`${BACKEND_URL}/api/v1/admin${path}`, {
      ...init,
      headers,
      cache: 'no-store',
      signal: timeoutMs ? AbortSignal.timeout(timeoutMs) : init?.signal,
    });
  } catch (e) {
    // 超时 / 网络中断 → 运营可读文案（否则 fetch 原生 message 不易理解）
    const name = (e as { name?: string } | null | undefined)?.name;
    if (name === 'TimeoutError' || name === 'AbortError') {
      throw new Error(
        `请求后端超时（${Math.round((timeoutMs ?? 0) / 1000)}s），可能后端处理较慢或网络不通，请稍后重试`,
      );
    }
    throw new Error('无法连接后端服务，请检查网络与后端状态');
  }

  if (res.status === 401) {
    throw new UnauthenticatedError('Token rejected by backend');
  }
  if (!res.ok) {
    // 尽量透传后端错误消息（如「封面图片不能超过 5MB」），否则退回 statusText
    let detail = '';
    try {
      const text = await res.text();
      if (text) {
        const parsed = JSON.parse(text) as { message?: unknown };
        const msg = parsed?.message;
        if (typeof msg === 'string') detail = msg;
        else if (Array.isArray(msg)) detail = msg.join('; ');
      }
    } catch {
      // 忽略 body 解析失败，使用默认 statusText
    }
    throw new Error(detail
      ? `API_ERROR: ${res.status} ${detail}`
      : `API_ERROR: ${res.status} ${res.statusText}`);
  }
  // 部分写操作（DELETE）可能返回空 body
  const text = await res.text();
  if (!text) {
    if (init?.method === 'DELETE') return undefined as T;
    throw new Error('后端返回空响应，请检查后端日志后重试');
  }
  return JSON.parse(text) as T;
}

// ===== 场景管理 / 使用次数（admin 前缀）=====
export interface AdminScene {
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

export interface UsageStatsItem {
  itemId: string;
  itemType: 'template' | 'scene';
  useShoot: number;
  openDetail: number;
  sceneSelect: number;
}

/**
 * 模板/场景使用次数汇总（admin 专用，走 AdminAuthGuard）。
 * best-effort 读取：任何失败都静默返回 []，不影响主列表渲染。
 */
export async function getUsageStats(
  itemType: 'template' | 'scene',
): Promise<UsageStatsItem[]> {
  try {
    const data = await adminFetch<{ items?: UsageStatsItem[] }>(`/usage/stats?itemType=${itemType}`);
    return Array.isArray(data?.items) ? data.items : [];
  } catch {
    return [];
  }
}

export interface BuiltinTemplate {
  id: string;
  name: string;
}

export interface BuiltinScene {
  id: string;
  name: string;
}

/**
 * 后台读取 App 内置模板 id/名称。best-effort：失败静默返回 []，不影响主列表。
 */
export async function getBuiltinTemplates(): Promise<BuiltinTemplate[]> {
  try {
    const data = await adminFetch<{ items?: BuiltinTemplate[] }>('/usage/builtin-templates');
    return Array.isArray(data?.items) ? data.items : [];
  } catch {
    return [];
  }
}

/**
 * 后台读取 App 内置场景 id/名称。best-effort：失败静默返回 []，不影响主列表。
 */
export async function getBuiltinScenes(): Promise<BuiltinScene[]> {
  try {
    const data = await adminFetch<{ items?: BuiltinScene[] }>('/usage/builtin-scenes');
    return Array.isArray(data?.items) ? data.items : [];
  } catch {
    return [];
  }
}

// ===== 通知公告（admin 前缀）=====

/** 后端 /admin/notifications 返回的原始行：JSON 字段为字符串、isActive 为 0/1、时间为毫秒 */
interface NotificationAdminRow {
  id: string; title: string; body: string;
  iconKey: string; category: string;
  targetScope: string;
  targetDeviceIdsJson: string;
  targetCriteriaJson: string;
  startAt: number | null; endAt: number | null;
  isActive: number; sortOrder: number;
  createdAt: number; updatedAt: number;
}

function parseJsonArray(value: string): string[] {
  try {
    const arr = JSON.parse(value || '[]') as unknown;
    return Array.isArray(arr) ? arr.filter((x) => x != null).map(String) : [];
  } catch {
    return [];
  }
}

function parseJsonCriteria(value: string): Record<string, string[]> {
  try {
    const obj = JSON.parse(value || '{}') as Record<string, unknown>;
    const out: Record<string, string[]> = {};
    if (obj && typeof obj === 'object') {
      for (const [k, v] of Object.entries(obj)) {
        out[k] = Array.isArray(v) ? v.filter((x) => x != null).map(String) : [];
      }
    }
    return out;
  } catch {
    return {};
  }
}

export const api = {
  getStats: () => adminFetch<StatsResponse>('/stats'),

  getDevices: (params: { page?: number; pageSize?: number; search?: string } = {}) => {
    const search = new URLSearchParams();
    if (params.page) search.set('page', String(params.page));
    if (params.pageSize) search.set('pageSize', String(params.pageSize));
    if (params.search) search.set('search', params.search);
    const qs = search.toString();
    return adminFetch<DeviceListResponse>(`/devices${qs ? `?${qs}` : ''}`);
  },

  getInvites: (params: { page?: number; pageSize?: number; deviceId?: string } = {}) => {
    const search = new URLSearchParams();
    if (params.page) search.set('page', String(params.page));
    if (params.pageSize) search.set('pageSize', String(params.pageSize));
    if (params.deviceId) search.set('deviceId', params.deviceId);
    const qs = search.toString();
    return adminFetch<InviteListResponse>(`/invites${qs ? `?${qs}` : ''}`);
  },

  getBatches: () => adminFetch<Batch[]>('/redeem-batches'),

  getBatchTemplates: () => adminFetch<TemplateOption[]>('/redeem-batches/templates'),

  createBatch: (data: CreateBatchInput) =>
    adminFetch<CreateBatchResponse>('/redeem-batches', {
      method: 'POST',
      body: JSON.stringify(data),
    }),

  getBatchDetail: (id: number) => adminFetch<BatchDetail>(`/redeem-batches/${id}`),

  toggleBatch: (id: number, isActive: boolean) =>
    adminFetch<{ success: boolean }>(`/redeem-batches/${id}`, {
      method: 'PATCH',
      body: JSON.stringify({ isActive }),
    }),

  getRewards: (params: { page?: number; pageSize?: number; deviceId?: string } = {}) => {
    const search = new URLSearchParams();
    if (params.page) search.set('page', String(params.page));
    if (params.pageSize) search.set('pageSize', String(params.pageSize));
    if (params.deviceId) search.set('deviceId', params.deviceId);
    const qs = search.toString();
    return adminFetch<RewardListResponse>(`/rewards${qs ? `?${qs}` : ''}`);
  },

  getQuestionnaire: (params: { page?: number; pageSize?: number; deviceId?: string } = {}) => {
    const search = new URLSearchParams();
    if (params.page) search.set('page', String(params.page));
    if (params.pageSize) search.set('pageSize', String(params.pageSize));
    if (params.deviceId) search.set('deviceId', params.deviceId);
    const qs = search.toString();
    return adminFetch<QuestionnaireListResponse>(`/questionnaire${qs ? `?${qs}` : ''}`);
  },

  getQuestionnaireHistory: (deviceId: string) =>
    adminFetch<QuestionnaireHistoryResponse>(`/questionnaire/${deviceId}`),

  getQuestionnaireStats: () =>
    adminFetch<QuestionnaireStats>('/questionnaire/stats'),

  // ===== 模板管理 =====
  listTemplates: (params: { page?: number; pageSize?: number; isActive?: boolean } = {}) => {
    const search = new URLSearchParams();
    if (params.page) search.set('page', String(params.page));
    if (params.pageSize) search.set('pageSize', String(params.pageSize));
    if (params.isActive !== undefined) search.set('isActive', String(params.isActive));
    const qs = search.toString();
    return adminFetch<AdminTemplateListResponse>(`/templates${qs ? `?${qs}` : ''}`);
  },

  getTemplate: (id: string) => adminFetch<AdminTemplateDetail>(`/templates/${id}`),

  createTemplate: (formData: FormData) =>
    adminFetch<AdminTemplateDetail>('/templates', {
      method: 'POST',
      body: formData,
    }),

  updateTemplate: (id: string, formData: FormData) =>
    adminFetch<AdminTemplateDetail>(`/templates/${id}`, {
      method: 'PATCH',
      body: formData,
    }),

  deleteTemplate: (id: string) =>
    adminFetch<{ success: boolean }>(`/templates/${id}`, {
      method: 'DELETE',
    }),

  toggleTemplateActive: (id: string) =>
    adminFetch<{ success: boolean; isActive: boolean }>(
      `/templates/${id}/toggle-active`,
      { method: 'POST' },
    ),

  // ===== 分类管理 =====
  listCategories: (params: { isActive?: boolean; parentKey?: string } = {}) => {
    const search = new URLSearchParams();
    if (params.isActive !== undefined) search.set('isActive', String(params.isActive));
    if (params.parentKey !== undefined) search.set('parentKey', params.parentKey);
    const qs = search.toString();
    return adminFetch<TemplateCategoryListResponse>(`/categories${qs ? `?${qs}` : ''}`);
  },

  /**
   * 返回三级树形结构。优先调用后端 `/categories/tree`；若不可用则从扁平列表客户端构造。
   */
  listCategoryTree: async (params: { isActive?: boolean } = {}): Promise<TemplateCategoryTreeResponse> => {
    try {
      const search = new URLSearchParams();
      if (params.isActive !== undefined) search.set('isActive', String(params.isActive));
      const qs = search.toString();
      return await adminFetch<TemplateCategoryTreeResponse>(`/categories/tree${qs ? `?${qs}` : ''}`);
    } catch {
      // 后端未实现 /tree 端点时，从扁平列表构造
      const resp = await api.listCategories(params);
      return { tree: buildCategoryTree(resp.categories) };
    }
  },

  /**
   * 按父分类筛选子分类（调用后端 ?parentKey= 查询参数）。
   */
  listCategoriesByParent: (parentKey: string, params: { isActive?: boolean } = {}) => {
    const search = new URLSearchParams();
    search.set('parentKey', parentKey);
    if (params.isActive !== undefined) search.set('isActive', String(params.isActive));
    return adminFetch<TemplateCategoryListResponse>(`/categories?${search.toString()}`);
  },

  getCategory: (key: string) =>
    adminFetch<TemplateCategory>(`/categories/${key}`),

  createCategory: (formData: FormData) =>
    adminFetch<TemplateCategory>('/categories', {
      method: 'POST',
      body: formData,
    }),

  updateCategory: (key: string, formData: FormData, parentKey?: string | null) =>
    adminFetch<TemplateCategory>(
      `/categories/${key}${parentKey ? `?parentKey=${encodeURIComponent(parentKey)}` : ''}`,
      {
        method: 'PATCH',
        body: formData,
      },
    ),

  deleteCategory: (key: string, parentKey?: string | null) =>
    adminFetch<{ success: boolean }>(
      `/categories/${key}${parentKey ? `?parentKey=${encodeURIComponent(parentKey)}` : ''}`,
      { method: 'DELETE' },
    ),

  toggleCategoryActive: (key: string, parentKey?: string | null) =>
    adminFetch<{ success: boolean; isActive: boolean }>(
      `/categories/${key}/toggle-active${parentKey ? `?parentKey=${encodeURIComponent(parentKey)}` : ''}`,
      { method: 'POST' },
    ),

  // ===== 积分管理 =====

  getUserPoints: (deviceId: string) =>
    adminFetch<UserPointsDetail>(`/devices/${deviceId}/points`),

  grantPoints: (deviceId: string, delta: number, reason: string) =>
    adminFetch<GrantPointsResponse>(`/devices/${deviceId}/points/grant`, {
      method: 'POST',
      body: JSON.stringify({ delta, reason }),
    }),

  // ===== 反馈管理 =====
  listFeedbacks: (params: { page?: number; pageSize?: number; type?: string; status?: string } = {}) => {
    const search = new URLSearchParams();
    if (params.page) search.set('page', String(params.page));
    if (params.pageSize) search.set('pageSize', String(params.pageSize));
    if (params.type) search.set('type', params.type);
    if (params.status) search.set('status', params.status);
    const qs = search.toString();
    return adminFetch<FeedbackListResponse>(`/feedbacks${qs ? `?${qs}` : ''}`);
  },

  updateFeedbackStatus: (id: string, status: string) =>
    adminFetch<{ success: boolean; id: string; status: string }>(`/feedbacks/${id}`, {
      method: 'PATCH',
      body: JSON.stringify({ status }),
    }),

  // ===== 场景管理 =====
  listScenes: () => adminFetch<{ scenes?: AdminScene[] }>('/scenes'),

  createScene: (payload: Record<string, unknown>) =>
    adminFetch<AdminScene>('/scenes', {
      method: 'POST',
      body: JSON.stringify(payload),
    }),

  updateScene: (id: string, payload: Record<string, unknown>) =>
    adminFetch<AdminScene>(`/scenes/${encodeURIComponent(id)}`, {
      method: 'PATCH',
      body: JSON.stringify(payload),
    }),

  deleteScene: (id: string) =>
    adminFetch<{ success: boolean }>(`/scenes/${encodeURIComponent(id)}`, {
      method: 'DELETE',
    }),

  toggleScene: (id: string) =>
    adminFetch<{ id: string; isActive: boolean }>(
      `/scenes/${encodeURIComponent(id)}/toggle`,
      { method: 'POST' },
    ),

  // ===== 通知公告管理 =====
  /**
   * 返回通知列表。后端返回原始行（JSON 字段为字符串），此处解析成结构化的
   * targetDeviceIds / targetCriteria 以便前端直接渲染。
   */
  listNotifications: async (): Promise<NotificationAdminItem[]> => {
    const rows = await adminFetch<NotificationAdminRow[]>('/notifications');
    return (Array.isArray(rows) ? rows : []).map((r) => ({
      id: r.id,
      title: r.title,
      body: r.body,
      iconKey: r.iconKey,
      category: r.category,
      targetScope: r.targetScope as NotificationAdminItem['targetScope'],
      targetDeviceIds: parseJsonArray(r.targetDeviceIdsJson),
      targetCriteria: parseJsonCriteria(r.targetCriteriaJson),
      startAt: r.startAt ?? null,
      endAt: r.endAt ?? null,
      isActive: r.isActive,
      sortOrder: r.sortOrder,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    }));
  },

  createNotification: (payload: NotificationPayload) =>
    adminFetch<NotificationAdminRow>('/notifications', {
      method: 'POST',
      body: JSON.stringify(payload),
    }),

  updateNotification: (id: string, payload: NotificationPayload) =>
    adminFetch<NotificationAdminRow>(`/notifications/${encodeURIComponent(id)}`, {
      method: 'PATCH',
      body: JSON.stringify(payload),
    }),

  deleteNotification: (id: string) =>
    adminFetch<{ success: boolean }>(`/notifications/${encodeURIComponent(id)}`, {
      method: 'DELETE',
    }),

  toggleNotification: (id: string) =>
    adminFetch<{ id: string; isActive: boolean }>(
      `/notifications/${encodeURIComponent(id)}/toggle`,
      { method: 'POST' },
    ),

  // ===== 运营 Banner 管理 =====
  listBanners: () => adminFetch<BannerAdminItem[]>('/banners'),

  createBanner: (payload: BannerPayload) =>
    adminFetch<BannerAdminItem>('/banners', {
      method: 'POST',
      body: JSON.stringify(payload),
    }),

  updateBanner: (id: string, payload: BannerPayload) =>
    adminFetch<BannerAdminItem>(`/banners/${encodeURIComponent(id)}`, {
      method: 'PATCH',
      body: JSON.stringify(payload),
    }),

  deleteBanner: (id: string) =>
    adminFetch<{ success: boolean }>(`/banners/${encodeURIComponent(id)}`, {
      method: 'DELETE',
    }),

  toggleBanner: (id: string) =>
    adminFetch<{ id: string; isActive: boolean }>(
      `/banners/${encodeURIComponent(id)}/toggle`,
      { method: 'POST' },
    ),

  /** 上传 Banner 配图（multipart，file 字段名 image）→ { url } */
  uploadBannerImage: (formData: FormData) =>
    adminFetch<{ url: string }>('/banners/upload', {
      method: 'POST',
      body: formData,
    }),

  // ===== AI 一键模板录入 =====
  getAiConfig: () =>
    adminFetch<AiProviderConfigView | { configured: false }>('/ai-config'),

  saveAiConfig: (payload: UpdateAiConfigPayload) =>
    adminFetch<AiProviderConfigView>('/ai-config', {
      method: 'PUT',
      body: JSON.stringify(payload),
    }),

  testAiConfig: (payload?: { targets?: AiConfigTestTarget[] }) =>
    adminFetch<AiConfigTestResult>('/ai-config/test', {
      method: 'POST',
      body: JSON.stringify(payload ?? {}),
    }),

  /** multipart：image 文件（示例图，可选）+ text/textDesc 文字描述（可选，至少其一）+ creationReq/poseCount。AI 识别耗时较长，超时 300s */
  aiAnalyze: (formData: FormData) =>
    adminFetch<AiAnalyzeResult>('/templates/ai-analyze', {
      method: 'POST',
      body: formData,
    }, AI_ENDPOINT_TIMEOUT_MS),

  /** 提交生图任务（multipart meta + reference 可选 + extraPrompt 附加提示词可选）→ 立即返回 taskId */
  aiGenerateImageStart: (formData: FormData) =>
    adminFetch<AiImageTaskId>('/templates/ai-generate-image', {
      method: 'POST',
      body: formData,
    }, AI_ENDPOINT_TIMEOUT_MS),

  /** 查询生图任务状态（done 带 image/mimeType；error 带 error） */
  aiGenerateImageStatus: (taskId: string) =>
    adminFetch<AiImageStatusResult>(`/templates/ai-generate-image/tasks/${taskId}`),

  /** multipart：image 文件 + meta JSON（{ mode, crop, engine }，可选）。异步任务只做提交，立即返回 */
  aiGenerateSilhouetteStart: (formData: FormData) =>
    adminFetch<AiSilhouetteTaskId>('/templates/ai-generate-silhouette/tasks', {
      method: 'POST',
      body: formData,
    }, AI_ENDPOINT_TIMEOUT_MS),

  /** 轮询剪影异步任务 */
  aiGenerateSilhouetteStatus: (taskId: string) =>
    adminFetch<AiSilhouetteStatusResult>(`/templates/ai-generate-silhouette/tasks/${taskId}`),

  /** 兼容保留：本地 ONNX 推理 / AI 生图均慢，同步端点超时 300s */
  aiGenerateSilhouette: (formData: FormData) =>
    adminFetch<AiImageResult>('/templates/ai-generate-silhouette', {
      method: 'POST',
      body: formData,
    }, AI_ENDPOINT_TIMEOUT_MS),
};
