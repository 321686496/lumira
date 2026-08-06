-- lumira-server/packages/backend/src/database/migrations/005_category_hierarchy.sql
-- 三级分类扩展（spec 2026-08-05 第 11 节）：预置所有二级(style)/三级(method)系统分类
-- 幂等写法：INSERT OR IGNORE（UNIQUE(key, parent_key) 约束保证重复执行不报错）
-- 注意：method 的 key 在不同 style 下可能重复（如 normal/selfie/wide），
-- 但 parent_key 不同，故 (key, parent_key) 联合唯一不冲突。

-- ===== 二级分类（style, level=2）=====

-- portrait 下 21 个 style
INSERT OR IGNORE INTO template_categories (key, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('japanese',           '日系',       '', 'portrait', 2, 1,  1, 1, 0, 0),
  ('emotional',          '情绪',       '', 'portrait', 2, 2,  1, 1, 0, 0),
  ('film',               '胶片',       '', 'portrait', 2, 3,  1, 1, 0, 0),
  ('western',            '欧美',       '', 'portrait', 2, 4,  1, 1, 0, 0),
  ('ccd_retro',          'CCD复古',    '', 'portrait', 2, 5,  1, 1, 0, 0),
  ('hk_noir',            '港风Noir',   '', 'portrait', 2, 6,  1, 1, 0, 0),
  ('japanese_fresh',     '日系清新',   '', 'portrait', 2, 7,  1, 1, 0, 0),
  ('cream_healing',      '奶油治愈',   '', 'portrait', 2, 8,  1, 1, 0, 0),
  ('chinese_classical',  '中式古典',   '', 'portrait', 2, 9,  1, 1, 0, 0),
  ('french_lazy',        '法式慵懒',   '', 'portrait', 2, 10, 1, 1, 0, 0),
  ('morandi_minimal',    '莫兰迪极简', '', 'portrait', 2, 11, 1, 1, 0, 0),
  ('dark_indoor',        '暗调室内',   '', 'portrait', 2, 12, 1, 1, 0, 0),
  ('neon_city',          '霓虹都市',   '', 'portrait', 2, 13, 1, 1, 0, 0),
  ('fresh_green',        '清新绿意',   '', 'portrait', 2, 14, 1, 1, 0, 0),
  ('y2k',                'Y2K千禧',    '', 'portrait', 2, 15, 1, 1, 0, 0),
  ('anime_dream',        '动漫梦境',   '', 'portrait', 2, 16, 1, 1, 0, 0),
  ('blue_night',         '蓝色之夜',   '', 'portrait', 2, 17, 1, 1, 0, 0),
  ('purple_dusk',        '紫色黄昏',   '', 'portrait', 2, 18, 1, 1, 0, 0),
  ('foodie_portrait',    '美食人像',   '', 'portrait', 2, 19, 1, 1, 0, 0),
  ('sweet_girl',         '甜美少女',   '', 'portrait', 2, 20, 1, 1, 0, 0),
  ('elegant_lady',       '优雅女士',   '', 'portrait', 2, 21, 1, 1, 0, 0);

-- landscape 下 2 个 style
INSERT OR IGNORE INTO template_categories (key, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('fresh', '清新', '', 'landscape', 2, 1, 1, 1, 0, 0),
  ('epic',  '大气', '', 'landscape', 2, 2, 1, 1, 0, 0);

-- food 下 2 个 style
INSERT OR IGNORE INTO template_categories (key, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('overhead', '俯拍', '', 'food', 2, 1, 1, 1, 0, 0),
  ('closeup',  '特写', '', 'food', 2, 2, 1, 1, 0, 0);

-- street 下 2 个 style
INSERT OR IGNORE INTO template_categories (key, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('casual',    '随性', '', 'street', 2, 1, 1, 1, 0, 0),
  ('geometric', '几何', '', 'street', 2, 2, 1, 1, 0, 0);

-- night 下 2 个 style
INSERT OR IGNORE INTO template_categories (key, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('neon',   '霓虹', '', 'night', 2, 1, 1, 1, 0, 0),
  ('starry', '星空', '', 'night', 2, 2, 1, 1, 0, 0);

-- macro 下 2 个 style
INSERT OR IGNORE INTO template_categories (key, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('nature', '自然', '', 'macro', 2, 1, 1, 1, 0, 0),
  ('object', '物品', '', 'macro', 2, 2, 1, 1, 0, 0);

-- still-life 下 2 个 style
INSERT OR IGNORE INTO template_categories (key, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('minimal', '极简', '', 'still-life', 2, 1, 1, 1, 0, 0),
  ('flat',    '扁平', '', 'still-life', 2, 2, 1, 1, 0, 0);

-- ===== 三级分类（method, level=3）=====

-- portrait 各 style 下的 method
INSERT OR IGNORE INTO template_categories (key, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('normal',    '他拍',   '', 'japanese',          3, 1, 1, 1, 0, 0),
  ('selfie',    '自拍',   '', 'japanese',          3, 2, 1, 1, 0, 0),
  ('overhead',  '俯拍',   '', 'japanese',          3, 3, 1, 1, 0, 0),
  ('wide',      '远景',   '', 'emotional',         3, 1, 1, 1, 0, 0),
  ('selfie',    '自拍',   '', 'emotional',         3, 2, 1, 1, 0, 0),
  ('normal',    '他拍',   '', 'film',              3, 1, 1, 1, 0, 0),
  ('selfie',    '自拍',   '', 'film',              3, 2, 1, 1, 0, 0),
  ('normal',    '他拍',   '', 'western',           3, 1, 1, 1, 0, 0),
  ('wide',      '远景',   '', 'western',           3, 2, 1, 1, 0, 0),
  ('half_body', '半身',   '', 'ccd_retro',         3, 1, 1, 1, 0, 0),
  ('half_body', '半身',   '', 'hk_noir',           3, 1, 1, 1, 0, 0),
  ('seven_body','七分身', '', 'japanese_fresh',    3, 1, 1, 1, 0, 0),
  ('half_body', '半身',   '', 'cream_healing',     3, 1, 1, 1, 0, 0),
  ('full_body', '全身',   '', 'chinese_classical', 3, 1, 1, 1, 0, 0),
  ('half_body', '半身',   '', 'french_lazy',       3, 1, 1, 1, 0, 0),
  ('half_body', '半身',   '', 'morandi_minimal',   3, 1, 1, 1, 0, 0),
  ('half_body', '半身',   '', 'dark_indoor',       3, 1, 1, 1, 0, 0),
  ('half_body', '半身',   '', 'neon_city',         3, 1, 1, 1, 0, 0),
  ('full_body', '全身',   '', 'fresh_green',       3, 1, 1, 1, 0, 0),
  ('half_body', '半身',   '', 'y2k',               3, 1, 1, 1, 0, 0),
  ('full_body', '全身',   '', 'anime_dream',       3, 1, 1, 1, 0, 0),
  ('seven_body','七分身', '', 'blue_night',        3, 1, 1, 1, 0, 0),
  ('half_body', '半身',   '', 'purple_dusk',       3, 1, 1, 1, 0, 0),
  ('half_body', '半身',   '', 'foodie_portrait',   3, 1, 1, 1, 0, 0),
  ('half_body', '半身',   '', 'sweet_girl',        3, 1, 1, 1, 0, 0),
  ('seven_body','七分身', '', 'elegant_lady',      3, 1, 1, 1, 0, 0);

-- landscape 各 style 下的 method
INSERT OR IGNORE INTO template_categories (key, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('wide',     '远景', '', 'fresh', 3, 1, 1, 1, 0, 0),
  ('flat',     '平拍', '', 'fresh', 3, 2, 1, 1, 0, 0),
  ('wide',     '远景', '', 'epic',  3, 1, 1, 1, 0, 0),
  ('overhead', '俯拍', '', 'epic',  3, 2, 1, 1, 0, 0);

-- food 各 style 下的 method
INSERT OR IGNORE INTO template_categories (key, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('flat',     '平拍', '', 'overhead', 3, 1, 1, 1, 0, 0),
  ('overhead', '俯拍', '', 'overhead', 3, 2, 1, 1, 0, 0),
  ('macro',    '微距', '', 'closeup',  3, 1, 1, 1, 0, 0),
  ('detail',   '细节', '', 'closeup',  3, 2, 1, 1, 0, 0);

-- street 各 style 下的 method
INSERT OR IGNORE INTO template_categories (key, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('normal',   '随拍', '', 'casual',    3, 1, 1, 1, 0, 0),
  ('wide',     '远景', '', 'casual',    3, 2, 1, 1, 0, 0),
  ('wide',     '远景', '', 'geometric', 3, 1, 1, 1, 0, 0),
  ('overhead', '俯拍', '', 'geometric', 3, 2, 1, 1, 0, 0);

-- night 下 neon 的 method（starry 无 method）
INSERT OR IGNORE INTO template_categories (key, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('normal',   '他拍', '', 'neon', 3, 1, 1, 1, 0, 0),
  ('wide',     '远景', '', 'neon', 3, 2, 1, 1, 0, 0);

-- macro 下 nature 的 method（object 无 method）
INSERT OR IGNORE INTO template_categories (key, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('macro',    '微距', '', 'nature', 3, 1, 1, 1, 0, 0);

-- still-life 下 minimal 的 method（flat 无 method）
INSERT OR IGNORE INTO template_categories (key, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('single',   '单品', '', 'minimal', 3, 1, 1, 1, 0, 0);
