-- lumira-server/packages/backend/src/database/migrations/038_storage_migrations.sql
-- 图片存储迁移（R2 迁移）记录表：每次迁移运行一行，失败详情落本地服务器文件。

CREATE TABLE IF NOT EXISTS storage_migrations (
  id            VARCHAR(64) PRIMARY KEY,
  status        VARCHAR(16)  NOT NULL COMMENT 'running|success|failed|stopped',
  trigger_by    TEXT         NOT NULL,
  started_at    INT          NOT NULL,
  finished_at   INT,
  error         TEXT,
  summary_json  LONGTEXT,
  failure_file  VARCHAR(512) COMMENT '失败详情文件（服务器本地相对路径）',
  created_at    INT          NOT NULL
) ENGINE=InnoDB;
-- source_id / target_id 由 043 统一补列（038 曾被误改为建表直含两列，
-- 导致全新库执行 043 时 ER_DUP_FIELDNAME，见 043 注释）