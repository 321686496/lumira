-- 039_storage_config.sql
-- 存储配置表：后台可视化配置各厂商 endpoint/凭证/bucket、当前激活存储、图片公网 URL。

CREATE TABLE IF NOT EXISTS storage_config (
  id          VARCHAR(32) PRIMARY KEY COMMENT 'local|r2|aliyun|tencent|qiniu',
  config_json LONGTEXT COMMENT 'JSON: { endpoint, accessKeyId, secretAccessKey, bucket, region, publicUrl }',
  is_active   INT NOT NULL DEFAULT 0 COMMENT '1=当前激活存储',
  updated_at  INT
) ENGINE=InnoDB;