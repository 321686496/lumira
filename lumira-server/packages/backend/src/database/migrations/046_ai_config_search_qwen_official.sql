-- 046: AI 服务商配置新增 Qwen 官方百炼联网搜索字段（search_provider=qwen-official 时使用）
-- 均为可空新增列，不影响存量配置（幂等由 _migrations 表保证只执行一次）。
-- 现有 search_qwen_*（第三方 MaaS，search_provider=qwen）字段保持不动，线上数据零迁移。
ALTER TABLE ai_provider_config
  ADD COLUMN search_qwen_official_base_url VARCHAR(255) NULL AFTER search_qwen_model,
  ADD COLUMN search_qwen_official_api_key VARCHAR(255) NULL AFTER search_qwen_official_base_url,
  ADD COLUMN search_qwen_official_model VARCHAR(64) NULL AFTER search_qwen_official_api_key;
