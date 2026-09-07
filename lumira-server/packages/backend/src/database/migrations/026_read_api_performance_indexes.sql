-- lumira-server/packages/backend/src/database/migrations/026_read_api_performance_indexes.sql
-- 读接口性能优化（设计文档 2026-09-07-read-api-performance-optimization-design.md 阶段二）

-- 1) usage_events 热度聚合索引：让 GROUP BY item_id,item_type,event_type（WHERE item_type=?）
--    从全表扫描变为索引扫描（loose index scan），是热度口径所有读接口（search base/scenes/usage stats）的根治项。
--    item_type/item_id/event_type 为 text 列，建索引必须带前缀长度；
--    utf8mb4 下 191 字符 × 4B × 3 列 = 2292B < 3072B（InnoDB 行内索引键上限），合法。
--    MySQL 8 ONLINE DDL（ALGORITHM=INPLACE），建索引不阻塞读写。
CREATE INDEX `idx_usage_stats` ON `usage_events` (`item_type`(191), `item_id`(191), `event_type`(191));

-- 2) templates 列表主排序索引：WHERE is_active=1 ORDER BY sort_order ASC, updated_at DESC
--    覆盖 templateList / search base 的活跃列表扫描
CREATE INDEX `idx_templates_active_sort` ON `templates` (`is_active`, `sort_order`, `updated_at`);

-- 3) templates 增量拉取索引：WHERE is_active=1 AND updated_at > ?
--    覆盖带 since 条件的增量拉取（旧实现该条件在缓存未命中时执行）
CREATE INDEX `idx_templates_active_updated` ON `templates` (`is_active`, `updated_at`);
