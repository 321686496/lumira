// lumira-server/packages/backend/src/modules/ai/trend-research/research-vision.service.spec.ts
import { ResearchVisionService } from './research-vision.service';
import type { ResearchImage } from './research-image';

const img = (id: string): ResearchImage => ({
  id, url: `https://x/uploads/research/${id}.jpg`, sourceUrl: 'https://a.com/1.jpg', source: 'searxng', layer: 'metadata', bytes: 1000,
});

describe('ResearchVisionService.interpret', () => {
  it('无图 → null（不调用模型）', async () => {
    const svc = new ResearchVisionService({ getActiveConfig: async () => ({ text: {} }) } as never);
    let called = false;
    svc.chat = async () => { called = true; return '{}'; };
    expect(await svc.interpret('旗袍', [])).toBeNull();
    expect(called).toBe(false);
  });

  it('正常解析出结论与 adopted', async () => {
    const svc = new ResearchVisionService({ getActiveConfig: async () => ({ text: {} }) } as never);
    svc.chat = async () =>
      JSON.stringify({ summary: '暖调逆光', styles: ['新中式'], adopted: [{ id: 'aaaaaaaaaaaaaaaa', reason: '光线好' }] });
    const v = await svc.interpret('旗袍', [{ image: img('aaaaaaaaaaaaaaaa'), base64: 'AAA', mime: 'image/jpeg' }]);
    expect(v?.styles).toEqual(['新中式']);
    expect(v?.adopted).toEqual([{ id: 'aaaaaaaaaaaaaaaa', reason: '光线好' }]);
  });

  it('模型编造的 image id 被过滤', async () => {
    const svc = new ResearchVisionService({ getActiveConfig: async () => ({ text: {} }) } as never);
    svc.chat = async () => JSON.stringify({ scene: ['咖啡馆'], adopted: [{ id: 'ffffffffffffffff', reason: '不存在' }] });
    const v = await svc.interpret('主题', [{ image: img('aaaaaaaaaaaaaaaa'), base64: 'AAA', mime: 'image/jpeg' }]);
    expect(v?.adopted).toEqual([]);
    expect(v?.scene).toEqual(['咖啡馆']);
  });

  it('解析失败 / 调用抛错 → null', async () => {
    const svc = new ResearchVisionService({ getActiveConfig: async () => ({ text: {} }) } as never);
    svc.chat = async () => { throw new Error('AI 请求超时，请稍后重试'); };
    expect(await svc.interpret('主题', [{ image: img('aaaaaaaaaaaaaaaa'), base64: 'A', mime: 'image/jpeg' }])).toBeNull();
  });

  it('返回非 JSON → null', async () => {
    const svc = new ResearchVisionService({ getActiveConfig: async () => ({ text: {} }) } as never);
    svc.chat = async () => '这不是 JSON';
    expect(await svc.interpret('主题', [{ image: img('aaaaaaaaaaaaaaaa'), base64: 'A', mime: 'image/jpeg' }])).toBeNull();
  });
});
