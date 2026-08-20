-- lumira-server/packages/backend/src/database/migrations/012_profile_preferences.sql
-- 个人中心偏好 + 自定义头像（spec 2026-08-20-profile-questionnaire-enhancement-design §2.2）

ALTER TABLE user_profiles
  ADD COLUMN gender VARCHAR(20) NULL,
  ADD COLUMN favorite_categories_json TEXT NULL,
  ADD COLUMN pain_points_json TEXT NULL,
  ADD COLUMN skill_level VARCHAR(20) NULL,
  ADD COLUMN expectations_json TEXT NULL,
  ADD COLUMN common_scenes_json TEXT NULL,
  ADD COLUMN shoot_frequency VARCHAR(20) NULL,
  ADD COLUMN avatar_url VARCHAR(255) NULL;