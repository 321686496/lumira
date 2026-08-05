-- lumira-server/packages/backend/src/database/migrations/004_user_profiles.sql
-- 用户资料表：随设备注册懒创建，首次注册由后端从昵称池/头像池随机分配

CREATE TABLE IF NOT EXISTS user_profiles (
  device_id    TEXT PRIMARY KEY REFERENCES devices(device_id),
  username     TEXT NOT NULL,
  avatar_seed  TEXT NOT NULL,
  updated_at   INTEGER NOT NULL
);
