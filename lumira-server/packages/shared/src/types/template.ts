// lumira-server/packages/shared/src/types/template.ts
// 后台动态模板上传功能共享类型定义（spec 2026-08-05 第 2.4 节）

// ===== 分类 =====

export interface TemplateCategory {
  key: string;
  name: string;
  iconUrl: string;
  /** 父分类 key；一级分类为 null */
  parentKey: string | null;
  /** 层级：1=type / 2=style / 3=method */
  level: number;
  sortOrder: number;
  isSystem: boolean;
  isActive: boolean;
  updatedAt: number;
}

export interface TemplateCategoryListResponse {
  categories: TemplateCategory[];
}

/** 树形分类节点（含 children 嵌套） */
export interface TemplateCategoryTree extends TemplateCategory {
  children: TemplateCategoryTree[];
}

export interface TemplateCategoryTreeResponse {
  categories: TemplateCategoryTree[];
}

// ===== 后端动态模板 meta（列表用，轻量）=====

export interface RemoteTemplateMeta {
  id: string;
  name: string;
  author: string;
  version: string;
  category: string;
  price: number;
  coverUrl: string;
  description: string;
  referenceSource: string;
  tags: string[];
  tagIds: string[];
  classification: { type: string; style: string; method: string };
  sortOrder: number;
  updatedAt: number;
}

export interface RemoteTemplateListResponse {
  templates: RemoteTemplateMeta[];
  serverUpdatedAt: number;
}

// ===== 后端动态模板完整内容（详情用）=====

export interface RemoteTemplateDetail extends RemoteTemplateMeta {
  composition: Record<string, unknown>;
  pose: Record<string, unknown>;
  camera: Record<string, unknown>;
  sceneGuide: Record<string, unknown>;
  postProcess: Record<string, unknown>;
}

// ===== Admin 管理用 =====

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
  iconUrl?: string;
  /** 父分类 key；省略或 null 表示一级分类 */
  parentKey?: string | null;
  sortOrder?: number;
  isActive?: boolean;
}

export interface UpdateCategoryRequest extends Partial<Omit<CreateCategoryRequest, 'key'>> {}
