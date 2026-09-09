-- lumira-server/packages/backend/src/database/migrations/029_ai_provider_config.sql
-- AI 一键模板录入（spec 2026-09-09-ai-template-one-click-creation-design）
-- 单行配置表：id 恒为 1，由 ai-config service upsert。
-- provider 为厂商预设标识（qwen/doubao/zhipu/openai），为将来接入 dify/coze 工作流预留扩展位。
CREATE TABLE IF NOT EXISTS `ai_provider_config` (
  `id`           INT PRIMARY KEY,
  `provider`     VARCHAR(32)  NOT NULL,
  `base_url`     VARCHAR(255) NOT NULL,
  `api_key`      VARCHAR(255) NOT NULL,
  `vision_model` VARCHAR(64)  NOT NULL,
  `image_model`  VARCHAR(64)  NOT NULL,
  `enabled`      INT NOT NULL DEFAULT 0,
  `created_at`   INT NOT NULL,
  `updated_at`   INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
