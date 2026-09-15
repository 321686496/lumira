-- 037: 剪影模态可选独立平台（NULL = 跟随生图模态，语义同 032 文本/生图独立平台）
ALTER TABLE ai_provider_config
  ADD COLUMN silhouette_provider VARCHAR(32) NULL AFTER silhouette_model,
  ADD COLUMN silhouette_base_url VARCHAR(255) NULL AFTER silhouette_provider,
  ADD COLUMN silhouette_api_key VARCHAR(255) NULL AFTER silhouette_base_url;
