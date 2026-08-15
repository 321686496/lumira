-- lumira-server/packages/backend/src/database/migrations/002_points.sql
-- 积分体系：用户积分账户、流水、已拥有模板、模板定价、签到记录

-- 1. 用户积分账户
CREATE TABLE IF NOT EXISTS user_points (
  device_id    VARCHAR(64) PRIMARY KEY,
  balance      INT NOT NULL DEFAULT 0,
  total_earned INT NOT NULL DEFAULT 0,
  total_spent  INT NOT NULL DEFAULT 0,
  updated_at   INT NOT NULL,
  CONSTRAINT fk_user_points_device FOREIGN KEY (device_id) REFERENCES devices(device_id)
) ENGINE=InnoDB;

-- 2. 积分流水
CREATE TABLE IF NOT EXISTS point_transactions (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  device_id  VARCHAR(64) NOT NULL,
  delta      INT NOT NULL,
  type       VARCHAR(64) NOT NULL,
  ref_id     VARCHAR(255),
  created_at INT NOT NULL,
  CONSTRAINT fk_point_tx_device FOREIGN KEY (device_id) REFERENCES devices(device_id)
) ENGINE=InnoDB;
CREATE INDEX idx_point_transactions_device ON point_transactions(device_id, created_at DESC);

-- 3. 用户已拥有模板（唯一约束：同设备同模板只记一次）
CREATE TABLE IF NOT EXISTS owned_templates (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  device_id     VARCHAR(64) NOT NULL,
  template_id   VARCHAR(64) NOT NULL,
  source        VARCHAR(32) NOT NULL,
  source_detail VARCHAR(255),
  unlocked_at   INT NOT NULL,
  UNIQUE (device_id, template_id),
  CONSTRAINT fk_owned_templates_device FOREIGN KEY (device_id) REFERENCES devices(device_id)
) ENGINE=InnoDB;
CREATE INDEX idx_owned_templates_device ON owned_templates(device_id);

-- 4. 模板积分定价
CREATE TABLE IF NOT EXISTS template_prices (
  template_id   VARCHAR(64) PRIMARY KEY,
  price_credits INT NOT NULL,
  is_active     INT NOT NULL DEFAULT 1,
  updated_at    INT NOT NULL
) ENGINE=InnoDB;

-- 5. 每日签到记录
CREATE TABLE IF NOT EXISTS daily_sign_in_records (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  device_id     VARCHAR(64) NOT NULL,
  sign_in_date  INT NOT NULL,
  day_index     INT NOT NULL,
  points_earned INT NOT NULL,
  created_at    INT NOT NULL,
  UNIQUE (device_id, sign_in_date),
  CONSTRAINT fk_daily_sign_in_device FOREIGN KEY (device_id) REFERENCES devices(device_id)
) ENGINE=InnoDB;
CREATE INDEX idx_daily_sign_in_device ON daily_sign_in_records(device_id, sign_in_date DESC);

-- 6. 种子：13 个付费模板的积分定价（每个 100 积分）
INSERT IGNORE INTO template_prices (template_id, price_credits, is_active, updated_at) VALUES
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
