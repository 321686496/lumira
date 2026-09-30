// src/modules/ai/ai-analyze.search-decided.spec.ts
// 联网检索必要性判定：明确禁止联网 → 不搜（最高优先）；明确要求搜索 → 搜；
// 提供参考 URL 且未要求搜索 → 不搜；常规 → 搜。

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

  it('创作要求明确禁止联网 → 不搜（最高优先）', () => {
    expect(searchDecided('做一套晴空田园少女人像模板，不要联网搜索', '')).toBe(false);
    expect(searchDecided('无需联网检索，按我说的风格来', '')).toBe(false);
    expect(searchDecided('不用搜索，直接生成', '')).toBe(false);
    expect(searchDecided('禁止联网，自己构思', '')).toBe(false);
    expect(searchDecided('取消联网搜索', '')).toBe(false);
    expect(searchDecided('不联网搜索最新趋势', '')).toBe(false);
    expect(searchDecided('请勿联网搜索', '')).toBe(false);
  });

  it('禁止联网优先于「搜索/联网」字样与参考 URL', () => {
    expect(searchDecided('不要联网搜索 https://example.com/a', '')).toBe(false);
    expect(searchDecided('不要联网搜索，我自己有判断', '夜景人像')).toBe(false);
  });

  it('否定词不误伤普通描述', () => {
    expect(searchDecided('做一个不一样的搜索风格海报', '')).toBe(true);
    expect(searchDecided('特别搜索一下最近流行的构图', '')).toBe(true);
    expect(searchDecided('分别搜索不同风格的参考', '')).toBe(true);
  });
});
