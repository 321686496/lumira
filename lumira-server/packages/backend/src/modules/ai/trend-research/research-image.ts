// 参考图抓取的数据模型与常量（spec 2026-09-28-ai-research-reference-images-design.md 第 4 章）

/** 命中的哪一层：用户显式参考页面 / 检索条目自带图 / 命中页面解析 / 图片搜索兜底 */
export type ResearchImageLayer = 'user-reference' | 'metadata' | 'page' | 'image-search';

/** 一张已抓取落盘的参考图 */
export interface ResearchImage {
  /** 内容哈希（sha256 前 16 位）：去重键 + 落盘文件名 */
  id: string;
  /** 落盘后的公网可访问 URL */
  url: string;
  /** 原图地址（外链，仅作溯源展示，不保证可访问） */
  sourceUrl: string;
  /** 来源页面 URL（若图片来自网页解析） */
  pageUrl?: string;
  /** 来源标识：引擎名（searxng / qwen-official / vendor）或页面域名 */
  source: string;
  /** 命中的检索词 */
  query?: string;
  layer: ResearchImageLayer;
  width?: number;
  height?: number;
  bytes: number;
}

/** 参考图抓取整体结果 */
export interface ResearchImagesResult {
  images: ResearchImage[];
  /** 单条抓取失败原因（不阻断主流程） */
  errors: { name: string; error: string }[];
}

/** 参考图抓取配置（由 ai-config 提供） */
export interface ResearchImagesConfig {
  enabled: boolean;
  /** 每主题最多保留张数 */
  max: number;
  /** 是否启用第二层（抓页面 og:image） */
  pageFetch: boolean;
  /** 是否启用第三层（图片搜索兜底） */
  searchFallback: boolean;
  /** 是否启用多模态解读 */
  vision: boolean;
  /** 落盘图片保留天数 */
  ttlDays: number;
}

export const DEFAULT_RESEARCH_IMAGES_CONFIG: ResearchImagesConfig = {
  enabled: false,
  max: 6,
  pageFetch: true,
  searchFallback: true,
  vision: true,
  ttlDays: 7,
};

/** 尚未抓取的候选图 */
export interface ImageCandidate {
  sourceUrl: string;
  pageUrl?: string;
  source: string;
  query?: string;
  layer: ResearchImageLayer;
}

/** trace 事件里携带的精简图（只留展示必需字段，不含宽高/体积） */
export interface TraceImage {
  id: string;
  url: string;
  sourceUrl?: string;
  pageUrl?: string;
  source: string;
  query?: string;
}

export function toTraceImage(img: ResearchImage): TraceImage {
  return {
    id: img.id,
    url: img.url,
    sourceUrl: img.sourceUrl || undefined,
    pageUrl: img.pageUrl || undefined,
    source: img.source,
    query: img.query || undefined,
  };
}

export function toTraceImages(images: ResearchImage[]): TraceImage[] {
  return images.map(toTraceImage);
}

// ===== 管线护栏常量（spec 5.3 / 5.4）=====

/** 单张下载体积上限 */
export const RESEARCH_IMAGE_MAX_BYTES = 5 * 1024 * 1024;
/** 尺寸门槛：任一边小于此值丢弃 */
export const RESEARCH_IMAGE_MIN_SIDE = 400;
/** 落盘长边上限 */
export const RESEARCH_IMAGE_MAX_SIDE = 1280;
/** 落盘 JPEG 质量 */
export const RESEARCH_IMAGE_JPEG_QUALITY = 80;
/** 抓取并发上限 */
export const RESEARCH_IMAGE_CONCURRENCY = 3;
/** 整体软预算（超预算即停止抓取，用已得结果） */
export const RESEARCH_IMAGE_TOTAL_BUDGET_MS = 20_000;
/** 单图下载超时 */
export const RESEARCH_IMAGE_FETCH_TIMEOUT_MS = 5_000;
/** 单页 HTML 抓取超时 */
export const RESEARCH_IMAGE_PAGE_TIMEOUT_MS = 5_000;
/** 重定向最大跳数 */
export const RESEARCH_IMAGE_MAX_REDIRECTS = 3;
/** content-type 白名单 */
export const RESEARCH_IMAGE_ALLOWED_MIMES = ['image/jpeg', 'image/png', 'image/webp'];
