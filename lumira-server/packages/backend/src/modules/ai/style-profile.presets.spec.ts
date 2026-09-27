import {
  STYLE_ARCHETYPES,
  STYLE_ARCHETYPE_PRESETS,
  REALISM_BASELINE,
  normalizeStyleProfile,
  defaultStyleProfile,
  styleProfileOfDraft,
  renderStyleProfileBlock,
} from './style-profile.presets';

describe('style-profile.presets', () => {
  it('7 条档案齐全，且均带底线外的档案级禁忌', () => {
    expect(STYLE_ARCHETYPES).toHaveLength(7);
    for (const a of STYLE_ARCHETYPES) {
      const p = STYLE_ARCHETYPE_PRESETS[a];
      expect(p.archetype).toBe(a);
      expect(p.lightingSignature.length).toBeGreaterThan(0);
      expect(p.compositionBias.length).toBeGreaterThan(0);
      expect(p.poseLanguage.length).toBeGreaterThan(0);
      expect(p.forbidden.length).toBeGreaterThan(0);
    }
  });

  it('defaultStyleProfile 为 candid_lifestyle + portrait + none', () => {
    const d = defaultStyleProfile();
    expect(d.archetype).toBe('candid_lifestyle');
    expect(d.category).toBe('portrait');
    expect(d.retouchLevel).toBe('none');
  });

  it('normalizeStyleProfile：枚举越界兜底；合法时保留档案默认的 retouchLevel', () => {
    const bad = normalizeStyleProfile({ category: '动画', archetype: 'anime' });
    expect(bad.category).toBe('portrait');
    expect(bad.archetype).toBe('candid_lifestyle');
    expect(bad.retouchLevel).toBe('none');

    const ok = normalizeStyleProfile({ category: 'landscape', archetype: 'landscape_fine_art', aestheticTarget: '层峦叠嶂的空气感' });
    expect(ok.category).toBe('landscape');
    expect(ok.archetype).toBe('landscape_fine_art');
    expect(ok.retouchLevel).toBe('light'); // 档案默认
    expect(ok.aestheticTarget).toBe('层峦叠嶂的空气感');
    expect(ok.lightingSignature).toBe(STYLE_ARCHETYPE_PRESETS.landscape_fine_art.lightingSignature);
  });

  it('normalizeStyleProfile：非法 retouchLevel 取档案默认，不取 none', () => {
    const p = normalizeStyleProfile({ archetype: 'fashion_editorial', retouchLevel: 'ultra' });
    expect(p.retouchLevel).toBe('polished');
  });

  it('normalizeStyleProfile：extraNotes 不覆盖底线（底线只在渲染时单独注入，不写入 extraNotes）', () => {
    const p = normalizeStyleProfile({ archetype: 'fashion_editorial', extraNotes: '禁用真实肤色' });
    expect(p.extraNotes).toBe('禁用真实肤色');
    const block = renderStyleProfileBlock(p);
    expect(block).toContain(REALISM_BASELINE);
    expect(block.indexOf(REALISM_BASELINE)).toBeGreaterThan(block.indexOf('禁用真实肤色'));
  });

  it('styleProfileOfDraft：非对象/缺 archetype 返回 undefined；合法对象返回归一化档案', () => {
    expect(styleProfileOfDraft(null)).toBeUndefined();
    expect(styleProfileOfDraft({})).toBeUndefined();
    expect(styleProfileOfDraft({ styleProfile: { archetype: 123 } })).toBeUndefined();
    const p = styleProfileOfDraft({ styleProfile: { category: 'food', archetype: 'food_lifestyle' } });
    expect(p?.category).toBe('food');
  });

  it('renderStyleProfileBlock 含中文标签、精修档、现场补充与底线优先声明', () => {
    const block = renderStyleProfileBlock(defaultStyleProfile());
    expect(block).toContain('本次风格档案');
    expect(block).toContain('随拍松弛');
    expect(block).toContain('无精修');
    expect(block).toContain('底线');
    expect(block).toContain('优先级高于');
  });
});