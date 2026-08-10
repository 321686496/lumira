-- lumira-server/packages/backend/src/database/migrations/008_point_earn_events.sql
-- 通用积分事件发放记录（每日首拍 / 完成挑战等新增获取途径）
-- UNIQUE(device_id, type, ref_id) 保证同一设备同一事件只发一次积分（幂等）

CREATE TABLE IF NOT EXISTS point_earn_events (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id   TEXT NOT NULL REFERENCES devices(device_id),
  type        TEXT NOT NULL,
  ref_id      TEXT NOT NULL,
  points      INTEGER NOT NULL,
  created_at  INTEGER NOT NULL,
  UNIQUE (device_id, type, ref_id)
);
CREATE INDEX IF NOT EXISTS idx_point_earn_events_device ON point_earn_events(device_id, created_at DESC);
