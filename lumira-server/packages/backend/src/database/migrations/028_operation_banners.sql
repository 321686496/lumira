-- lumira-server/packages/backend/src/database/migrations/028_operation_banners.sql
-- 首页运营 Banner 配置表（后台下发）。初始 3 条对齐 App 静态 kOperationBanners，
-- 使后台开箱即可编辑现有运营位；App 端拉取成功后以本表为准。
-- 注意：`condition` 为 MySQL 保留字，必须反引号。
CREATE TABLE IF NOT EXISTS `operation_banners` (
  `id` VARCHAR(64) NOT NULL,
  `title` VARCHAR(128) NOT NULL,
  `subtitle` VARCHAR(255) NOT NULL,
  `tag` VARCHAR(32) NOT NULL,
  `route` VARCHAR(128) NOT NULL,
  `condition` VARCHAR(64) NOT NULL,
  `is_active` INT NOT NULL DEFAULT 1,
  `sort_order` INT NOT NULL DEFAULT 0,
  `created_at` INT NOT NULL,
  `updated_at` INT NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `operation_banners`
  (`id`, `title`, `subtitle`, `tag`, `route`, `condition`, `is_active`, `sort_order`, `created_at`, `updated_at`)
VALUES
  ('op_invite', '邀请好友 · 双方各+30分', '绑定邀请码完成首拍，双方各得 30 积分', '邀请有礼', '/invite', 'nonNewUserNotInvited', 1, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
  ('op_points', '积分当钱花 · 解锁模板', '拍摄攒积分，攒够就兑换心仪模板', '积分乐园', '/points/wallet', 'pointsReady', 1, 2, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
  ('op_unlock', '尊享上新 · 一键解锁', '用积分或邀请奖励，解锁付费模板', '上新', '/templates/unlock', 'hasLockedTemplate', 1, 3, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());
