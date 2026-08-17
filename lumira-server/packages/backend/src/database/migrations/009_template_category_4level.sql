-- lumira-server/packages/backend/src/database/migrations/009_template_category_4level.sql
-- 模板分类四级化（spec 2026-08-17-template-category-4level-design）
-- 范围：人像(portrait)扩展为 题材→大风格→子风格→方法 四级；非人像题材保持浅层（level 2 style + level 3 method）。
-- 步骤：
--   1. 插入人像大风格（L2，parent=portrait）
--   2. portrait 现有 style（L2）下移为 subStyle（L3），parent_key 改到对应大风格
--   3. portrait 现有 method（L3）下移为 method（L4）
--   4. 老模板 classification_json 平移：style→subStyle，method 保留，majorStyle 由子风格归属回填
-- 幂等说明：迁移由 _migrations 表记录只执行一次；INSERT 用 INSERT IGNORE，UPDATE 带精确 WHERE。

-- ===== 1. 插入人像大风格（level=2）=====
-- 命名规则：不与人像现有 style key（japanese/emotional/...）冲突
INSERT IGNORE INTO template_categories (`key`, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('fresh_healing',    '清新治愈', '', 'portrait', 2, 1, 1, 1, 0, 0),
  ('emotional_film',   '情绪胶片', '', 'portrait', 2, 2, 1, 1, 0, 0),
  ('retro_nostalgia',  '复古怀旧', '', 'portrait', 2, 3, 1, 1, 0, 0),
  ('urban_trend',      '都市潮流', '', 'portrait', 2, 4, 1, 1, 0, 0),
  ('dreamy_night',     '梦幻夜色', '', 'portrait', 2, 5, 1, 1, 0, 0),
  ('scene_portrait',   '场景人像', '', 'portrait', 2, 6, 1, 1, 0, 0);

-- ===== 2. portrait 现有 style（L2）下移为 subStyle（L3），parent_key 改到大风格 =====
UPDATE template_categories SET level = 3, parent_key = 'fresh_healing'
WHERE parent_key = 'portrait' AND level = 2 AND `key` IN
  ('japanese', 'japanese_fresh', 'cream_healing', 'fresh_green', 'sweet_girl', 'morandi_minimal');

UPDATE template_categories SET level = 3, parent_key = 'emotional_film'
WHERE parent_key = 'portrait' AND level = 2 AND `key` IN
  ('emotional', 'film', 'ccd_retro');

UPDATE template_categories SET level = 3, parent_key = 'retro_nostalgia'
WHERE parent_key = 'portrait' AND level = 2 AND `key` IN
  ('hk_noir', 'french_lazy', 'chinese_classical');

UPDATE template_categories SET level = 3, parent_key = 'urban_trend'
WHERE parent_key = 'portrait' AND level = 2 AND `key` IN
  ('western', 'neon_city', 'y2k', 'dark_indoor');

UPDATE template_categories SET level = 3, parent_key = 'dreamy_night'
WHERE parent_key = 'portrait' AND level = 2 AND `key` IN
  ('blue_night', 'purple_dusk', 'anime_dream');

UPDATE template_categories SET level = 3, parent_key = 'scene_portrait'
WHERE parent_key = 'portrait' AND level = 2 AND `key` IN
  ('foodie_portrait', 'elegant_lady');

-- ===== 3. portrait 现有 method（L3）下移为 method（L4）=====
-- 仅处理父级为「已下移为 L3 的 portrait style」的 method，非人像 method 保持 L3。
UPDATE template_categories SET level = 4
WHERE level = 3 AND parent_key IN
  ('japanese', 'japanese_fresh', 'cream_healing', 'fresh_green', 'sweet_girl', 'morandi_minimal',
   'emotional', 'film', 'ccd_retro',
   'hk_noir', 'french_lazy', 'chinese_classical',
   'western', 'neon_city', 'y2k', 'dark_indoor',
   'blue_night', 'purple_dusk', 'anime_dream',
   'foodie_portrait', 'elegant_lady');

-- ===== 4. 老模板 classification_json 平移（style→subStyle + majorStyle 回填）=====
-- 处理所有仍含 style 字段的旧数据（含空串，统一为新结构）；majorStyle 由子风格归属回填，非人像为空串。
UPDATE templates
SET classification_json = JSON_SET(
  JSON_REMOVE(classification_json, '$.style'),
  '$.subStyle',   JSON_UNQUOTE(JSON_EXTRACT(classification_json, '$.style')),
  '$.majorStyle', CASE
    WHEN JSON_UNQUOTE(JSON_EXTRACT(classification_json, '$.style')) IN ('japanese','japanese_fresh','cream_healing','fresh_green','sweet_girl','morandi_minimal') THEN 'fresh_healing'
    WHEN JSON_UNQUOTE(JSON_EXTRACT(classification_json, '$.style')) IN ('emotional','film','ccd_retro') THEN 'emotional_film'
    WHEN JSON_UNQUOTE(JSON_EXTRACT(classification_json, '$.style')) IN ('hk_noir','french_lazy','chinese_classical') THEN 'retro_nostalgia'
    WHEN JSON_UNQUOTE(JSON_EXTRACT(classification_json, '$.style')) IN ('western','neon_city','y2k','dark_indoor') THEN 'urban_trend'
    WHEN JSON_UNQUOTE(JSON_EXTRACT(classification_json, '$.style')) IN ('blue_night','purple_dusk','anime_dream') THEN 'dreamy_night'
    WHEN JSON_UNQUOTE(JSON_EXTRACT(classification_json, '$.style')) IN ('foodie_portrait','elegant_lady') THEN 'scene_portrait'
    ELSE ''
  END
)
WHERE JSON_EXTRACT(classification_json, '$.style') IS NOT NULL;
