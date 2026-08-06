// src/lib/category-tree.ts
// 纯函数模块，不依赖 next/headers，可被客户端组件安全导入。
import type {
  TemplateCategory,
  TemplateCategoryTreeNode,
} from '@/types/admin';

/**
 * 从扁平分类列表构造三级树（type → style → method）。
 *
 * 关键点：method 级分类的 key 在多个 style 下可能重复（如 normal 同时出现在
 * japanese / film 下），且存在子节点 key 与父节点 key 相同的数据（如 food → overhead → overhead）。
 * 因此必须用复合标识（parentKey + key）建 Map，并按 level 精确匹配父节点，
 * 否则会自引用形成循环，导致递归渲染栈溢出（RangeError: Maximum call stack size exceeded）。
 */
export function buildCategoryTree(categories: TemplateCategory[]): TemplateCategoryTreeNode[] {
  const sorted = [...categories].sort(
    (a, b) => a.sortOrder - b.sortOrder || a.key.localeCompare(b.key),
  );

  const map = new Map<string, TemplateCategoryTreeNode>();
  const roots: TemplateCategoryTreeNode[] = [];

  // 第一遍：创建所有节点（复合键 parentKey|key，区分不同层级下的同名 key）
  for (const cat of sorted) {
    map.set(nodeId(cat.key, cat.parentKey), { ...cat, children: [] });
  }

  // 第二遍：组装父子关系，父节点按 (parentKey, level) 精确匹配
  for (const cat of sorted) {
    const node = map.get(nodeId(cat.key, cat.parentKey))!;
    if (cat.parentKey === null) {
      roots.push(node);
    } else {
      const parent = findNode(map, cat.parentKey, cat.level - 1);
      if (parent) {
        parent.children.push(node);
      } else {
        // 父节点不存在（如被 isActive 过滤或数据不一致）时作为根节点兜底
        roots.push(node);
      }
    }
  }

  return roots;
}

/** 生成节点 Map key：parentKey|null + '|' + key（处理同 key 不同层级的情况） */
function nodeId(key: string, parentKey: string | null): string {
  return `${parentKey ?? '\0'}|${key}`;
}

/** 在 Map 中按 key + level 查找父节点（同 key 可能出现在多个层级，需按 level 精确匹配） */
function findNode(
  map: Map<string, TemplateCategoryTreeNode>,
  key: string,
  level: number,
): TemplateCategoryTreeNode | undefined {
  for (const node of map.values()) {
    if (node.key === key && node.level === level) {
      return node;
    }
  }
  return undefined;
}
