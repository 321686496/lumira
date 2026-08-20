-- lumira-server/packages/backend/src/database/migrations/015_template_ambience_short_desc.sql
-- 模板季节/天气/时段元数据 + 短简介（spec 2026-08-20-template-ambience-metadata-design）
-- 迁移执行器按文件名去重，编辑该文件前需确认 015_ 未被 _migrations 记录
ALTER TABLE templates
  ADD COLUMN ambience_json LONGTEXT NOT NULL DEFAULT '{}',
  ADD COLUMN short_desc TEXT NOT NULL DEFAULT '';