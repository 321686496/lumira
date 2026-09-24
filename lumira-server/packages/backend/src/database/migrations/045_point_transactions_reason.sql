-- lumira-server/packages/backend/src/database/migrations/045_point_transactions_reason.sql
-- 积分流水新增「备注原因」列：
--   后台给用户充值积分时填写的充值原因会写入该列，App 端积分流水直接展示该原因
--   （未填写时为 NULL，客户端回退显示「后台发放」等通用来源文案）。
ALTER TABLE `point_transactions`
  ADD COLUMN `reason` varchar(256) NULL AFTER `ref_id`;