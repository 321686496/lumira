-- lumira-server/packages/backend/src/database/migrations/050_ai_config_crawl_render.sql
-- AI 设置：网页爬取的无头渲染降级开关 / 超时 / 按域 cookie（加密存储）
-- 幂等：由 _migrations 表记录，仅执行一次；NOT NULL DEFAULT 保证存量行零数据迁移

ALTER TABLE `ai_provider_config`
  ADD COLUMN `crawl_render_enabled` INT NOT NULL DEFAULT 0 COMMENT '爬取静态失败时是否降级到无头渲染：1=启用；0=关闭',
  ADD COLUMN `crawl_render_timeout_ms` INT NOT NULL DEFAULT 20000 COMMENT '单次无头渲染超时（毫秒，5000~60000）',
  ADD COLUMN `crawl_cookies` TEXT NULL COMMENT '按域名隔离的 cookie（JSON：{domain: cookieString}），AES-256-GCM 加密存储';