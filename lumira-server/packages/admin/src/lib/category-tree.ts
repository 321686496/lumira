// src/lib/category-tree.ts
// 纯函数模块，不依赖 next/headers，可被客户端组件安全导入。
import type {
  TemplateCategory,
  TemplateCategoryTreeNode,
} from '@/types/admin';

/**
 * 从扁平分类列表构造三级树（type → style → method）。
 * 按 sortOrder 升序、key 字典序兜底排列；孤儿节点（parentKey 指向不存在的分类）作为根节点展示。
 */
export function buildCategoryTree(categories: TemplateCategory[]): TemplateCategoryTreeNode[] {
  const sorted = [...categories].sort(
    (a, b) => a.sortOrder - b.sortOrder || a.key.localeCompare(b.key),
  );
  const byParent = new Map<string | null, TemplateCategoryTreeNode[]>();
  const keySet = new Set(sorted.map((c) => c.key));
  for (const c of sorted) {
    const parent = c.parentKey ?? null;
    // 父节点不存在时作为根节点处理，避免数据不一致导致丢失
    const effectiveParent = parent && !keySet.has(parent) ? null : parent;
    if (!byParent.has(effectiveParent)) byParent.set(effectiveParent, []);
    byParent.get(effectiveParent)!.push({ ...c, children: [] });
  }
  const roots = byParent.get(null) ?? [];
  const attach = (nodes: TemplateCategoryTreeNode[]) => {
    for (const n of nodes) {
      n.children = byParent.get(n.key) ?? [];
      attach(n.children);
    }
  };
  attach(roots);
  return roots;
}
