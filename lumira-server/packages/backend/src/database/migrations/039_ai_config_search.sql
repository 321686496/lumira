-- 039: AI 服务商配置新增 Agentic 研究管线字段（search 开关/服务商/source/迭代上限）
-- 均为可空或带默认值的新增列，不影响存量配置（向后兼容，幂等由 _migrations 表保证只执行一次）。
ALTER TABLE ai_provider_config
  ADD COLUMN search_enabled INT NOT NULL DEFAULT 0 AFTER enabled,
  ADD COLUMN search_provider VARCHAR(32) NULL AFTER search_enabled,
  ADD COLUMN search_base_url VARCHAR(255) NULL AFTER search_provider,
  ADD COLUMN search_api_key VARCHAR(255) NULL AFTER search_base_url,
  ADD COLUMN search_sources VARCHAR(255) NULL AFTER search_api_key,
  ADD COLUMN max_iterations INT NOT NULL DEFAULT 3 AFTER search_sources;