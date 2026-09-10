// lumira-server/packages/backend/src/modules/ai/analyze.prompt.spec.ts
// renderCategoryTree 环安全单测：分类树中存在「key 等于其父 key」的自环节点（seed 005 中 food/overhead/overhead，见 005_category_hierarchy.sql）时，
// walk 不得无限递归导致 Maximum call stack。e.g. 纯文字描述触发构建系统提示词时必现。

import { buildTextOnlySystemPrompt, buildAnalyzeSystemPrompt } from './analyze.prompt';
import { CategoryNode } from './normalize';

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