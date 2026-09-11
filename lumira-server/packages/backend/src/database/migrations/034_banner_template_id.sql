-- lumira-server/packages/backend/src/database/migrations/034_banner_template_id.sql
-- 运营 Banner 支持跳转到「指定模板详情页」：新增目标模板 id（可空）。
-- route 为 /templates/detail 时必须填写 template_id，App 端据此拼出
-- /templates/detail?templateId=xxx 跳转；其余 route 忽略此列。
ALTER TABLE `operation_banners`
  ADD COLUMN `template_id` VARCHAR(64) NULL DEFAULT NULL AFTER `route`;