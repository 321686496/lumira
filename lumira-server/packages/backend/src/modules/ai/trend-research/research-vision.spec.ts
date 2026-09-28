import { normalizeVision, renderResearchVision, visionHasContent } from './research-vision';

describe('normalizeVision', () => {
  it('非对象 / 数组 / null → null', () => {
    expect(normalizeVision(null)).toBeNull();
    expect(normalizeVision([])).toBeNull();
    expect(normalizeVision('x')).toBeNull();
  });

  it('全空 → null', () => {
    expect(normalizeVision({})).toBeNull();
    expect(normalizeVision({ summary: '  ', styles: [], adopted: [] })).toBeNull();
  });

  it('去重 / 去空 / 截断', () => {
    const v = normalizeVision({ styles: ['新中式', '新中式', '', ' 胶片感 '], summary: '一句话' });
    expect(v?.styles).toEqual(['新中式', '胶片感']);
    expect(v?.summary).toBe('一句话');
  });

  it('adopted 只保留 allowedIds 内且带 reason 的项', () => {
    const raw = { scene: ['咖啡馆'], adopted: [{ id: 'a', reason: '光线好' }, { id: 'b', reason: '' }, { id: 'zz', reason: '不存在' }] };
    const v = normalizeVision(raw, new Set(['a', 'b']));
    expect(v?.adopted).toEqual([{ id: 'a', reason: '光线好' }]);
  });

  it('未传 allowedIds 时不做 id 过滤', () => {
    const v = normalizeVision({ scene: ['街景'], adopted: [{ id: 'a', reason: '构图佳' }] });
    expect(v?.adopted).toEqual([{ id: 'a', reason: '构图佳' }]);
  });

  it('有内容时 visionHasContent 为 true', () => {
    const v = normalizeVision({ colorLight: ['暖调逆光'] });
    expect(v).not.toBeNull();
    expect(visionHasContent(v!)).toBe(true);
  });
});

describe('renderResearchVision', () => {
  it('渲染分节小标题与采纳说明', () => {
    const v = normalizeVision({ summary: '暖调逆光氛围', styles: ['新中式'], scene: ['咖啡馆'] })!;
    const text = renderResearchVision(v);
    expect(text).toContain('风格倾向：新中式');
    expect(text).toContain('场景：咖啡馆');
    expect(text).toContain('综合结论：暖调逆光氛围');
  });
});
