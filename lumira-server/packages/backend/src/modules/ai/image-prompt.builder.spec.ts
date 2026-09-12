// lumira-server/packages/backend/src/modules/ai/image-prompt.builder.spec.ts
// 生图提示词 builder 纯函数单测（Task 6，TDD）
// 输入草稿直接取设计文档第四节完整示例（与 normalize.spec.ts baseDraft 同源）；
// 断言关键词覆盖 task-6-brief.md 要求：画幅 3:4、人像、日系、田野与天空、
// 侧逆光、午后4-6点、日系清新（LUT 标签）、氛围关键词（把夏天拍进眼睛里）。

import { buildImagePrompt } from './image-prompt.builder';

/** 设计文档第四节完整草稿示例（pose/camera 等不参与 prompt 的字段保留，验证多余字段被忽略） */
function fullDraft(): Record<string, unknown> {
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

describe('buildImagePrompt', () => {
  test('完整草稿：合成包含全部关键信息的中文一段式 prompt', () => {
    const prompt = buildImagePrompt(fullDraft());

    // 固定格式骨架：「一张{画幅}{主体类型}摄影作品，…」
    expect(prompt.startsWith('一张')).toBe(true);
    expect(prompt).toContain('摄影作品');

    // brief 要求的关键词逐一断言
    expect(prompt).toContain('3:4');            // 画幅
    expect(prompt).toContain('竖构图');         // 画幅取向（3:4 → 竖构图）
    expect(prompt).toContain('人像');           // 主体类型（classification.type=portrait）
    expect(prompt).toContain('日系');           // tags
    expect(prompt).toContain('侧逆光');         // 光线
    expect(prompt).toContain('田野与天空');     // 场景背景
    expect(prompt).toContain('午后4-6点');      // 最佳时段
    expect(prompt).toContain('日系清新');       // LUT 中文标签（japanese_fresh）
    expect(prompt).toContain('把夏天拍进眼睛里'); // 氛围关键词（shortDesc）

    // 场景引导其余字段与后期颗粒
    expect(prompt).toContain('草帽');
    expect(prompt).toContain('三分线');
    expect(prompt).toContain('颗粒感');

    // 一段式、无占位残留
    expect(prompt).not.toContain('\n');
    expect(prompt).not.toContain('undefined');
    expect(prompt).not.toContain('null');
    expect(prompt).not.toContain('NaN');
  });

  test('空草稿：返回非空兜底串「一张 3:4 竖构图的人像摄影作品…」', () => {
    const prompt = buildImagePrompt({});
    expect(prompt.length).toBeGreaterThan(0);
    expect(prompt).toContain('一张 3:4 竖构图的人像摄影作品');
  });

  test('字段缺失：跳过缺失字段，不产生空段或占位符', () => {
    const prompt = buildImagePrompt({ sceneGuide: { background: '海边', lightDirection: '顺光' } });
    expect(prompt).toContain('海边');
    expect(prompt).toContain('顺光');
    expect(prompt).not.toContain('undefined');
    expect(prompt).not.toContain('，，');
    expect(prompt).not.toContain('NaN');
  });

  test('未知一级分类 key：跳过主体类型，不泄漏英文 key', () => {
    const prompt = buildImagePrompt({ meta: { classification: { type: 'mystery_style' } } });
    expect(prompt.length).toBeGreaterThan(0);
    expect(prompt).not.toContain('mystery_style');
  });

  test('classification 缺失时用 meta.category 兜底主体类型', () => {
    const prompt = buildImagePrompt({ meta: { category: 'street' }, composition: { aspectRatio: '3:4' } });
    expect(prompt).toContain('街拍');
    expect(prompt).toContain('3:4');
  });

  test('LUT 为 none/未知 key 时跳过色调描述，grain 为 0 时跳过颗粒感', () => {
    const base = { sceneGuide: { background: '海边' } };
    const noneLut = buildImagePrompt({ ...base, postProcess: { lut: 'none', grain: 0 } });
    expect(noneLut).toContain('海边'); // 证明非兜底串
    expect(noneLut).not.toContain('原图');
    expect(noneLut).not.toContain('颗粒感');
    const unknownLut = buildImagePrompt({ ...base, postProcess: { lut: 'mystery_lut' } });
    expect(unknownLut).not.toContain('mystery_lut');
  });

  test('未知画幅比例：仅保留比例值，不附加取向词', () => {
    const prompt = buildImagePrompt({
      meta: { classification: { type: 'portrait' } },
      composition: { aspectRatio: '21:9' },
    });
    expect(prompt).toContain('21:9');
    expect(prompt).toContain('人像');
    expect(prompt).not.toContain('竖构图');
    expect(prompt).not.toContain('横构图');
  });

  test('氛围兜底：shortDesc 优先，缺失时回退 description', () => {
    const withShort = buildImagePrompt({ meta: { shortDesc: '情绪短句A', description: '结构化长描述B' } });
    expect(withShort).toContain('情绪短句A');
    expect(withShort).not.toContain('结构化长描述B');
    const descOnly = buildImagePrompt({ meta: { description: '结构化长描述B' } });
    expect(descOnly).toContain('结构化长描述B');
  });

  test('extraPrompt 非空：以「额外要求：」附加到 prompt 末尾（用户显式要求权重最高）', () => {
    const prompt = buildImagePrompt(fullDraft(), '人物戴草帽，天空占比更大');
    expect(prompt).toContain('额外要求：人物戴草帽，天空占比更大');
    // 附加段在末尾（最接近结尾的逗号分隔段）
    expect(prompt.lastIndexOf('额外要求：')).toBeGreaterThan(prompt.lastIndexOf('情绪'));
  });

  test('extraPrompt 为空串 / 纯空白 / null / undefined：不附加段，行为与旧版一致', () => {
    const baseline = buildImagePrompt(fullDraft());
    for (const extra of ['', '   ', null, undefined] as Array<string | null | undefined>) {
      const prompt = buildImagePrompt(fullDraft(), extra);
      expect(prompt).toBe(baseline);
      expect(prompt).not.toContain('额外要求');
    }
  });

  test('单姿势模式：使用选中 pose，忽略全局数量/多姿势描述', () => {
    const base = fullDraft() as Record<string, unknown> & {
      meta: Record<string, unknown>;
      composition: Record<string, unknown>;
    };
    const draft = {
      ...base,
      ...fullDraft(),
      singlePose: true,
      pose: { name: '侧身回眸', description: '身体微侧45度，下巴略抬' },
      meta: {
        ...base.meta,
        description: '生成三个不同姿势的氛围感自拍',
      },
      composition: {
        ...base.composition,
        description: '三个不同姿势的氛围感自拍',
      },
    };
    const prompt = buildImagePrompt(draft);
    expect(prompt).toContain('侧身回眸');
    expect(prompt).toContain('身体微侧45度');
    expect(prompt).toContain('画面中只有一个人物');
    expect(prompt).toContain('不要合并多个姿势，不要生成连拍、多宫格或姿势对比图');
    expect(prompt).not.toContain('三个不同姿势');
  });

  test('单姿势模式默认保持人物与场景一致性，除非用户明确要求不一致', () => {
    const prompt = buildImagePrompt({
      singlePose: true,
      pose: { name: '侧身', description: '身体微侧45度' },
    });
    expect(prompt).toContain('同一套模板的连续拍摄');
    expect(prompt).toContain('保持同一人物的长相、服装、发型、体型');

    const loose = buildImagePrompt({
      singlePose: true,
      pose: { name: '侧身', description: '身体微侧45度' },
      consistency: { mode: 'loose' },
    });
    expect(loose).not.toContain('同一套模板的连续拍摄');

    const explicit = buildImagePrompt({
      singlePose: true,
      pose: { name: '侧身', description: '身体微侧45度' },
    }, '第二个姿势换到不同场景');
    expect(explicit).not.toContain('同一套模板的连续拍摄');
  });

  test('锚点参考模式：明确要求复用第一张姿势图中的人物与场景', () => {
    const prompt = buildImagePrompt({
      singlePose: true,
      pose: { name: '侧身', description: '身体微侧45度' },
      consistency: { mode: 'strict', anchor: 'first' },
    });
    expect(prompt).toContain('参考图是同一套模板的第一张姿势图');
    expect(prompt).toContain('严格复用参考图中的同一人物长相');
  });
});
