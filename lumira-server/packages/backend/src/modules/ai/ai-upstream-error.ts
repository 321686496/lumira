// lumira-server/packages/backend/src/modules/ai/ai-upstream-error.ts
// 上游（LLM / 生图 / 剪影 / 检索）错误的统一结构化表示。
// 目的：让 job 层按 code/status/upstream 归类生成中断详情，而不是靠正则猜中文文案。

export type UpstreamErrorCode =
  | 'upstream_timeout'
  | 'upstream_http'
  | 'upstream_empty'
  | 'network'
  | 'internal';

export interface AiUpstreamErrorOptions {
  status?: number;
  /** 原始上游响应片段（截断后） */
  upstream?: string;
  /** 触发该错误的图片/姿势下标（describe、生图、剪影逐张场景） */
  failedIndexes?: number[];
  cause?: unknown;
}

export class AiUpstreamError extends Error {
  readonly code: UpstreamErrorCode;
  readonly status?: number;
  readonly upstream?: string;
  readonly failedIndexes?: number[];

  constructor(code: UpstreamErrorCode, message: string, options: AiUpstreamErrorOptions = {}) {
    super(message);
    this.name = 'AiUpstreamError';
    this.code = code;
    this.status = options.status;
    this.upstream = options.upstream;
    this.failedIndexes = options.failedIndexes;
    if (options.cause !== undefined) {
      (this as { cause?: unknown }).cause = options.cause;
    }
  }
}

/** 可重试判定（供 LLM / 生图有界重试复用）：超时、空响应、网络抖动、5xx/429 可重试 */
export function isRetryableUpstream(code: UpstreamErrorCode, status?: number): boolean {
  if (code === 'upstream_timeout' || code === 'upstream_empty' || code === 'network') return true;
  if (code === 'upstream_http') return status === undefined || status === 429 || status >= 500;
  return false;
}

export interface ClassifiedUpstreamError {
  code: UpstreamErrorCode;
  message: string;
  status?: number;
  upstream?: string;
  failedIndexes?: number[];
}

/** 从既有中文文案推断 code（兼容尚未改造成结构化错误的调用方） */
function inferFromMessage(message: string): { code: UpstreamErrorCode; status?: number } {
  const httpMatch = /HTTP\s+(\d{3})/.exec(message);
  if (httpMatch) return { code: 'upstream_http', status: Number(httpMatch[1]) };
  if (/认证失败/.test(message)) return { code: 'upstream_http', status: 401 };
  if (/超时|Timeout|timeout/.test(message)) return { code: 'upstream_timeout' };
  if (/无法连接|连接失败|ECONN|fetch failed/.test(message)) return { code: 'network' };
  if (/返回内容为空|内容为空|EMPTY/.test(message)) return { code: 'upstream_empty' };
  return { code: 'internal' };
}

/** 归一化任意异常 → 可直接写入 InterruptionInfo 的结构 */
export function classifyUpstreamError(err: unknown): ClassifiedUpstreamError {
  if (err instanceof AiUpstreamError) {
    return {
      code: err.code,
      message: err.message,
      status: err.status,
      upstream: err.upstream,
      failedIndexes: err.failedIndexes,
    };
  }
  const message = (err as Error)?.message || String(err) || '未知错误';
  const inferred = inferFromMessage(message);
  return { code: inferred.code, message, status: inferred.status, upstream: message };
}