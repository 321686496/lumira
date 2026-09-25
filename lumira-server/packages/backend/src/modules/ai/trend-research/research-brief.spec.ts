// lumira-server/packages/backend/src/modules/ai/trend-research/research-brief.spec.ts
// 研究资料二次整理产物：模型 JSON → ResearchBrief 的归一化，以及注入提示词的渲染规则。

import { normalizeBrief, renderResearchBrief, briefHasContent } from './research-brief';

describe('normalizeBrief', () => {
  it('结构不合法（非对象 / 数组 / null）→ null', () => {
    expect(normalizeBrief(null)).toBeNull();
    expect(normalizeBrief('str')).toBeNull();
    expect(normalizeBrief([])).toBeNull();
  });

  it('无任何有效内容 → null（调用方据此回退规则摘要）', () => {
    expect(normalizeBrief({ summary: '', themes: [], sources: [] })).toBeNull();
    expect(normalizeBrief({ summary: '   ', themes: ['', '  '] })).toBeNull();
  });

  it('归一化：去空、去重、去非字符串，保留有效分节', () => {
    const brief = normalizeBrief({
      summary: ' 秋日暖调人像最受关注 ',
      themes: ['秋季人像', '秋季人像', '', 123, '银杏'],
      styles: ['日系清新'],
      colorLight: null,
      visualElements: ['银杏林', '针织衫'],
      seasons: ['2026年10月 中秋/国庆'],
      poseIdeas: ['侧身回眸'],
      sources: [{ title: '站点A', url: 'https://a.com' }, { title: '' }, { title: '站点A', url: 'https://a.com' }, { title: '站点B' }],
    });

    expect(brief).not.toBeNull();
    expect(brief!.summary).toBe('秋日暖调人像最受关注');
    expect(brief!.themes).toEqual(['秋季人像', '银杏']);
    expect(brief!.colorLight).toEqual([]);
    expect(brief!.sources).toEqual([{ title: '站点A', url: 'https://a.com' }, { title: '站点B' }]);
  });

  it('briefHasContent：仅来源不算有效内容', () => {
    expect(briefHasContent({ summary: '', themes: [], styles: [], colorLight: [], visualElements: [], seasons: [], poseIdeas: [], sources: [{ title: 'A' }] })).toBe(false);
    expect(briefHasContent({ summary: '结论', themes: [], styles: [], colorLight: [], visualElements: [], seasons: [], poseIdeas: [], sources: [] })).toBe(true);
  });
});

describe('renderResearchBrief', () => {
  it('只输出非空分节，并渲染采纳来源', () => {
    const text = renderResearchBrief({
      summary: '秋日暖调为主流',
      themes: ['秋季人像'],
      styles: [],
      colorLight: ['暖调低饱和'],
      visualElements: ['银杏林', '针织衫'],
      seasons: [],
      poseIdeas: [],
      sources: [{ title: '站点A', url: 'https://a.com' }, { title: '站点B' }],
    });

    expect(text).toContain('- 流行主题：秋季人像');
    expect(text).toContain('- 色彩与光影：暖调低饱和');
    expect(text).toContain('- 视觉元素：银杏林；针织衫');
    expect(text).toContain('- 综合结论：秋日暖调为主流');
    expect(text).toContain('站点A（https://a.com）');
    expect(text).toContain('站点B');
    // 空分节不出现
    expect(text).not.toContain('风格倾向');
    expect(text).not.toContain('时令 / 节日');
  });
});