-- 迁移 007：兑换码批次移除 reward_tier 依赖，增加 reward_templates 列
-- 对已有表使用 ALTER TABLE 添加列（幂等）
-- 注意：SQLite 不支持删除列，reward_tier 列保留但不再使用

ALTER TABLE redemption_code_batches ADD COLUMN reward_templates TEXT NOT NULL DEFAULT '[]';