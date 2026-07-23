// src/lib/__tests__/api.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock next/headers and next/navigation
vi.mock('next/headers', () => ({
  cookies: () => ({ get: () => ({ value: 'test-token' }) }),
}));
vi.mock('next/navigation', () => ({
  redirect: (path: string) => { throw new Error(`REDIRECT:${path}`); },
}));

// Mock global fetch
const fetchMock = vi.fn();
global.fetch = fetchMock as any;

describe('api client', () => {
  beforeEach(() => {
    fetchMock.mockReset();
  });

  it('getStats calls /stats with Authorization header', async () => {
    fetchMock.mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: async () => ({ totalDevices: 1 }),
    });
    const { api } = await import('../api');
    const result = await api.getStats();
    expect(result).toEqual({ totalDevices: 1 });
    expect(fetchMock).toHaveBeenCalledWith(
      expect.stringContaining('/api/v1/admin/stats'),
      expect.objectContaining({
        headers: expect.objectContaining({
          Authorization: 'Bearer test-token',
        }),
      }),
    );
  });

  it('throws on 404', async () => {
    fetchMock.mockResolvedValueOnce({
      ok: false,
      status: 404,
      statusText: 'Not Found',
      json: async () => ({}),
    });
    const { api } = await import('../api');
    await expect(api.getBatchDetail(9999)).rejects.toThrow('API_ERROR: 404');
  });
});
