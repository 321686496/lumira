-- lumira-server/packages/backend/src/database/migrations/022_template_images_poses.sql
-- 模板多姿势改造：新增 images_json 列存多图；pose_json 由单对象兼容为数组（spec 2026-08-26-template-multi-pose-phase3）。
-- 幂等：由 _migrations 表记录，仅执行一次。
-- 注：MySQL 8 不支持 ADD COLUMN IF NOT EXISTS（MariaDB 语法），依赖 _migrations 表保证整体幂等；
--     数据级幂等通过 WHERE 条件实现，重跑不会破坏已迁移数据。

-- 1) 新增 images_json 列（存效果图数组，[0]=封面）
ALTER TABLE templates
  ADD COLUMN images_json LONGTEXT NOT NULL DEFAULT ('[]')
  COMMENT '效果图列表 JSON：[{url,data},...]，[0]=封面';

-- 2) 将旧 pose_json 单对象包装为数组（仅在为 JSON OBJECT 时）
UPDATE templates
  SET pose_json = CONCAT('[', pose_json, ']')
  WHERE JSON_TYPE(pose_json) = 'OBJECT';

-- 3) 将旧 cover_url 同步到 images_json 首元素（仅 images_json 为空数组时）
UPDATE templates
  SET images_json = JSON_ARRAY(JSON_OBJECT('url', cover_url))
  WHERE JSON_LENGTH(images_json) = 0
    AND cover_url IS NOT NULL
    AND cover_url != '';
