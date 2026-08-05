-- lumira-server/packages/backend/src/database/migrations/001_init.sql

CREATE TABLE IF NOT EXISTS devices (
  device_id    TEXT PRIMARY KEY,
  alias        TEXT,
  first_seen_at INTEGER NOT NULL,
  last_seen_at  INTEGER NOT NULL,
  ip_region     TEXT
);

CREATE TABLE IF NOT EXISTS invite_records (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  inviter_device_id TEXT NOT NULL REFERENCES devices(device_id),
  invitee_device_id TEXT NOT NULL UNIQUE REFERENCES devices(device_id),
  invite_code       TEXT NOT NULL,
  channel           TEXT NOT NULL DEFAULT 'direct',
  activated_at      INTEGER NOT NULL,
  inviter_ip        TEXT,
  invitee_ip        TEXT
);
CREATE INDEX IF NOT EXISTS idx_invite_records_inviter ON invite_records(inviter_device_id);
CREATE INDEX IF NOT EXISTS idx_invite_records_code ON invite_records(invite_code);

CREATE TABLE IF NOT EXISTS reward_tiers (
  tier             INTEGER PRIMARY KEY,
  required_invites INTEGER NOT NULL,
  rewards_json     TEXT NOT NULL DEFAULT '[]',
  is_active        INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS reward_unlocks (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id       TEXT NOT NULL REFERENCES devices(device_id),
  tier            INTEGER NOT NULL REFERENCES reward_tiers(tier),
  source          TEXT NOT NULL,
  source_detail   TEXT,
  status          TEXT NOT NULL DEFAULT 'unlocked',
  unlocked_at     INTEGER NOT NULL,
  claimed_at      INTEGER
);
CREATE INDEX IF NOT EXISTS idx_reward_unlocks_device ON reward_unlocks(device_id);

CREATE TABLE IF NOT EXISTS redemption_code_batches (
  batch_id         INTEGER PRIMARY KEY AUTOINCREMENT,
  campaign_name    TEXT NOT NULL,
  reward_tier      INTEGER NOT NULL REFERENCES reward_tiers(tier),
  max_uses_per_code INTEGER NOT NULL DEFAULT 1,
  total_generated  INTEGER NOT NULL,
  total_used       INTEGER NOT NULL DEFAULT 0,
  reward_points    INTEGER NOT NULL DEFAULT 0,
  valid_from       INTEGER,
  valid_until      INTEGER,
  is_active        INTEGER NOT NULL DEFAULT 1,
  created_at       INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS redemption_codes (
  code             TEXT PRIMARY KEY,
  batch_id         INTEGER NOT NULL REFERENCES redemption_code_batches(batch_id),
  used_count       INTEGER NOT NULL DEFAULT 0,
  max_uses         INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_redemption_codes_batch ON redemption_codes(batch_id);

CREATE TABLE IF NOT EXISTS redemption_records (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  code          TEXT NOT NULL REFERENCES redemption_codes(code),
  device_id     TEXT NOT NULL REFERENCES devices(device_id),
  redeemed_at   INTEGER NOT NULL,
  ip_address    TEXT
);
CREATE INDEX IF NOT EXISTS idx_redemption_records_code ON redemption_records(code);
CREATE INDEX IF NOT EXISTS idx_redemption_records_device ON redemption_records(device_id);

-- 默认奖励阶梯配置
INSERT OR IGNORE INTO reward_tiers (tier, required_invites, rewards_json, is_active) VALUES
  (1, 1, '[{"type":"template","id":"jp-film","label":"日系胶片模板"}]', 1),
  (2, 3, '[{"type":"template_pack","id":"french-retro","label":"法式复古模板包(含3个模板)"}]', 1),
  (3, 5, '[{"type":"template_pack","id":"ambience-portrait","label":"氛围感写真模板包(含5个模板)"}]', 1),
  (4, 10, '[{"type":"achievement","id":"share-master","label":"分享达人成就"}]', 1);

CREATE TABLE IF NOT EXISTS questionnaire_records (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id     TEXT NOT NULL,
  answers_json  TEXT NOT NULL,
  submitted_at  INTEGER NOT NULL,
  client_ip     TEXT
);
CREATE INDEX IF NOT EXISTS idx_questionnaire_records_device ON questionnaire_records(device_id);
CREATE INDEX IF NOT EXISTS idx_questionnaire_records_submitted ON questionnaire_records(submitted_at DESC);
