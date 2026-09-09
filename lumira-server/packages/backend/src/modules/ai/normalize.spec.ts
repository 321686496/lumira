// lumira-server/packages/backend/src/modules/ai/normalize.spec.ts
// AI 草稿归一化纯函数单测（Task 2，TDD）
// 用例编号 1~15 与 task-2-brief.md 一一对应；16~19 为补充用例（throw / AI 不填字段 / 浅树 / 枚举表一致性）

import {
  CategoryNode,
  extractJson,
  mapEnumValue,
  clampNumber,
  normalizeDraft,
  LUTS,
  LUT_LABELS,
} from './normalize';

/** 四级分类树测试夹具：portrait 全链 + landscape 浅树（非人像：L2 style + L3 method） */
const CATEGORIES: CategoryNode[] = [
  { key: 'portrait', name: '人像', parentKey: null, level: 1 },
  { key: 'landscape', name: '风景', parentKey: null, level: 1 },
  { key: 'fresh_healing', name: '清新治愈', parentKey: 'portrait', level: 2 },
  { key: 'emotional_film', name: '情绪胶片', parentKey: 'portrait', level: 2 },
  { key: 'japanese', name: '日系', parentKey: 'fresh_healing', level: 3 },
  { key: 'method_x', name: '回眸法', parentKey: 'japanese', level: 4 },
  { key: 'citywalk', name: '城市漫步', parentKey: 'landscape', level: 2 },
  { key: 'method_y', name: '慢门法', parentKey: 'citywalk', level: 3 },
];

/** 完整合法草稿（结构同设计文档第四节示例；name 保证 12~30 字以使 warnings 为空） */
function baseDraft(): any {
  return {
    meta: {
      name: '晴空田园少女人像侧拍逆光清新风格模板',
      category: 'portrait',
      shortDesc: '把夏天拍进眼睛里',
      description: '逆光下的田园少女，主体清新自然，背景为田野与天空。',
      tags: ['日系', '田园', '清新'],
      ambience: { seasons: ['summer'], weathers: ['sunny'], timeTones: ['day'] },
      classification: { type: 'portrait', majorStyle: 'fresh_healing', style: 'japanese', method: 'method_x' },
    },
    composition: {
      overlayType: 'rule_of_thirds',
      aspectRatio: '3:4',
      opacity: 0.5,
      description: '主体置于左侧三分线，留出天空呼吸感',
      subjectFrame: { x: 0.3, y: 0.2, w: 0.4, h: 0.6 },
    },
    pose: [
      { name: '侧身回眸', description: '身体微侧45度，下巴略抬', position: { x: 0.5, y: 0.45 }, scale: 1.0, rotation: 0 },
    ],
    camera: {
      exposureCompensation: 0.3,
      isoMode: 'manual',
      iso: 200,
      shutterSpeed: '1/400',
      whiteBalance: 'daylight',
      whiteBalanceK: 5500,
      flashMode: 'off',
      focusMode: 'auto',
      lensType: '85mm f/1.8',
      lensSuggestion: 'telephoto',
    },
    sceneGuide: {
      lightDirection: '侧逆光',
      shootingDistance: '2-3米',
      background: '田野与天空',
      props: ['草帽'],
      bestTime: '午后4-6点',
      tips: ['对焦眼睛', '避免正午顶光'],
    },
    postProcess: {
      cropRatio: '3:4',
      color: { brightness: 5, contrast: 8, saturation: -10, temperature: 10, tint: 3, highlights: -5, shadows: 8 },
      smoothStrength: 15,
      sharpen: 10,
      vignette: 12,
      grain: 18,
      lut: 'japanese_fresh',
    },
  };
}

describe('extractJson', () => {
  it('1. 纯 JSON 字符串 → 直接解析为对象', () => {
    expect(extractJson('{"a":1}')).toEqual({ a: 1 });
  });

  it('2. 剥离 ```json code fence 后解析', () => {
    expect(extractJson('```json\n{"a":1}\n```')).toEqual({ a: 1 });
    expect(extractJson('```\n{"a":1}\n```')).toEqual({ a: 1 });
  });

  it('3. 前后带废话时截取首个 { 到末个 }', () => {
    expect(extractJson('前置废话 {"a":{"b":2}} 后置废话')).toEqual({ a: { b: 2 } });
  });

  it('4. 完全不是 JSON → null', () => {
    expect(extractJson('完全不是 JSON')).toBeNull();
  });
});

describe('mapEnumValue', () => {
  const allowed = ['rule_of_thirds', 'center'];
  const labels = { rule_of_thirds: '三等分', center: '居中' };

  it('5. 精确 key 命中 → 原样返回 key', () => {
    expect(mapEnumValue('rule_of_thirds', allowed, labels)).toBe('rule_of_thirds');
  });

  it('6. 中文标签反查命中 → 返回对应 key', () => {
    expect(mapEnumValue('三等分', allowed, labels)).toBe('rule_of_thirds');
  });

  it('7. 非法值 → undefined（调用方丢弃并记 warning）', () => {
    expect(mapEnumValue('对角线', allowed, labels)).toBeUndefined();
    expect(mapEnumValue(123, allowed, labels)).toBeUndefined();
    expect(mapEnumValue(null, allowed, labels)).toBeUndefined();
  });
});

