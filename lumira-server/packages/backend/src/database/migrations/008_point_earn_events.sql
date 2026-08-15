-- lumira-server/packages/backend/src/database/migrations/008_point_earn_events.sql
-- 通用积分事件发放记录（每日首拍 / 完成挑战等新增获取途径）
-- UNIQUE(device_id, type, ref_id) 保证同一设备同一事件只发一次积分（幂等）

CREATE TABLE IF NOT EXISTS point_earn_events (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  device_id   VARCHAR(64) NOT NULL,
  type        VARCHAR(64) NOT NULL,
  ref_id      VARCHAR(255) NOT NULL,
  points      INT NOT NULL,
  created_at  INT NOT NULL,
  UNIQUE (device_id, type, ref_id),
  CONSTRAINT fk_point_earn_events_device FOREIGN KEY (device_id) REFERENCES devices(device_id)
) ENGINE=InnoDB;
CREATE INDEX idx_point_earn_events_device ON point_earn_events(device_id, created_at DESC);
