-- lumira-server/packages/backend/src/database/migrations/047_ai_config_llm_stability.sql
-- AI 识别链路稳定性配置：JSON 解析失败重试次数 / 单次 LLM 调用超时 / 单次输出 token 上限
-- 幂等：由 _migrations 表记录，仅执行一次；NOT NULL DEFAULT 保证存量行零数据迁移

ALTER TABLE `ai_provider_config`
  ADD COLUMN `llm_retry_count` INT NOT NULL DEFAULT 2 COMMENT '识别步骤失败后额外重试次数（0~3；总调用 ≤ 次数+1）',
  ADD COLUMN `llm_timeout_ms` INT NOT NULL DEFAULT 300000 COMMENT '单次 LLM 调用超时（毫秒）',
  ADD COLUMN `llm_max_tokens` INT NOT NULL DEFAULT 8192 COMMENT '单次 LLM 输出 token 上限';