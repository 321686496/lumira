-- lumira-server/packages/backend/src/database/migrations/004_user_profiles.sql
-- 用户资料表：随设备注册懒创建，首次注册由后端从昵称池/头像池随机分配

CREATE TABLE IF NOT EXISTS user_profiles (
  device_id   VARCHAR(64) PRIMARY KEY,
  username    VARCHAR(64) NOT NULL,
  avatar_seed VARCHAR(64) NOT NULL,
  updated_at  INT NOT NULL,
  CONSTRAINT fk_user_profiles_device FOREIGN KEY (device_id) REFERENCES devices(device_id)
) ENGINE=InnoDB;
