-- lumira-server/packages/backend/src/database/migrations/035_template_gender.sql
-- 模板新增适用性别字段（spec 2026-09-14）：
-- 'unisex'（通用）| 'male'（男）| 'female'（女），默认 unisex。
-- 存量数据统一回填为 unisex，不破坏现有模板。
ALTER TABLE `templates`
  ADD COLUMN `gender` VARCHAR(16) NOT NULL DEFAULT 'unisex' AFTER `short_desc`;