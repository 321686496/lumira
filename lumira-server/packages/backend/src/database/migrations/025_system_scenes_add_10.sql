-- lumira-server/packages/backend/src/database/migrations/025_system_scenes_add_10.sql
-- 新增 10 个贴近日常生活的常用场景，同步到 system_scenes（App 端内置 preset 由 Flutter 侧维护）。
-- 使用 INSERT IGNORE：仅当 id 不存在时插入，不覆盖已有场景的启用/排序/名称等状态。
-- example_images_json 使用 picsum 占位（供 Web/Admin 展示）；App 端封面走本地 localCoverOf 不受影响。
-- sort_order 从 2001 开始递增，排在既有的 24 场景（1001-1024）之后。

INSERT IGNORE INTO `system_scenes`
(`id`, `name`, `category`, `style`, `icon`, `vibe`, `description`,
 `filter_json`, `tips_json`, `example_images_json`, `where_to_shoot`, `best_time`,
 `related_category`, `recommended_tag_ids_json`, `sort_order`, `is_active`, `created_at`, `updated_at`)
VALUES
('living-room', '客厅', 'indoor', 'home', 'ph-sofa', '把一屋子的松弛，坐成日常', '适合白天，明亮舒适的客厅，落地窗与沙发绿植，暖色木质地板，是最治愈的居家大本营。', '{"lut":"warm_film"}', '["让落地窗侧光勾勒沙发与人物","用绿植做前景，增加层次","抓拍躺沙发、喝水的松弛状态"]', '["https://picsum.photos/seed/scene-living-room/600/800"]', '家 / 民宿 / 样板间客厅', '白天 09:00-17:00', 'portrait', '[]', 2001, 1, 1788425541000, 1788425541000),
('classroom', '教室', 'indoor', 'studio', 'ph-chalkboard-teacher', '一页课桌，把青春折进阳光', '适合白天，洒满阳光的教室，木质课桌与黑板，斜射的窗光与书本，是青春的模样。', '{"lut":"japanese_fresh"}', '["利用窗户斜光做侧逆光","课桌阵列做延伸引导线","抓拍看书、抬头、靠在窗边的瞬间"]', '["https://picsum.photos/seed/scene-classroom/600/800"]', '学校教室 / 自习室 / 图书馆', '白天 08:00-17:00', 'portrait', '[]', 2002, 1, 1788425541000, 1788425541000),
('dormitory', '宿舍', 'indoor', 'home', 'ph-bed', '一张小床，把夜晚暖成自己的宇宙', '适合夜晚或早晨，温馨的宿舍床位、暖黄台灯与挂帘，窗外灯火，是专属的小天地。', '{"lut":"warm_film"}', '["用台灯暖光做侧光","床头抱枕挂饰增加生活感","抓拍躺床、倚床头的慵懒瞬间"]', '["https://picsum.photos/seed/scene-dormitory/600/800"]', '大学宿舍 / 公寓卧室 / 合租小房间', '夜晚 19:00-24:00 或早晨', 'portrait', '[]', 2003, 1, 1788425541000, 1788425541000),
('noodle-shop', '面馆', 'indoor', 'cafe', 'ph-bowl-food', '一碗热汤面，把胃和心都填满', '适合饭点，热气腾腾的小面馆，氤氲蒸汽中的一碗面与暖黄灯光，烟火气最抚凡人心。', '{"lut":"warm_film"}', '["逆蒸汽拍，热气透光发亮","暖色顶灯做主光源","加入挑面、喝汤的动作"]', '["https://picsum.photos/seed/scene-noodle-shop/600/800"]', '面馆 / 小馆子 / 拉面店', '饭点 11:00-14:00 / 17:00-21:00', 'food', '[]', 2004, 1, 1788425541000, 1788425541000),
('canteen', '食堂', 'indoor', 'cafe', 'ph-tray', '一到饭点，食堂就是最大的快乐', '适合饭点，明亮熙攘的食堂，暖色灯光下的取餐窗口与餐桌，青春与烟火气都在这。', '{"lut":"warm_film"}', '["取餐窗口暖光做背景光","抓拍端餐盘、就坐的瞬间","利用餐桌纵深做引导线"]', '["https://picsum.photos/seed/scene-canteen/600/800"]', '学校食堂 / 企业餐厅 / 快餐店', '饭点 11:00-13:00 / 17:30-19:00', 'food', '[]', 2005, 1, 1788425541000, 1788425541000),
('office', '办公室', 'indoor', 'studio', 'ph-laptop', '在工位之间，把专注拍成风景', '适合白天，落地玻璃的现代办公区，自然光洒在工位与绿植，精致而专注的氛围。', '{"lut":"cinematic"}', '["落地窗逆光做轮廓光","工位绿植做前景点缀","抓拍敲键盘、翻文件的专注瞬间"]', '["https://picsum.photos/seed/scene-office/600/800"]', '现代办公区 / 咖啡工位 / 联合办公', '白天 09:00-18:00', 'portrait', '[]', 2006, 1, 1788425541000, 1788425541000),
('city-square', '城市广场', 'outdoor', 'urban', 'ph-fountain', '人群聚散之间，把自己走成这座城市', '适合黄昏，开阔的城市广场，喷泉与鸽子，晚霞下的人群与建筑轮廓，辽阔又有人气。', '{"lut":"cinematic"}', '["利用喷泉与建筑做对称构图","黄昏逆光拍城市轮廓","抓拍喂鸽、散步的自然状态"]', '["https://picsum.photos/seed/scene-city-square/600/800"]', '城市广场 / 音乐喷泉 / 地标广场', '黄昏 16:30-19:00', 'street', '[]', 2007, 1, 1788425541000, 1788425541000),
('basketball-court', '篮球场', 'outdoor', 'urban', 'ph-basketball', '一记跳投，把夏天扔进篮筐', '适合午后到黄昏，夕阳下的户外篮球场，地胶与球架剪影，传球投篮充满力量与活力。', '{"lut":"cinematic"}', '["逆光拍跳投剪影","利用球场地胶线条做引导线","抓拍运球、投篮的动感瞬间"]', '["https://picsum.photos/seed/scene-basketball-court/600/800"]', '户外篮球场 / 社区球场 / 学校球场', '午后至黄昏 16:00-19:00', 'portrait', '[]', 2008, 1, 1788425541000, 1788425541000),
('market', '菜市场', 'outdoor', 'urban', 'ph-carrot', '挑挑拣拣，把平淡日子过出滋味', '适合清晨早市，缤纷的蔬菜水果摊与暖黄灯光，买卖与讨价声，是最浓的人间烟火。', '{"lut":"warm_film"}', '["暖黄摊位灯做主光","蔬果做前景，色彩明艳","抓拍挑选、称重的忙碌瞬间"]', '["https://picsum.photos/seed/scene-market/600/800"]', '早市 / 菜市场 / 生鲜集市', '清晨 06:00-10:00', 'food', '[]', 2009, 1, 1788425541000, 1788425541000),
('bus-stop', '公交站', 'outdoor', 'urban', 'ph-bus', '站牌下等一班车，把黄昏过成归途', '适合黄昏到入夜，公交站台的站牌与人影，街道车流与灯光，是每个下班人的日常诗意。', '{"lut":"twilight"}', '["站牌与车流灯光做背景","黄昏蓝调时刻光比柔和","抓拍候车、低头看手机的日常"]', '["https://picsum.photos/seed/scene-bus-stop/600/800"]', '公交站台 / 地铁口 / 车站', '黄昏至入夜 17:30-20:00', 'street', '[]', 2010, 1, 1788425541000, 1788425541000);

-- 同步注册 builtin_scenes（usage 注册表），使新场景可计入使用统计
INSERT IGNORE INTO `builtin_scenes` (`id`, `name`, `updated_at`) VALUES
  ('living-room', '客厅', 1788425541000),
  ('classroom', '教室', 1788425541000),
  ('dormitory', '宿舍', 1788425541000),
  ('noodle-shop', '面馆', 1788425541000),
  ('canteen', '食堂', 1788425541000),
  ('office', '办公室', 1788425541000),
  ('city-square', '城市广场', 1788425541000),
  ('basketball-court', '篮球场', 1788425541000),
  ('market', '菜市场', 1788425541000),
  ('bus-stop', '公交站', 1788425541000);