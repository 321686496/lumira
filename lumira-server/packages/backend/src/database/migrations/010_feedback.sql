-- lumira-server/packages/backend/src/database/migrations/010_feedback.sql
-- 意见反馈表（spec 2026-08-18-feedback-design）
-- 幂等：由 _migrations 表记录，仅执行一次
CREATE TABLE IF NOT EXISTS `feedbacks` (
  `id` VARCHAR(64) PRIMARY KEY,
  `device_id` TEXT NOT NULL,
  `type` VARCHAR(32) NOT NULL,
  `content` TEXT NOT NULL,
  `contact` TEXT,
  `status` VARCHAR(16) NOT NULL DEFAULT 'pending',
  `screenshots_json` TEXT NOT NULL DEFAULT '[]',
  `client_ip` TEXT,
  `created_at` INT NOT NULL
);
CREATE INDEX `idx_feedbacks_created` ON `feedbacks` (`created_at`);