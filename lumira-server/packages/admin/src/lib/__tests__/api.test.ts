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
      text: async () => JSON.stringify({ totalDevices: 1 }),
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
      text: async () => JSON.stringify({}),
    });
    const { api } = await import('../api');
    await expect(api.getBatchDetail(9999)).rejects.toThrow('API_ERROR: 404');
  });

  it('getBuiltinTemplates calls /usage/builtin-templates and returns items', async () => {
    fetchMock.mockResolvedValueOnce({
      ok: true,
      status: 200,
      text: async () => JSON.stringify({ items: [{ id: 'soft_portrait', name: '柔和人像' }] }),
    });
    const { getBuiltinTemplates } = await import('../api');
    const items = await getBuiltinTemplates();
    expect(items).toEqual([{ id: 'soft_portrait', name: '柔和人像' }]);
    expect(fetchMock).toHaveBeenCalledWith(
      expect.stringContaining('/api/v1/admin/usage/builtin-templates'),
      expect.anything(),
    );
  });

  it('getBuiltinScenes calls /usage/builtin-scenes and returns items', async () => {
    fetchMock.mockResolvedValueOnce({
      ok: true,
      status: 200,
      text: async () => JSON.stringify({ items: [{ id: 'cafe-window', name: '咖啡馆' }] }),
    });
    const { getBuiltinScenes } = await import('../api');
    const items = await getBuiltinScenes();
    expect(items).toEqual([{ id: 'cafe-window', name: '咖啡馆' }]);
    expect(fetchMock).toHaveBeenCalledWith(
      expect.stringContaining('/api/v1/admin/usage/builtin-scenes'),
      expect.anything(),
    );
  });

  it('aiGenerateImageStart POSTs to /ai-generate-image and returns taskId', async () => {
    fetchMock.mockResolvedValueOnce({
      ok: true,
      status: 200,
      text: async () => JSON.stringify({ taskId: 'img_abc123' }),
    });
    const { api } = await import('../api');
    const formData = new FormData();
    formData.set('meta', '{}');
    const result = await api.aiGenerateImageStart(formData);
    expect(result).toEqual({ taskId: 'img_abc123' });
    expect(fetchMock).toHaveBeenCalledWith(
      expect.stringContaining('/api/v1/admin/templates/ai-generate-image'),
      expect.objectContaining({ method: 'POST', body: formData }),
    );
  });

  it('testAiConfig posts selected targets', async () => {
    fetchMock.mockResolvedValueOnce({
      ok: true,
      status: 200,
      text: async () => JSON.stringify({ vision: { ok: true }, note: 'ok' }),
    });
    const { api } = await import('../api');
    const result = await api.testAiConfig({ targets: ['vision', 'image'] });
    expect(result).toEqual({ vision: { ok: true }, note: 'ok' });
    const [, init] = fetchMock.mock.calls[0];
    expect(init).toMatchObject({
      method: 'POST',
      body: JSON.stringify({ targets: ['vision', 'image'] }),
      headers: expect.objectContaining({ 'Content-Type': 'application/json' }),
    });
  });

  it('aiGenerateImageStatus GETs the task and returns done result', async () => {
    fetchMock.mockResolvedValueOnce({
      ok: true,
      status: 200,
      text: async () =>
        JSON.stringify({ taskId: 'img_abc123', status: 'done', image: 'aGVsbG8=', mimeType: 'image/png' }),
    });
    const { api } = await import('../api');
    const result = await api.aiGenerateImageStatus('img_abc123');
    expect(result).toEqual({
      taskId: 'img_abc123',
      status: 'done',
      image: 'aGVsbG8=',
      mimeType: 'image/png',
    });
    expect(fetchMock).toHaveBeenCalledWith(
      expect.stringContaining('/api/v1/admin/templates/ai-generate-image/tasks/img_abc123'),
      expect.objectContaining({
        headers: expect.objectContaining({ Authorization: 'Bearer test-token' }),
      }),
    );
  });
});
