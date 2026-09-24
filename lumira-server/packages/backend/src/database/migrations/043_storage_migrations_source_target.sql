-- 043_storage_migrations_source_target.sql
-- 修复：1c92f6e 将 source_id/target_id 直接补进了 038 的 CREATE TABLE IF NOT EXISTS，
-- 但线上 storage_migrations 表已由旧版 038 建好，IF NOT EXISTS 不再生效导致缺列
-- （ER_BAD_FIELD_ERROR 1054）。此处用 ALTER TABLE 补齐两列，含默认值，不影响存量行。

ALTER TABLE storage_migrations
  ADD COLUMN source_id VARCHAR(32) NOT NULL DEFAULT 'local' COMMENT '迁移源存储 id（当前激活存储）' AFTER trigger_by,
  ADD COLUMN target_id VARCHAR(32) NOT NULL DEFAULT 'r2' COMMENT '迁移目标存储 id' AFTER source_id;
