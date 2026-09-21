-- 041: AI 服务商配置新增 Qwen 模型自带联网搜索字段（search_provider=qwen 时使用）
-- 均为可空新增列，不影响存量配置（幂等由 _migrations 表保证只执行一次）。
ALTER TABLE ai_provider_config
  ADD COLUMN search_qwen_base_url VARCHAR(255) NULL AFTER max_iterations,
  ADD COLUMN search_qwen_api_key VARCHAR(255) NULL AFTER search_qwen_base_url,
  ADD COLUMN search_qwen_model VARCHAR(64) NULL AFTER search_qwen_api_key;