// lumira-server/packages/shared/src/types/template.ts
// 后台动态模板上传功能共享类型定义（spec 2026-08-05 第 2.4 节）

// ===== 分类 =====

export interface TemplateCategory {
  key: string;
  name: string;
  iconUrl: string;
  /** 简短描述（可为空，仅一/二级分类使用） */
  description: string;
  /** 父分类 key；一级分类为 null */
  parentKey: string | null;
  /** 层级：1=type / 2=majorStyle / 3=subStyle / 4=method */
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

/** 模板适用的季节/天气/时段色调（后续季节/天气推荐使用） */
export interface TemplateAmbience {
  /** 适用季节：spring / summer / autumn / winter，空数组=不限 */
  seasons: ('spring' | 'summer' | 'autumn' | 'winter')[];
  /** 适用天气：sunny / cloudy / overcast / rain / snow / fog（对齐 WeatherService 中文描述） */
  weathers: ('sunny' | 'cloudy' | 'overcast' | 'rain' | 'snow' | 'fog')[];
  /** 时段/色调倾向：goldenHour / day / night / warm / cool */
  timeTones: ('goldenHour' | 'day' | 'night' | 'warm' | 'cool')[];
}

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
  classification: { type: string; majorStyle: string; subStyle: string; method: string };
  /** 季节/天气/时段元数据 */
  ambience: TemplateAmbience;
  /** 短简介（≤10字） */
  shortDesc: string;
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
  classification: { type: string; majorStyle: string; subStyle: string; method: string };
  composition: Record<string, unknown>;
  pose: Record<string, unknown>;
  camera: Record<string, unknown>;
  sceneGuide: Record<string, unknown>;
  postProcess: Record<string, unknown>;
  /** 季节/天气/时段元数据 */
  ambience: TemplateAmbience;
  /** 短简介（≤10字） */
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
  classification?: { type: string; majorStyle: string; subStyle: string; method: string };
  /** 季节/天气/时段元数据（可选，缺省按空结构存储） */
  ambience?: TemplateAmbience;
  /** 短简介（≤10字，可选） */
  shortDesc?: string;
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
  /** 简短描述（可为空，仅一/二级分类使用） */
  description?: string;
  /** 父分类 key；省略或 null 表示一级分类 */
  parentKey?: string | null;
  sortOrder?: number;
  isActive?: boolean;
}

export interface UpdateCategoryRequest extends Partial<Omit<CreateCategoryRequest, 'key'>> {}
