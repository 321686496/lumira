// src/lib/__tests__/category-tree.test.ts
import { describe, it, expect } from 'vitest';

import { buildCategoryTree } from '../category-tree';
import type { TemplateCategory } from '@/types/admin';

function makeCat(over: Partial<TemplateCategory> & Pick<TemplateCategory, 'key' | 'name' | 'level'>): TemplateCategory {
  return {
    id: 0,
    parentKey: null,
    iconUrl: '',
    sortOrder: 0,
    isSystem: false,
    isActive: true,
    updatedAt: 0,
    ...over,
  };
}

describe('buildCategoryTree', () => {
  it('空列表返回空数组', () => {
    expect(buildCategoryTree([])).toEqual([]);
  });

  it('构造完整三级树', () => {
    const flat: TemplateCategory[] = [
      makeCat({ key: 'portrait', name: '人像', level: 1, sortOrder: 1 }),
      makeCat({ key: 'japanese', name: '日系', level: 2, parentKey: 'portrait', sortOrder: 1 }),
      makeCat({ key: 'normal', name: '他拍', level: 3, parentKey: 'japanese', sortOrder: 1 }),
      makeCat({ key: 'landscape', name: '风景', level: 1, sortOrder: 2 }),
    ];
    const tree = buildCategoryTree(flat);
    expect(tree).toHaveLength(2);
    expect(tree[0].key).toBe('portrait');
    expect(tree[1].key).toBe('landscape');
    expect(tree[0].children).toHaveLength(1);
    expect(tree[0].children[0].key).toBe('japanese');
    expect(tree[0].children[0].children).toHaveLength(1);
    expect(tree[0].children[0].children[0].key).toBe('normal');
    expect(tree[1].children).toHaveLength(0);
  });

  it('按 sortOrder 升序排列，key 字典序兜底', () => {
    const flat: TemplateCategory[] = [
      makeCat({ key: 'food', name: '美食', level: 1, sortOrder: 3 }),
      makeCat({ key: 'portrait', name: '人像', level: 1, sortOrder: 1 }),
      makeCat({ key: 'landscape', name: '风景', level: 1, sortOrder: 2 }),
    ];
    const tree = buildCategoryTree(flat);
    expect(tree.map((n) => n.key)).toEqual(['portrait', 'landscape', 'food']);
  });

  it('sortOrder 相同时按 key 字典序', () => {
    const flat: TemplateCategory[] = [
      makeCat({ key: 'zebra', name: 'Z', level: 1, sortOrder: 0 }),
      makeCat({ key: 'apple', name: 'A', level: 1, sortOrder: 0 }),
    ];
    const tree = buildCategoryTree(flat);
    expect(tree.map((n) => n.key)).toEqual(['apple', 'zebra']);
  });

  it('孤儿节点（parentKey 指向不存在的分类）作为根节点展示', () => {
    const flat: TemplateCategory[] = [
      makeCat({ key: 'portrait', name: '人像', level: 1 }),
      makeCat({ key: 'orphan', name: '孤儿', level: 2, parentKey: 'nonexistent' }),
    ];
    const tree = buildCategoryTree(flat);
    // portrait 和 orphan 都作为根节点
    expect(tree.map((n) => n.key).sort()).toEqual(['orphan', 'portrait']);
  });

  it('子节点继承到正确的父级下', () => {
    const flat: TemplateCategory[] = [
      makeCat({ key: 'portrait', name: '人像', level: 1 }),
      makeCat({ key: 'film', name: '胶片', level: 2, parentKey: 'portrait' }),
      makeCat({ key: 'japanese', name: '日系', level: 2, parentKey: 'portrait' }),
      makeCat({ key: 'selfie', name: '自拍', level: 3, parentKey: 'film' }),
    ];
    const tree = buildCategoryTree(flat);
    const portrait = tree[0];
    expect(portrait.children.map((c) => c.key)).toEqual(['film', 'japanese']);
    expect(portrait.children[0].children.map((c) => c.key)).toEqual(['selfie']);
    expect(portrait.children[1].children).toHaveLength(0);
  });

  it('不修改原始输入数组', () => {
    const flat: TemplateCategory[] = [
      makeCat({ key: 'portrait', name: '人像', level: 1 }),
      makeCat({ key: 'japanese', name: '日系', level: 2, parentKey: 'portrait' }),
    ];
    const snapshot = JSON.parse(JSON.stringify(flat));
    buildCategoryTree(flat);
    expect(flat).toEqual(snapshot);
  });
});
