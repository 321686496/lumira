-- 030_banner_image_url.sql
-- 首页运营 Banner 支持配图（后台可上传图片，App 端完整显示）。
-- imageUrl 为空时 App 端回退品牌渐变背景，与旧行为兼容。
ALTER TABLE `operation_banners`
  ADD COLUMN `image_url` VARCHAR(512) NULL AFTER `route`;
