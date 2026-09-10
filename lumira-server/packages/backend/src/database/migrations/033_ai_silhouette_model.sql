-- lumira-server/packages/backend/src/database/migrations/033_ai_silhouette_model.sql
-- AI 剪影专用模型（spec：ai-template-oneclick-enhance Phase 2）
-- 语义：NULL/空 = 与生图模型一致（默认零配置即用）；非空 = 单独指定的专用剪影模型。
ALTER TABLE `ai_provider_config`
  ADD COLUMN `silhouette_model` VARCHAR(64) NULL AFTER `image_model`;
