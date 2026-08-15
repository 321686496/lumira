-- lumira-server/packages/backend/src/database/migrations/006_fix_category_duplicates.sql
-- 修复一级分类重复问题（三级分类 spec 2026-08-05 第 11 节）
-- MySQL 8 唯一索引对 NULL 不生效（多行 (key, NULL) 允许重复），
-- 与旧 SQLite 行为一致，故用 NULL 安全索引 + 清理重复保证幂等。

-- 1. 清理重复的一级分类（每个 key 仅保留 id 最小的一条）
--    同表子查询需包一层派生表，避免 MySQL 1093 错误
DELETE FROM template_categories
WHERE id NOT IN (
  SELECT * FROM (
    SELECT MIN(id)
    FROM template_categories
    GROUP BY `key`, IFNULL(parent_key, '')
  ) AS keep_ids
);

-- 2. NULL 安全唯一索引（COALESCE 将 NULL 归一到 ''，使唯一约束对一级分类生效）
--    索引列必须是等值表达式；用生成列实现 NULL → '' 归一
ALTER TABLE template_categories
  ADD COLUMN parent_key_norm VARCHAR(64)
  GENERATED ALWAYS AS (COALESCE(parent_key, '')) STORED;

CREATE UNIQUE INDEX uq_category_key_parent_null_safe
  ON template_categories (`key`, parent_key_norm);
