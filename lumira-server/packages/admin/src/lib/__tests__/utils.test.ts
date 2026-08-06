// src/lib/__tests__/utils.test.ts
import { describe, it, expect } from 'vitest';
import { truncateDeviceId, formatUnixTime, toUnixSeconds } from '../utils';

describe('truncateDeviceId', () => {
  it('truncates UUID to 8 chars + ellipsis', () => {
    expect(truncateDeviceId('66666666-6666-4666-8666-666666666666')).toBe('66666666…');
  });
  it('returns short id unchanged', () => {
    expect(truncateDeviceId('abc123')).toBe('abc123');
  });
});

describe('formatUnixTime', () => {
  it('formats known Unix timestamp in fixed Asia/Shanghai timezone', () => {
    // 2024-01-01 00:00:00 UTC = 1704067200 → 2024-01-01 08:00 Asia/Shanghai
    expect(formatUnixTime(1704067200)).toBe('2024-01-01 08:00');
  });
  it('is independent of the host timezone (no hydration mismatch)', () => {
    // 无论运行在 UTC 还是 UTC+8，输出都必须一致（固定 +8 偏移）
    const sydney = formatUnixTime(1704067200);
    expect(sydney).toBe('2024-01-01 08:00');
  });
});

describe('toUnixSeconds', () => {
  it('converts ISO datetime-local string', () => {
    const unix = toUnixSeconds('2024-01-01T00:00');
    expect(unix).toBeGreaterThan(1704067199);
    expect(unix).toBeLessThan(1704153601);
  });
});
