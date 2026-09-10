-- 032: 文本/生图模态可选独立平台（NULL = 跟随共享平台）
ALTER TABLE ai_provider_config
  ADD COLUMN text_provider VARCHAR(32) NULL AFTER text_model,
  ADD COLUMN text_base_url VARCHAR(255) NULL AFTER text_provider,
  ADD COLUMN text_api_key VARCHAR(255) NULL AFTER text_base_url,
  ADD COLUMN image_provider VARCHAR(32) NULL AFTER image_model,
  ADD COLUMN image_base_url VARCHAR(255) NULL AFTER image_provider,
  ADD COLUMN image_api_key VARCHAR(255) NULL AFTER image_base_url;
