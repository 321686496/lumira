-- 031: AI 配置新增可选文本模型列（空 = 回退视觉模型）
-- 设计文档：docs/specs/2026-09-10-ai-create-enhancement-design.md 第一节
ALTER TABLE ai_provider_config
  ADD COLUMN text_model VARCHAR(64) NULL AFTER vision_model;
