-- lumira-server/packages/backend/src/database/migrations/051_ai_template_jobs.sql
-- AI 生成任务队列（spec 2026-09-30-ai-job-queue-design）
-- DB 只存列表展示数据；详情/事件流/产物/输入落存储文件，由 detail_key 关联
-- 幂等：由 _migrations 表记录，仅执行一次

-- 注意：MySQL 8 不允许 TEXT 作为主键或索引列（报 ER_BLOB_KEY_WITHOUT_LENGTH），
-- 故 id 用 VARCHAR、status 用 VARCHAR（用于索引）；其余非索引文本列保留 TEXT。
CREATE TABLE IF NOT EXISTS `ai_template_jobs` (
  `id` VARCHAR(64) PRIMARY KEY,
  `status` VARCHAR(32) NOT NULL,
  `mode` VARCHAR(32) NOT NULL,
  `title` TEXT NOT NULL,
  `current_stage` TEXT,
  `pose_total` INT NOT NULL DEFAULT 0,
  `pose_done` INT NOT NULL DEFAULT 0,
  `sil_total` INT NOT NULL DEFAULT 0,
  `sil_done` INT NOT NULL DEFAULT 0,
  `queue_pos` INT NOT NULL DEFAULT 0,
  `input_summary_json` LONGTEXT,
  `error_code` TEXT,
  `error_message` TEXT,
  `detail_key` TEXT,
  `created_at` INT NOT NULL,
  `started_at` INT,
  `finished_at` INT
);

CREATE INDEX `idx_ai_template_jobs_status_created` ON `ai_template_jobs` (`status`, `created_at`);

ALTER TABLE `ai_provider_config`
  ADD COLUMN `job_concurrency` INT NOT NULL DEFAULT 2 COMMENT 'AI 生成任务并发上限（1~5）';