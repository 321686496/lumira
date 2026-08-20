-- lumira-server/packages/backend/src/database/migrations/018_builtin_scenes_seed.sql
-- 内置场景种子数据：App 内置的 6 个 ScenePreset，保证后台立即可见。
-- 使用 INSERT IGNORE，仅在 id 不存在时插入；App 后续上报的名称更新不受影响。
INSERT IGNORE INTO `builtin_scenes` (`id`, `name`, `updated_at`) VALUES
  ('cafe-window', '咖啡馆', 1787216783000),
  ('sunset-silhouette', '黄昏剪影', 1787216783000),
  ('night-street', '霓虹街角', 1787216783000),
  ('seaside-beach', '海边沙滩', 1787216783000),
  ('forest-bamboo', '竹海禅意', 1787216783000),
  ('rainy-window', '雨窗静思', 1787216783000);