// lumira-server/packages/backend/src/modules/ai/trend-research/research-item.ts
// T1 趋势研究条目类型（Task 2）：统一网络搜索/厂商检索多源输出
// 设计文档：docs/superpowers/specs/2026-09-21-ai-template-trend-orchestrator-design.md T1

/** 一条研究/搜索结果 */
export interface ResearchItem {
  /** 来源标识（bing / vendor / baidu …） */
  source: string;
  title: string;
  /** 摘要片段 */
  snippet: string;
  /** 关键词（供中枢 vs 用户意图/季节做命中判断） */
  keywords: string[];
  /** 命中条目若带图则保留原图地址（交给 T2 队列识别） */
  imgUrl?: string;
  /** 原文链接 */
  url?: string;
  /** 发布时间（可解析字符串或 ISO） */
  date?: string;
  /** 热度（0~1，可选） */
  popularity?: number;
}