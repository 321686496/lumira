-- lumira-server/packages/backend/src/database/migrations/006_fix_category_duplicates.sql
-- 修复一级分类重复问题（三级分类 spec 2026-08-05 第 11 节）。
--
-- 背景：
--   runMigrations() 每次服务启动会重新执行所有迁移 SQL；
--   003_templates.sql 预置 7 个系统根分类时未指定 parent_key（SQLite 中为 NULL），
--   而唯一索引 (key, parent_key) 对 NULL 不生效（SQLite 将 NULL 视为互不相同），
--   导致每次启动都会给每个系统根分类再插入一条重复记录。
--   二级/三级分类 parent_key 非空，联合唯一索引生效，不受影响。
--
-- 本迁移：
--   1) 清理已存在的一级分类重复记录（每个 key 仅保留 id 最小的一条）
--   2) 新增 NULL 安全唯一索引 (key, COALESCE(parent_key, ''))，
--      使后续 INSERT OR IGNORE 对一级分类同样幂等
--
-- 幂等写法：DELETE 条件清理 + CREATE UNIQUE INDEX IF NOT EXISTS。

-- 1. 清理重复的一级分类
DELETE FROM template_categories
WHERE id NOT IN (
  SELECT MIN(id)
  FROM template_categories
  GROUP BY key, IFNULL(parent_key, '')
);

-- 2. NULL 安全唯一索引（COALESCE 将 NULL 归一为 ''，使唯一约束对一级分类生效）
CREATE UNIQUE INDEX IF NOT EXISTS uq_category_key_parent_null_safe
  ON template_categories(key, COALESCE(parent_key, ''));
