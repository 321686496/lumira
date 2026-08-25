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

/** 效果图（[0]=封面） */
export interface TemplateImage {
  url: string;
  /** base64 data URL（可选，内置模板用） */
  data?: string;
}

/** 姿势剪影（多姿势 Phase 3 起新结构） */
export interface TemplatePose {
  name?: string;
  description?: string;
  silhouette: { type: string; data?: string; url?: string };
  position: { x: number; y: number };
  scale: number;
  rotation: number;
}

/** 三级分类：大类(type) → 风格(majorStyle) → 子风格(style)；method 不再作为树层级（兼容保留） */
export interface TemplateClassification {
  type: string;
  majorStyle: string;
  style: string;
  /** 兼容旧数据/旧 App：等同于 style 的旧字段名 */
  subStyle?: string;
  /** 兼容旧数据：不再作为分类树层级 */
  method?: string;
}

export interface RemoteTemplateMeta {
  id: string;
  name: string;
  author: string;
  version: string;
  category: string;
  price: number;
  /** 封面 URL（保留，= images[0].url 派生，兼容旧 App） */
  coverUrl: string;
  /** 效果图列表（[0]=封面）。旧数据由 cover_url 派生单元素。 */
  images?: TemplateImage[];
  /** 姿势组。旧数据由 pose 派生单元素。 */
  poses?: TemplatePose[];
  description: string;
  referenceSource: string;
  tags: string[];
  tagIds: string[];
  classification: TemplateClassification;
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

// ===== 模板搜索（客户端实时搜索线上模板）=====

/** 模板搜索排序方式。 */
export type TemplateSearchSort = 'comprehensive' | 'hot' | 'latest' | 'photos' | 'name';

/** 模板搜索结果项：在 meta 基础上附加全站热度/拍摄/查看计数。 */
export interface TemplateSearchItem extends RemoteTemplateMeta {
  /** 全站热度 = 2×全站拍摄数 + 1×全站查看数（火爆排序用）。 */
  hotScore: number;
  /** 全站拍摄数（use_shoot），拍摄数排序用。 */
  shootCount: number;
  /** 全站查看数（open_detail）。 */
  openCount: number;
}

export interface TemplateSearchResponse {
  items: TemplateSearchItem[];
  total: number;
  page: number;
  pageSize: number;
}

// ===== 后端动态模板完整内容（详情用）=====

export interface RemoteTemplateDetail extends RemoteTemplateMeta {
  composition: Record<string, unknown>;
  /** 兼容旧 App：首个姿势（poses[0]） */
  pose: Record<string, unknown>;
  /** 姿势组（多姿势；旧数据由 pose 派生单元素） */
  poses?: TemplatePose[];
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
  classification: TemplateClassification;
  composition: Record<string, unknown>;
  /** 兼容旧 admin：首个姿势（poses[0]） */
  pose: Record<string, unknown>;
  /** 姿势组（多姿势） */
  poses?: TemplatePose[];
  /** 效果图列表（[0]=封面） */
  images?: TemplateImage[];
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
  classification?: TemplateClassification;
  /** 季节/天气/时段元数据（可选，缺省按空结构存储） */
  ambience?: TemplateAmbience;
  /** 短简介（≤10字，可选） */
  shortDesc?: string;
  sortOrder?: number;
  isActive?: boolean;
  composition?: Record<string, unknown>;
  /** 兼容旧 admin：单个姿势（poses 优先） */
  pose?: Record<string, unknown>;
  /** 姿势组（多姿势，优先于 pose） */
  poses?: TemplatePose[];
  /** 效果图列表（[0]=封面，优先于 cover 文件上传） */
  images?: TemplateImage[];
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
