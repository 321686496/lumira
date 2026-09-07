-- lumira-server/packages/backend/src/database/migrations/027_invite_achieved_status.sql
-- 邀请达成机制：新用户绑定邀请码后，需首次完成拍照/成片，老用户的邀请才算成立。
-- 为 invite_records 增加 status（pending=已绑定待成片 / success=已成片邀请成立）与 achieved_at。
-- 存量已绑定记录视为已成立（保持历史裂变有效，不回溯补发）。

-- 1) 新增 status 列，默认 pending
ALTER TABLE `invite_records` ADD COLUMN `status` VARCHAR(16) NOT NULL DEFAULT 'pending';

-- 2) 新增 achieved_at 列（可空，pending 时为 NULL）
ALTER TABLE `invite_records` ADD COLUMN `achieved_at` INT NULL;

-- 3) 历史已确认的邀请视为成功（避免存量用户邀请数归零）：仅当后端尚未引入达成机制前
--    的既有记录，统一置为 success，这也意味着其即时奖励已按旧逻辑发过。
UPDATE `invite_records` SET `status` = 'success', `achieved_at` = `activated_at`;