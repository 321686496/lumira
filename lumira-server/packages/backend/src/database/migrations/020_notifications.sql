-- lumira-server/packages/backend/src/database/migrations/020_notifications.sql
-- 通知公告表（spec 2026-08-20-notifications-center）。
-- 幂等：由 _migrations 表记录，仅执行一次。
CREATE TABLE IF NOT EXISTS `notifications` (
  `id` TEXT NOT NULL,
  `title` TEXT NOT NULL,
  `body` TEXT NOT NULL,
  `icon_key` TEXT NOT NULL DEFAULT ('announcement'),
  `category` TEXT NOT NULL DEFAULT ('announcement'),
  `target_scope` TEXT NOT NULL DEFAULT ('all'),
  `target_device_ids_json` TEXT NOT NULL DEFAULT ('[]'),
  `target_criteria_json` TEXT NOT NULL DEFAULT ('{}'),
  `start_at` INT NULL,
  `end_at` INT NULL,
  `is_active` INT NOT NULL DEFAULT 1,
  `sort_order` INT NOT NULL DEFAULT 0,
  `created_at` INT NOT NULL,
  `updated_at` INT NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;