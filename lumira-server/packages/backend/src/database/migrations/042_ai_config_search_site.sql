-- 042: AI 服务商配置新增 SearXNG 站点限定字段（searxng 适配器拼接 site: 前缀）
-- 可空新增列，不影响存量配置（幂等由 _migrations 表保证只执行一次）。
ALTER TABLE ai_provider_config
  ADD COLUMN search_site VARCHAR(255) NULL AFTER search_sources;
