// lumira-server/packages/backend/src/modules/ai/trend-research/index.ts
// T1 趋势研究模块统一导出（Task 2~4）

export { createWebSearchProvider, cacheableSearch } from './web-search.provider';
export type { WebSearchProvider, WebSearchQuery } from './web-search.provider';
export type { ResearchItem } from './research-item';
export { createBingSearchProvider } from './web-search-bing';
export { createQwenSearchProvider } from './web-search-qwen';
export { createVendorSearchProvider } from './web-search-vendor';
export { TrendResearchService } from './trend-research.service';
export type { SearchConfig, SearchSourceConfig, SearchProviderFactory } from './trend-research.service';