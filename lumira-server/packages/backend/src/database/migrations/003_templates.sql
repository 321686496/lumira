-- lumira-server/packages/backend/src/database/migrations/003_templates.sql
-- 后台动态模板上传功能（spec 2026-08-05 第 2.2 节）
-- 幂等写法：CREATE TABLE IF NOT EXISTS + INSERT OR IGNORE

-- 1. 模板分类表
CREATE TABLE IF NOT EXISTS template_categories (
  key         TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  icon_url    TEXT NOT NULL,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  is_system   INTEGER NOT NULL DEFAULT 0,
  is_active   INTEGER NOT NULL DEFAULT 1,
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL
);

-- 2. 后端动态模板内容表（5 段内容 JSON 列）
CREATE TABLE IF NOT EXISTS templates (
  id                   TEXT PRIMARY KEY,
  name                 TEXT NOT NULL,
  author               TEXT NOT NULL DEFAULT 'Lumira',
  version              TEXT NOT NULL DEFAULT '1.0.0',
  category             TEXT NOT NULL,
  price                INTEGER NOT NULL DEFAULT 0,
  cover_url            TEXT NOT NULL,
  description          TEXT NOT NULL DEFAULT '',
  reference_source     TEXT NOT NULL DEFAULT '',
  tags_json            TEXT NOT NULL DEFAULT '[]',
  tag_ids_json         TEXT NOT NULL DEFAULT '[]',
  classification_json  TEXT NOT NULL DEFAULT '{}',
  sort_order           INTEGER NOT NULL DEFAULT 0,
  is_active            INTEGER NOT NULL DEFAULT 1,
  composition_json     TEXT NOT NULL DEFAULT '{}',
  pose_json            TEXT NOT NULL DEFAULT '{}',
  camera_json          TEXT NOT NULL DEFAULT '{}',
  scene_guide_json     TEXT NOT NULL DEFAULT '{}',
  post_process_json    TEXT NOT NULL DEFAULT '{}',
  created_at           INTEGER NOT NULL,
  updated_at           INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_templates_category ON templates(category);
CREATE INDEX IF NOT EXISTS idx_templates_sort_order ON templates(sort_order);

-- 3. 预置 7 个系统分类（key 与 Flutter 内置 7 类严格对齐，icon_url 空字符串表示用 Flutter 内置映射）
INSERT OR IGNORE INTO template_categories (key, name, icon_url, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('portrait',    '人像',   '', 1, 1, 1, 0, 0),
  ('landscape',   '风景',   '', 2, 1, 1, 0, 0),
  ('food',        '美食',   '', 3, 1, 1, 0, 0),
  ('street',      '街拍',   '', 4, 1, 1, 0, 0),
  ('night',       '夜景',   '', 5, 1, 1, 0, 0),
  ('macro',       '微距',   '', 6, 1, 1, 0, 0),
  ('still-life',  '静物',   '', 7, 1, 1, 0, 0);
