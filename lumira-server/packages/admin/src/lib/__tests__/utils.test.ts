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
  it('formats known Unix timestamp', () => {
    // 2024-01-01 00:00:00 UTC = 1704067200
    const result = formatUnixTime(1704067200);
    // 时区相关，只验证格式
    expect(result).toMatch(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/);
  });
});

describe('toUnixSeconds', () => {
  it('converts ISO datetime-local string', () => {
    const unix = toUnixSeconds('2024-01-01T00:00');
    expect(unix).toBeGreaterThan(1704067199);
    expect(unix).toBeLessThan(1704153601);
  });
});
