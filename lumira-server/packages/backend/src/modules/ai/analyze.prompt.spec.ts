// lumira-server/packages/backend/src/modules/ai/analyze.prompt.spec.ts
// renderCategoryTree 环安全单测：分类树中存在「key 等于其父 key」的自环节点（seed 005 中 food/overhead/overhead，见 005_category_hierarchy.sql）时，
// walk 不得无限递归导致 Maximum call stack。e.g. 纯文字描述触发构建系统提示词时必现。

import {
  buildTextOnlySystemPrompt,
  buildAnalyzeSystemPrompt,
  buildAnalyzeUserPrompt,
  inferSubjectCountHint,
} from './analyze.prompt';
import { CategoryNode } from './normalize';
import { type StyleProfile } from './style-profile.presets';

const CATS: CategoryNode[] = [{ key: 'portrait', name: '人像', parentKey: null, level: 1 }];

/** 复现 seed 005 中自环：样式 overhead(food 下) + 方法 overhead(父 overhead) */
function selfLoopCategories(): CategoryNode[] {
  return [
    { key: 'portrait', name: '人像', parentKey: null, level: 1 },
    { key: 'food', name: '美食', parentKey: null, level: 1 },
    { key: 'overhead', name: '俯拍', parentKey: 'food', level: 2 },
    // 自环：key === parentKey
    { key: 'overhead', name: '俯拍', parentKey: 'overhead', level: 3 },
    { key: 'flat', name: '平拍', parentKey: 'overhead', level: 3 },
  ];
}

describe('analyze.prompt renderCategoryTree 环安全', () => {
  it('存在自环分类时构建系统提示词不抛堆栈溢出，且每个节点只渲染一次', () => {
    const cats = selfLoopCategories();
    expect(() => buildTextOnlySystemPrompt(cats)).not.toThrow();

    const prompt = buildTextOnlySystemPrompt(cats);
    // 自环节点与其父样式均只出现一次（- overhead 俯拍 ×2），不产生重复展开
    const hit = (m: string) => prompt.split('\n').filter((l) => l.includes(m));
    expect(hit('- overhead 俯拍')).toHaveLength(2);
    expect(hit('- flat 平拍')).toHaveLength(1);
  });

  it('视觉识别版同样对自环分类免疫', () => {
    expect(() => buildAnalyzeSystemPrompt(selfLoopCategories())).not.toThrow();
  });
});

describe('analyze.prompt 自拍（前置）视角契约', () => {
  const cats: CategoryNode[] = [{ key: 'portrait', name: '人像', parentKey: null, level: 1 }];

  it('输出契约包含 pose[].cameraDirection 前后摄字段', () => {
    expect(buildTextOnlySystemPrompt(cats)).toContain('cameraDirection');
  });

  it('含自拍第一人称视角规则：一臂距离 / 近景 / 不出现手机与拍摄设备', () => {
    const prompt = buildAnalyzeSystemPrompt(cats);
    expect(prompt).toContain('第一人称');
    expect(prompt).toContain('一臂');
    expect(prompt).toContain('不出现手机');
  });
});

const PORTRAIT_PROFILE: StyleProfile = {
  category: 'portrait',
  archetype: 'fashion_editorial',
  aestheticTarget: '秋冬杂志大片',
  subjectStyling: '驼色大衣 + 皮革手套',
  expressionMood: '冷峻直视镜头',
  poseLanguage: '线条有张力',
  lightingSignature: '硬光高光比',
  compositionBias: '对角线与框架式构图',
  paletteHint: '高级灰',
  retouchLevel: 'polished',
  extraNotes: '灰墙负空间',
};

const LANDSCAPE_PROFILE: StyleProfile = {
  ...PORTRAIT_PROFILE,
  category: 'landscape',
  archetype: 'landscape_fine_art',
  aestheticTarget: '层峦空气感',
  subjectStyling: '',
  expressionMood: '',
  poseLanguage: '',
};

describe('analyze.prompt 风格档案分流', () => {
  it('注入档案：两种系统提示词都含档案段落与档案字段值', () => {
    const vision = buildAnalyzeSystemPrompt(CATS, PORTRAIT_PROFILE);
    const textOnly = buildTextOnlySystemPrompt(CATS, PORTRAIT_PROFILE);
    for (const p of [vision, textOnly]) {
      expect(p).toContain('本次风格档案');
      expect(p).toContain('时尚大片');
      expect(p).toContain('驼色大衣 + 皮革手套');
      expect(p).toContain('冷峻直视镜头');
      expect(p).toContain('对角线与框架式构图');
      expect(p).toContain('真实照片媒介');
    }
  });

  it('不传档案时不得出现档案段落（向后兼容）', () => {
    const p = buildAnalyzeSystemPrompt(CATS);
    expect(p).not.toContain('本次风格档案');
    expect(p).toContain('重心与支撑腿');
  });

  it('人像档案：要求含表情与穿搭，并含人类专属姿势术语', () => {
    const p = buildAnalyzeSystemPrompt(CATS, PORTRAIT_PROFILE);
    expect(p).toContain('表情');
    expect(p).toContain('穿搭');
    expect(p).toContain('重心与支撑腿');
    expect(p).toContain('手部落点');
  });

  it('非人像档案：不得出现「重心与支撑腿」「手部落点」，改为该大类术语', () => {
    const p = buildAnalyzeSystemPrompt(CATS, LANDSCAPE_PROFILE);
    expect(p).not.toContain('重心与支撑腿');
    expect(p).not.toContain('手部落点');
    expect(p).toContain('层次');
    expect(p).toContain('光时窗');
  });

  it('自拍第一人称契约仍保留（回归）', () => {
    const p = buildAnalyzeSystemPrompt(CATS, PORTRAIT_PROFILE);
    expect(p).toContain('第一人称');
    expect(p).toContain('一臂');
    expect(p).toContain('不出现手机');
  });
});

const CATEGORIES: CategoryNode[] = [{ key: 'portrait', name: '人像', parentKey: null, level: 1 }];

describe('多人物支持', () => {
  it('inferSubjectCountHint：命中多人关键词返回 2，否则 1', () => {
    expect(inferSubjectCountHint('帮朋友拍一组情侣照')).toBe(2);
    expect(inferSubjectCountHint('一家人的全家福')).toBe(2);
    expect(inferSubjectCountHint('一个人的街拍')).toBe(1);
    expect(inferSubjectCountHint(undefined, null, '')).toBe(1);
  });

  it('系统提示：多人提示档要求保持人物数量与互动关系', () => {
    const single = buildAnalyzeSystemPrompt(CATEGORIES, PORTRAIT_PROFILE, 1);
    const multi = buildAnalyzeSystemPrompt(CATEGORIES, PORTRAIT_PROFILE, 2);
    expect(single).toContain('不得改变人物长相');
    expect(multi).toContain('同一组人物');
    expect(multi).toContain('不得改变人物数量');
    expect(multi).not.toContain('体型、场景、道具、光线或整体风格。仅当用户明确要求');
  });

  it('系统提示：契约示例含 meta.subjectCount', () => {
    expect(buildAnalyzeSystemPrompt(CATEGORIES)).toContain('"subjectCount"');
  });

  it('用户提示：显式指定人数输出硬约束', () => {
    expect(buildAnalyzeUserPrompt({ subjectCount: 2 })).toContain('meta.subjectCount 必须为 2');
  });

  it('用户提示：未指定人数时输出推断口径', () => {
    expect(buildAnalyzeUserPrompt({})).toContain('请根据用户描述与示例图中实际可见的人物数量给出 meta.subjectCount');
  });
});