describe('clampNumber', () => {
  it('8. 数值夹取：越界夹到边界，非法值返回 undefined', () => {
    expect(clampNumber(1.5, 0, 1)).toBe(1);
    expect(clampNumber(-3, 0, 1)).toBe(0);
    expect(clampNumber('abc', 0, 1)).toBeUndefined();
    expect(clampNumber(0.5, 0, 1)).toBe(0.5);
  });
});

describe('normalizeDraft', () => {
  it('9. 完整合法草稿 → draft 保留全部字段，warnings=[]', () => {
    const { draft, warnings } = normalizeDraft(baseDraft(), CATEGORIES);

    expect(warnings).toEqual([]);

    expect(draft.meta).toMatchObject({
      name: '晴空田园少女人像侧拍逆光清新风格模板',
      category: 'portrait',
      shortDesc: '把夏天拍进眼睛里',
      description: '逆光下的田园少女，主体清新自然，背景为田野与天空。',
      tags: ['日系', '田园', '清新'],
      ambience: { seasons: ['summer'], weathers: ['sunny'], timeTones: ['day'] },
      classification: { type: 'portrait', majorStyle: 'fresh_healing', style: 'japanese', method: 'method_x' },
    });
    expect(draft.composition).toMatchObject({
      overlayType: 'rule_of_thirds',
      aspectRatio: '3:4',
      opacity: 0.5,
      description: '主体置于左侧三分线，留出天空呼吸感',
      subjectFrame: { x: 0.3, y: 0.2, w: 0.4, h: 0.6 },
    });
    expect(draft.pose).toEqual([
      { name: '侧身回眸', description: '身体微侧45度，下巴略抬', position: { x: 0.5, y: 0.45 }, scale: 1, rotation: 0 },
    ]);
    expect(draft.camera).toMatchObject({
      exposureCompensation: 0.3,
      isoMode: 'manual',
      iso: 200,
      shutterSpeed: '1/400',
      whiteBalance: 'daylight',
      whiteBalanceK: 5500,
      flashMode: 'off',
      focusMode: 'auto',
      lensType: '85mm f/1.8',
      lensSuggestion: 'telephoto',
    });
    expect(draft.sceneGuide).toMatchObject({
      lightDirection: '侧逆光',
      shootingDistance: '2-3米',
      background: '田野与天空',
      props: ['草帽'],
      bestTime: '午后4-6点',
      tips: ['对焦眼睛', '避免正午顶光'],
    });
    expect(draft.postProcess).toMatchObject({
      cropRatio: '3:4',
      color: { brightness: 5, contrast: 8, saturation: -10, temperature: 10, tint: 3, highlights: -5, shadows: 8 },
      smoothStrength: 15,
      sharpen: 10,
      vignette: 12,
      grain: 18,
      lut: 'japanese_fresh',
    });
  });

  it('10. meta.category 不在分类树 → 回退默认 portrait + warning', () => {
    const raw = baseDraft();
    raw.meta.category = '不存在的分类';
    const { draft, warnings } = normalizeDraft(raw, CATEGORIES);

    expect((draft.meta as any).category).toBe('portrait');
    expect((draft.meta as any).classification.type).toBe('portrait');
    expect(warnings).toHaveLength(1);
    expect(warnings[0]).toContain('category');
  });

  it('11. classification 链断裂（style 的 parent 不是 majorStyle）→ 截断到合法层 + warning', () => {
    const raw = baseDraft();
    // citywalk 是 landscape 的二级节点，不是 fresh_healing 的三级子节点 → style 层断裂
    raw.meta.classification = { type: 'portrait', majorStyle: 'fresh_healing', style: 'citywalk', method: 'method_x' };
    const { draft, warnings } = normalizeDraft(raw, CATEGORIES);

    expect((draft.meta as any).classification).toEqual({ type: 'portrait', majorStyle: 'fresh_healing' });
    expect(warnings.some((w) => w.includes('style'))).toBe(true);
  });

  it('12. 数值越界夹取：pose.position.x=1.7→1，postProcess.color.saturation=200→100', () => {
    const raw = baseDraft();
    raw.pose[0].position.x = 1.7;
    raw.postProcess.color.saturation = 200;
    const { draft, warnings } = normalizeDraft(raw, CATEGORIES);

    expect(draft.pose[0].position.x).toBe(1);
    expect(draft.postProcess.color.saturation).toBe(100);
    expect(warnings.some((w) => w.includes('position.x'))).toBe(true);
    expect(warnings.some((w) => w.includes('saturation'))).toBe(true);
  });

  it('13. camera.whiteBalance="日光" → 中文标签反查为 daylight', () => {
    const raw = baseDraft();
    raw.camera.whiteBalance = '日光';
    const { draft, warnings } = normalizeDraft(raw, CATEGORIES);

    expect((draft.camera as any).whiteBalance).toBe('daylight');
    expect(warnings).toEqual([]);
  });

  it('14. postProcess.lut="日系清新"→japanese_fresh；lut="不存在"→丢弃 + warning', () => {
    const raw1 = baseDraft();
    raw1.postProcess.lut = '日系清新';
    const r1 = normalizeDraft(raw1, CATEGORIES);
    expect((r1.draft.postProcess as any).lut).toBe('japanese_fresh');
    expect(r1.warnings).toEqual([]);

    const raw2 = baseDraft();
    raw2.postProcess.lut = '不存在';
    const r2 = normalizeDraft(raw2, CATEGORIES);
    expect((r2.draft.postProcess as any).lut).toBeUndefined();
    expect(r2.warnings.some((w) => w.includes('lut'))).toBe(true);
  });

  it('15. pose 为对象（非数组）→ 包装成 [pose]；pose 为空 → 默认单姿势骨架', () => {
    const raw1 = baseDraft();
    raw1.pose = { name: '站姿', description: '自然站立', position: { x: 0.4, y: 0.6 }, scale: 1.2, rotation: -10 };
    const r1 = normalizeDraft(raw1, CATEGORIES);
    expect(Array.isArray(r1.draft.pose)).toBe(true);
    expect(r1.draft.pose).toEqual([
      { name: '站姿', description: '自然站立', position: { x: 0.4, y: 0.6 }, scale: 1.2, rotation: -10 },
    ]);

    const raw2 = baseDraft();
    raw2.pose = [];
    const r2 = normalizeDraft(raw2, CATEGORIES);
    expect(r2.draft.pose).toEqual([
      { name: '', description: '', position: { x: 0.5, y: 0.5 }, scale: 1, rotation: 0 },
    ]);
  });

  it('16. 非 object 输入（string/null/array）→ throw（调用方转 400）', () => {
    expect(() => normalizeDraft('not an object', CATEGORIES)).toThrow();
    expect(() => normalizeDraft(null, CATEGORIES)).toThrow();
    expect(() => normalizeDraft([1, 2], CATEGORIES)).toThrow();
  });

  it('17. AI 不填字段（price/silhouette/author/sortOrder/isActive）与未知顶层键强制不写入', () => {
    const raw: any = baseDraft();
    raw.price = 99;
    raw.author = 'AI';
    raw.sortOrder = 5;
    raw.isActive = false;
    raw.unknownTopKey = 'x';
    raw.meta.price = 99;
    raw.meta.author = 'AI';
    raw.meta.sortOrder = 5;
    raw.meta.isActive = false;
    raw.pose[0].silhouette = { type: 'image', url: 'http://example.com/s.png' };

    const { draft } = normalizeDraft(raw, CATEGORIES);

    // 顶层只保留六个已知 section
    expect(Object.keys(draft).sort()).toEqual(['camera', 'composition', 'meta', 'pose', 'postProcess', 'sceneGuide']);
    const meta = draft.meta as any;
    expect(meta.price).toBeUndefined();
    expect(meta.author).toBeUndefined();
    expect(meta.sortOrder).toBeUndefined();
    expect(meta.isActive).toBeUndefined();
    expect(draft.pose[0].silhouette).toBeUndefined();
  });

  it('18. 非人像浅树（majorStyle 为空串，style=L2，method=L3）→ 全链保留且无 warning', () => {
    const raw = baseDraft();
    raw.meta.category = 'landscape';
    raw.meta.classification = { type: 'landscape', majorStyle: '', style: 'citywalk', method: 'method_y' };
    const { draft, warnings } = normalizeDraft(raw, CATEGORIES);

    expect((draft.meta as any).category).toBe('landscape');
    expect((draft.meta as any).classification).toEqual({ type: 'landscape', style: 'citywalk', method: 'method_y' });
    expect(warnings).toEqual([]);
  });

  it('19. LUT 枚举表与 admin 表单常量一致：25 项（24 滤镜 + none 原图），标签齐全', () => {
    // admin template-form.tsx 的 LUTS / LUT_LABELS 与 Flutter unifiedFilters 均为 25 项（含 none 原图）
    expect(LUTS).toHaveLength(25);
    expect(Object.keys(LUT_LABELS)).toHaveLength(LUTS.length);
    for (const key of LUTS) {
      expect(typeof LUT_LABELS[key]).toBe('string');
      expect(LUT_LABELS[key].length).toBeGreaterThan(0);
    }
    expect(mapEnumValue('日系清新', LUTS, LUT_LABELS)).toBe('japanese_fresh');
    expect(mapEnumValue('原图', LUTS, LUT_LABELS)).toBe('none');
  });
});
