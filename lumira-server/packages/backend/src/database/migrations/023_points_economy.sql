-- lumira-server/packages/backend/src/database/migrations/023_points_economy.sql
-- 积分经济体系优化：
--   1) user_points 增加免费解锁付费模板次数 free_unlock_count
--   2) 邀请有礼阶梯改为「积分 + 解锁次数 + 成就」三类奖励（覆盖 001_init 旧种子）
--   3) 模板积分定价分层（普通 80 / 精品 120 / 旗舰 160，覆盖 002_points 统一 100）

-- 1) 免费解锁次数（邀请里程碑奖励之一，兑换付费模板时扣减，不耗积分）
ALTER TABLE user_points ADD COLUMN free_unlock_count INT NOT NULL DEFAULT 0;

-- 2) 邀请奖励阶梯覆盖为新配置（tier 主键已存在 → ON DUPLICATE KEY UPDATE 覆盖旧 rewards_json）
INSERT INTO reward_tiers (tier, required_invites, rewards_json, is_active) VALUES
  (1, 1,
   '[{"type":"points","value":20},{"type":"unlock_count","value":1},{"type":"achievement","id":"ach_invite_1","label":"初露锋芒"}]',
   1),
  (2, 3,
   '[{"type":"points","value":80},{"type":"unlock_count","value":1}]',
   1),
  (3, 5,
   '[{"type":"points","value":150},{"type":"unlock_count","value":2},{"type":"achievement","id":"ach_invite_3","label":"人气达人"}]',
   1),
  (4, 10,
   '[{"type":"points","value":300},{"type":"unlock_count","value":3},{"type":"achievement","id":"ach_invite_4","label":"社交之星"}]',
   1)
ON DUPLICATE KEY UPDATE
  required_invites = VALUES(required_invites),
  rewards_json     = VALUES(rewards_json),
  is_active        = VALUES(is_active);

-- 3) 模板积分定价分层（普通 80 / 精品 120 / 旗舰 160）
UPDATE template_prices SET price_credits = 80,  updated_at = UNIX_TIMESTAMP() WHERE template_id IN (
  'macro_flower', 'urban_architecture', 'dark_indoor_portrait', 'blue_night_portrait', 'purple_dusk_portrait'
);
UPDATE template_prices SET price_credits = 120, updated_at = UNIX_TIMESTAMP() WHERE template_id IN (
  'film_vintage', 'neon_portrait', 'french_lazy_portrait', 'morandi_minimal_portrait',
  'neon_city_portrait', 'y2k_portrait', 'anime_dream_portrait'
);
UPDATE template_prices SET price_credits = 160, updated_at = UNIX_TIMESTAMP() WHERE template_id IN (
  'elegant_lady_portrait'
);
