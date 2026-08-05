-- lumira-server/packages/backend/src/database/migrations/002_points.sql
-- 积分体系：用户积分账户、流水、已拥有模板、模板定价、签到记录
-- 注意：redemption_code_batches 的 reward_points 列由 database.service.ts 的 JS 检测补充，
--   这里不写 ALTER TABLE（不幂等）。新库的 001_init.sql 已包含该列。

-- 1. 用户积分账户
CREATE TABLE IF NOT EXISTS user_points (
  device_id     TEXT PRIMARY KEY REFERENCES devices(device_id),
  balance       INTEGER NOT NULL DEFAULT 0,
  total_earned  INTEGER NOT NULL DEFAULT 0,
  total_spent   INTEGER NOT NULL DEFAULT 0,
  updated_at    INTEGER NOT NULL
);

-- 2. 积分流水
CREATE TABLE IF NOT EXISTS point_transactions (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id   TEXT NOT NULL REFERENCES devices(device_id),
  delta       INTEGER NOT NULL,
  type        TEXT NOT NULL,
  ref_id      TEXT,
  created_at  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_point_transactions_device ON point_transactions(device_id, created_at DESC);

-- 3. 用户已拥有模板（唯一约束：同设备同模板只记一次）
CREATE TABLE IF NOT EXISTS owned_templates (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id     TEXT NOT NULL REFERENCES devices(device_id),
  template_id   TEXT NOT NULL,
  source        TEXT NOT NULL,
  source_detail TEXT,
  unlocked_at   INTEGER NOT NULL,
  UNIQUE (device_id, template_id)
);
CREATE INDEX IF NOT EXISTS idx_owned_templates_device ON owned_templates(device_id);

-- 4. 模板积分定价
CREATE TABLE IF NOT EXISTS template_prices (
  template_id    TEXT PRIMARY KEY,
  price_credits  INTEGER NOT NULL,
  is_active      INTEGER NOT NULL DEFAULT 1,
  updated_at     INTEGER NOT NULL
);

-- 5. 每日签到记录
CREATE TABLE IF NOT EXISTS daily_sign_in_records (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id      TEXT NOT NULL REFERENCES devices(device_id),
  sign_in_date   INTEGER NOT NULL,
  day_index      INTEGER NOT NULL,
  points_earned  INTEGER NOT NULL,
  created_at     INTEGER NOT NULL,
  UNIQUE (device_id, sign_in_date)
);
CREATE INDEX IF NOT EXISTS idx_daily_sign_in_device ON daily_sign_in_records(device_id, sign_in_date DESC);

-- 6. 种子：13 个付费模板的积分定价（每个 100 积分）
-- 模板 id 与前端 Flutter/uni-app 两端完全一致
INSERT OR IGNORE INTO template_prices (template_id, price_credits, is_active, updated_at) VALUES
  ('film_vintage',             100, 1, 0),
  ('macro_flower',             100, 1, 0),
  ('neon_portrait',            100, 1, 0),
  ('urban_architecture',       100, 1, 0),
  ('french_lazy_portrait',     100, 1, 0),
  ('morandi_minimal_portrait', 100, 1, 0),
  ('dark_indoor_portrait',     100, 1, 0),
  ('neon_city_portrait',       100, 1, 0),
  ('y2k_portrait',             100, 1, 0),
  ('anime_dream_portrait',     100, 1, 0),
  ('blue_night_portrait',      100, 1, 0),
  ('purple_dusk_portrait',     100, 1, 0),
  ('elegant_lady_portrait',    100, 1, 0);
