-- lumira-server/packages/backend/src/database/migrations/003_templates.sql
-- 后台动态模板上传功能（spec 2026-08-05 第 2.2 节）
-- 幂等由版本化迁移执行器保证（_migrations 表只执行一次）

-- 1. 模板分类表（三级树形：type/style/method，key + parent_key 联合唯一）
CREATE TABLE IF NOT EXISTS template_categories (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  `key`       VARCHAR(64) NOT NULL,
  name        VARCHAR(64) NOT NULL,
  icon_url    VARCHAR(512) NOT NULL,
  parent_key  VARCHAR(64),
  level       INT NOT NULL DEFAULT 1,
  sort_order  INT NOT NULL DEFAULT 0,
  is_system   INT NOT NULL DEFAULT 0,
  is_active   INT NOT NULL DEFAULT 1,
  created_at  INT NOT NULL,
  updated_at  INT NOT NULL,
  UNIQUE KEY uq_category_key_parent (`key`, parent_key)
) ENGINE=InnoDB;

-- 2. 后台动态模板内容表（5 段内容 = JSON 列）
CREATE TABLE IF NOT EXISTS templates (
  id                  VARCHAR(64) PRIMARY KEY,
  name                VARCHAR(255) NOT NULL,
  author              VARCHAR(64) NOT NULL DEFAULT 'Lumira',
  version             VARCHAR(32) NOT NULL DEFAULT '1.0.0',
  category            VARCHAR(64) NOT NULL,
  price               INT NOT NULL DEFAULT 0,
  cover_url           VARCHAR(1024) NOT NULL,
  description         TEXT NOT NULL,
  reference_source    VARCHAR(512) NOT NULL DEFAULT '',
  tags_json           TEXT NOT NULL,
  tag_ids_json        TEXT NOT NULL,
  classification_json TEXT NOT NULL,
  sort_order          INT NOT NULL DEFAULT 0,
  is_active           INT NOT NULL DEFAULT 1,
  composition_json    LONGTEXT NOT NULL,
  pose_json           LONGTEXT NOT NULL,
  camera_json         LONGTEXT NOT NULL,
  scene_guide_json    LONGTEXT NOT NULL,
  post_process_json   LONGTEXT NOT NULL,
  created_at          INT NOT NULL,
  updated_at          INT NOT NULL
) ENGINE=InnoDB;
CREATE INDEX idx_templates_category ON templates(category);
CREATE INDEX idx_templates_sort_order ON templates(sort_order);

-- 3. 预置 7 个系统分类（key 与 Flutter 内置 7 类严格对齐，icon_url 空字符串表示用 Flutter 内置映射）
INSERT IGNORE INTO template_categories (`key`, name, icon_url, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('portrait',   '人像', '', 1, 1, 1, 0, 0),
  ('landscape',  '风景', '', 2, 1, 1, 0, 0),
  ('food',       '美食', '', 3, 1, 1, 0, 0),
  ('street',     '街拍', '', 4, 1, 1, 0, 0),
  ('night',      '夜景', '', 5, 1, 1, 0, 0),
  ('macro',      '微距', '', 6, 1, 1, 0, 0),
  ('still-life', '静物', '', 7, 1, 1, 0, 0);
