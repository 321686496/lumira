// src/modules/ai/ai-analyze.search-decided.spec.ts
// 联网检索必要性判定：明确要求搜索 → 搜；提供参考 URL 且未要求搜索 → 不搜；常规 → 搜。

import { searchDecided } from './ai-analyze.service';

describe('searchDecided', () => {
  it('提供参考 URL 且未要求搜索 → 不搜（直接爬 URL）', () => {
    expect(
      searchDecided('根据这篇网页创作模板，姿势全部参照这个网页：https://post.smzdm.com/p/arlx2w0w/', ''),
    ).toBe(false);
  });

  it('明确要求搜索 → 即使给了 URL 也搜', () => {
    expect(
      searchDecided('参考这个网站 https://post.smzdm.com/p/arlx2w0w/ 并联网搜索补充趋势', ''),
    ).toBe(true);
    expect(searchDecided('帮我在网上搜一下最近流行的人像风格', '')).toBe(true);
  });

  it('常规要求（无 URL、无搜索词）→ 搜', () => {
    expect(searchDecided('做一套晴空田园少女人像模板', '')).toBe(true);
    expect(searchDecided(undefined, '')).toBe(true);
    expect(searchDecided(null, '夜景人像')).toBe(true);
  });

  it('文字描述里带 URL 也视为提供参考（不搜）', () => {
    expect(searchDecided('参考这个网页', 'https://example.com/a')).toBe(false);
  });
});
