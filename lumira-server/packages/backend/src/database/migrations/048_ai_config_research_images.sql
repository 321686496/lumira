-- lumira-server/packages/backend/src/database/migrations/048_ai_config_research_images.sql
-- AI 参考图抓取配置（spec 2026-09-28-ai-research-reference-images-design.md 第 8 章）
-- 参考图是短 TTL 内部缓存，不为图片新建表；配置随 ai_provider_config 单行配置扩展。

ALTER TABLE `ai_provider_config`
  ADD COLUMN `research_images_enabled` TINYINT NOT NULL DEFAULT 0 COMMENT '参考图抓取总开关',
  ADD COLUMN `research_images_max` INT NOT NULL DEFAULT 6 COMMENT '每主题最多保留张数',
  ADD COLUMN `research_images_page_fetch` TINYINT NOT NULL DEFAULT 1 COMMENT '启用抓页面 og:image',
  ADD COLUMN `research_images_search_fallback` TINYINT NOT NULL DEFAULT 1 COMMENT '启用图片搜索兜底',
  ADD COLUMN `research_images_vision` TINYINT NOT NULL DEFAULT 1 COMMENT '启用多模态解读',
  ADD COLUMN `research_images_ttl_days` INT NOT NULL DEFAULT 7 COMMENT '落盘图片保留天数';
