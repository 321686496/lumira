-- lumira-server/packages/backend/src/database/migrations/036_banner_ad_slot.sql
-- 首页 Banner 新增「活动/广告」槽位（kind=ad）：
--   kind         : 条目类型，operation=现有条件触达运营位 / ad=通用广告曝光（默认 operation）
--   position     : 广告在首页轮播中的绝对槽位下标；NULL=放在最后一个槽位（默认，防打扰）
--   external_url : 广告点击跳转的外部 URL（kind=ad 时必填；App 内点击后用系统浏览器打开，
--                  不跳 App 内路由，故 route 对广告不再约束白名单）
ALTER TABLE `operation_banners`
  ADD COLUMN `kind` varchar(16) NOT NULL DEFAULT 'operation' AFTER `condition`,
  ADD COLUMN `position` int DEFAULT NULL AFTER `sort_order`,
  ADD COLUMN `external_url` varchar(512) DEFAULT NULL AFTER `position`;