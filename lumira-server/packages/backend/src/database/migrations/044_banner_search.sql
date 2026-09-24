-- lumira-server/packages/backend/src/database/migrations/044_banner_search.sql
-- 首页 Banner 新增「App 内搜索」类型（kind=search）：
--   search_keyword : App 内搜索关键字（kind=search 时必填，跳转全局搜索页并预填）
--   search_scope   : 搜索范围，all=全部 / template=模板 / scene=场景 / academy=美学院（默认 all）
-- NULL 兼容旧数据与非 search 条目；App 读取时 search_scope 空回退 all。
ALTER TABLE `operation_banners`
  ADD COLUMN `search_keyword` varchar(128) NULL AFTER `external_url`,
  ADD COLUMN `search_scope` varchar(16) NULL DEFAULT 'all' AFTER `search_keyword`;