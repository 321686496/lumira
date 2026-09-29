// lumira-server/packages/backend/src/modules/ai/ai-upstream-error.spec.ts
import { AiUpstreamError, classifyUpstreamError, isRetryableUpstream } from './ai-upstream-error';

describe('AiUpstreamError', () => {
  it('结构化错误原样透传 code/status/upstream/failedIndexes', () => {
    const err = new AiUpstreamError('upstream_timeout', 'AI 请求超时，请稍后重试', {
      status: 504,
      upstream: 'gateway timeout',
      failedIndexes: [1],
    });
    const r = classifyUpstreamError(err);
    expect(err.code).toBe('upstream_timeout');
    expect(err.status).toBe(504);
    expect(r).toEqual({
      code: 'upstream_timeout',
      message: 'AI 请求超时，请稍后重试',
      status: 504,
      upstream: 'gateway timeout',
      failedIndexes: [1],
    });
  });

  it('既有中文文案（未结构化）按规则推断 code', () => {
    expect(classifyUpstreamError(new Error('AI 请求超时，请稍后重试')).code).toBe('upstream_timeout');
    expect(classifyUpstreamError(new Error('AI 服务无法连接，请检查 baseUrl')).code).toBe('network');
    expect(classifyUpstreamError(new Error('AI 服务返回内容为空')).code).toBe('upstream_empty');
    expect(classifyUpstreamError(new Error('生图失败：HTTP 503 Service Unavailable'))).toEqual({
      code: 'upstream_http',
      message: '生图失败：HTTP 503 Service Unavailable',
      status: 503,
      upstream: '生图失败：HTTP 503 Service Unavailable',
    });
    expect(classifyUpstreamError(new Error('AI 服务认证失败（apiKey 无效或无权限/欠费），请到后台「AI 设置」检查')).code).toBe(
      'upstream_http',
    );
    expect(classifyUpstreamError(new Error('完全看不懂的异常')).code).toBe('internal');
  });

  it('非 Error 入参不炸，返回 internal', () => {
    expect(classifyUpstreamError('字符串错误').code).toBe('internal');
    expect(classifyUpstreamError(undefined).code).toBe('internal');
  });

  it('可重试判定：超时/空响应/网络可重试；5xx 与 429 可重试，4xx 不可', () => {
    expect(isRetryableUpstream('upstream_timeout')).toBe(true);
    expect(isRetryableUpstream('upstream_empty')).toBe(true);
    expect(isRetryableUpstream('network')).toBe(true);
    expect(isRetryableUpstream('upstream_http', 503)).toBe(true);
    expect(isRetryableUpstream('upstream_http', 429)).toBe(true);
    expect(isRetryableUpstream('upstream_http', 400)).toBe(false);
    expect(isRetryableUpstream('internal')).toBe(false);
  });
});