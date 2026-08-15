-- lumira-server/packages/backend/src/database/migrations/001_init.sql

CREATE TABLE IF NOT EXISTS devices (
  device_id     VARCHAR(64) PRIMARY KEY,
  alias         VARCHAR(255),
  platform      VARCHAR(64),
  os_version    VARCHAR(64),
  device_model  VARCHAR(128),
  app_version   VARCHAR(64),
  first_seen_at INT NOT NULL,
  last_seen_at  INT NOT NULL,
  ip_region     VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS invite_records (
  id                INT AUTO_INCREMENT PRIMARY KEY,
  inviter_device_id VARCHAR(64) NOT NULL,
  invitee_device_id VARCHAR(64) NOT NULL UNIQUE,
  invite_code       VARCHAR(64) NOT NULL,
  channel           VARCHAR(32) NOT NULL DEFAULT 'direct',
  activated_at      INT NOT NULL,
  inviter_ip        VARCHAR(64),
  invitee_ip        VARCHAR(64),
  CONSTRAINT fk_invite_inviter FOREIGN KEY (inviter_device_id) REFERENCES devices(device_id),
  CONSTRAINT fk_invite_invitee FOREIGN KEY (invitee_device_id) REFERENCES devices(device_id)
) ENGINE=InnoDB;
CREATE INDEX idx_invite_records_inviter ON invite_records(inviter_device_id);
CREATE INDEX idx_invite_records_code ON invite_records(invite_code);

CREATE TABLE IF NOT EXISTS reward_tiers (
  tier             INT PRIMARY KEY,
  required_invites INT NOT NULL,
  rewards_json     TEXT NOT NULL,
  is_active        INT NOT NULL DEFAULT 1
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS reward_unlocks (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  device_id       VARCHAR(64) NOT NULL,
  tier            INT NOT NULL,
  source          VARCHAR(64) NOT NULL,
  source_detail   VARCHAR(255),
  status          VARCHAR(32) NOT NULL DEFAULT 'unlocked',
  unlocked_at     INT NOT NULL,
  claimed_at      INT,
  CONSTRAINT fk_reward_unlock_device FOREIGN KEY (device_id) REFERENCES devices(device_id),
  CONSTRAINT fk_reward_unlock_tier FOREIGN KEY (tier) REFERENCES reward_tiers(tier)
) ENGINE=InnoDB;
CREATE INDEX idx_reward_unlocks_device ON reward_unlocks(device_id);

CREATE TABLE IF NOT EXISTS redemption_code_batches (
  batch_id          INT AUTO_INCREMENT PRIMARY KEY,
  campaign_name     VARCHAR(255) NOT NULL,
  max_uses_per_code INT NOT NULL DEFAULT 1,
  total_generated   INT NOT NULL,
  total_used        INT NOT NULL DEFAULT 0,
  reward_points     INT NOT NULL DEFAULT 0,
  reward_templates  TEXT NOT NULL,
  valid_from        INT,
  valid_until       INT,
  is_active         INT NOT NULL DEFAULT 1,
  created_at        INT NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS redemption_codes (
  code       VARCHAR(64) PRIMARY KEY,
  batch_id   INT NOT NULL,
  used_count INT NOT NULL DEFAULT 0,
  max_uses   INT NOT NULL DEFAULT 1,
  CONSTRAINT fk_redemption_codes_batch FOREIGN KEY (batch_id) REFERENCES redemption_code_batches(batch_id)
) ENGINE=InnoDB;
CREATE INDEX idx_redemption_codes_batch ON redemption_codes(batch_id);

CREATE TABLE IF NOT EXISTS redemption_records (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  code        VARCHAR(64) NOT NULL,
  device_id   VARCHAR(64) NOT NULL,
  redeemed_at INT NOT NULL,
  ip_address  VARCHAR(64),
  CONSTRAINT fk_redemption_records_code FOREIGN KEY (code) REFERENCES redemption_codes(code),
  CONSTRAINT fk_redemption_records_device FOREIGN KEY (device_id) REFERENCES devices(device_id)
) ENGINE=InnoDB;
CREATE INDEX idx_redemption_records_code ON redemption_records(code);
CREATE INDEX idx_redemption_records_device ON redemption_records(device_id);

-- 默认奖励阶梯配置（INSERT IGNORE 幂等）
INSERT IGNORE INTO reward_tiers (tier, required_invites, rewards_json, is_active) VALUES
  (1, 1, '[{"type":"template","id":"jp-film","label":"日系胶片模板"}]', 1),
  (2, 3, '[{"type":"template_pack","id":"french-retro","label":"法式复古模板包(含 2 个模板)"}]', 1),
  (3, 5, '[{"type":"template_pack","id":"ambience-portrait","label":"氛围感写真模板包(含 2 个模板)"}]', 1),
  (4, 10, '[{"type":"achievement","id":"share-master","label":"分享达人成就"}]', 1);

CREATE TABLE IF NOT EXISTS questionnaire_records (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  device_id    VARCHAR(64) NOT NULL,
  answers_json LONGTEXT NOT NULL,
  submitted_at INT NOT NULL,
  client_ip    VARCHAR(64)
) ENGINE=InnoDB;
CREATE INDEX idx_questionnaire_records_device ON questionnaire_records(device_id);
CREATE INDEX idx_questionnaire_records_submitted ON questionnaire_records(submitted_at DESC);
