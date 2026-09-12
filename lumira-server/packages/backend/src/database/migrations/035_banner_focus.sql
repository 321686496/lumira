-- Banner 背景图可视区域元数据：焦点归一化坐标 0-1，缩放 1-3。
-- NULL 兼容旧数据，App 与后台读取时回退 0.5 / 0.5 / 1.0。
ALTER TABLE `operation_banners`
  ADD COLUMN `focus_x` DOUBLE NULL AFTER `image_url`,
  ADD COLUMN `focus_y` DOUBLE NULL AFTER `focus_x`,
  ADD COLUMN `focus_zoom` DOUBLE NULL AFTER `focus_y`;
