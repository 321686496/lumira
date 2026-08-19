-- 账号恢复（spec 2026-08-19-account-recovery-design）
-- 幂等：由 _migrations 表记录，仅执行一次
ALTER TABLE `devices`
  ADD COLUMN `recovery_secret_hash` VARCHAR(64) NULL,
  ADD COLUMN `recovery_secret_created_at` INT NULL,
  ADD COLUMN `email` VARCHAR(255) NULL,
  ADD COLUMN `email_verified_at` INT NULL,
  ADD COLUMN `session_epoch` INT NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS `account_otp` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `email` VARCHAR(255) NOT NULL,
  `device_id` TEXT NULL,
  `purpose` VARCHAR(16) NOT NULL,
  `code_hash` VARCHAR(64) NOT NULL,
  `expires_at` INT NOT NULL,
  `consumed_at` INT NULL,
  `attempts` INT NOT NULL DEFAULT 0,
  `created_at` INT NOT NULL
);
CREATE INDEX `idx_account_otp_email_purpose` ON `account_otp` (`email`, `purpose`);
CREATE UNIQUE INDEX `uq_devices_email` ON `devices` (`email`);