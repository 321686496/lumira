// src/lib/api.ts
import { cookies } from 'next/headers';
import { AUTH_COOKIE_NAME, UnauthenticatedError } from './auth';
import type {
  StatsResponse,
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
  TemplateCategory,
} from '@/types/admin';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';

async function adminFetch<T>(path: string, init?: RequestInit): Promise<T> {
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

  const res = await fetch(`${BACKEND_URL}/api/v1/admin${path}`, {
    ...init,
    headers,
    cache: 'no-store',
  });

  if (res.status === 401) {
    throw new UnauthenticatedError('Token rejected by backend');
  }
  if (!res.ok) {
    throw new Error(`API_ERROR: ${res.status} ${res.statusText}`);
  }
  // 部分写操作（DELETE）可能返回空 body
  const text = await res.text();
  if (!text) return undefined as T;
  return JSON.parse(text) as T;
}

export const api = {
  getStats: () => adminFetch<StatsResponse>('/stats'),

  getInvites: (params: { page?: number; pageSize?: number; deviceId?: string } = {}) => {
    const search = new URLSearchParams();
    if (params.page) search.set('page', String(params.page));
    if (params.pageSize) search.set('pageSize', String(params.pageSize));
    if (params.deviceId) search.set('deviceId', params.deviceId);
    const qs = search.toString();
    return adminFetch<InviteListResponse>(`/invites${qs ? `?${qs}` : ''}`);
  },

  getBatches: () => adminFetch<Batch[]>('/redeem-batches'),

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
  listCategories: (params: { isActive?: boolean } = {}) => {
    const search = new URLSearchParams();
    if (params.isActive !== undefined) search.set('isActive', String(params.isActive));
    const qs = search.toString();
    return adminFetch<TemplateCategoryListResponse>(`/categories${qs ? `?${qs}` : ''}`);
  },

  getCategory: (key: string) =>
    adminFetch<TemplateCategory>(`/categories/${key}`),

  createCategory: (formData: FormData) =>
    adminFetch<TemplateCategory>('/categories', {
      method: 'POST',
      body: formData,
    }),

  updateCategory: (key: string, formData: FormData) =>
    adminFetch<TemplateCategory>(`/categories/${key}`, {
      method: 'PATCH',
      body: formData,
    }),

  deleteCategory: (key: string) =>
    adminFetch<{ success: boolean }>(`/categories/${key}`, {
      method: 'DELETE',
    }),

  toggleCategoryActive: (key: string) =>
    adminFetch<{ success: boolean; isActive: boolean }>(
      `/categories/${key}/toggle-active`,
      { method: 'POST' },
    ),
};
