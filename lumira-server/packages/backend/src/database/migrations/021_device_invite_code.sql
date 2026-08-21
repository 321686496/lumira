-- lumira-server/packages/backend/src/database/migrations/021_device_invite_code.sql
-- 邀请码从 devices.ip_region 迁移到专属列（spec 2026-08-21-invite-rewards-enhancement）。
-- 幂等：由 _migrations 表记录，仅执行一次。

-- 1) 新增 invite_code 列（可空，未生成邀请码的设备为 NULL）
ALTER TABLE `devices` ADD COLUMN `invite_code` VARCHAR(16) NULL;

-- 2) 一次性迁移：把旧 ip_region 前缀值搬到新列（先迁移后建索引，避免唯一冲突）
UPDATE `devices`
SET `invite_code` = SUBSTRING(`ip_region`, 8)
WHERE `invite_code` IS NULL
  AND `ip_region` LIKE 'invite:%';

-- 3) 唯一索引（MySQL 允许多个 NULL，不影响未生成邀请码的设备）
CREATE UNIQUE INDEX `uq_devices_invite_code` ON `devices`(`invite_code`);