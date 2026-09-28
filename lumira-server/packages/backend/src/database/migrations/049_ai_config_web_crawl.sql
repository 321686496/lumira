-- lumira-server/packages/backend/src/database/migrations/049_ai_config_web_crawl.sql
-- AI 设置：网页爬取工具开关（文本模型可按需调用 crawl_website 抓取网页正文）
-- 幂等：由 _migrations 表记录，仅执行一次；NOT NULL DEFAULT 保证存量行零数据迁移

ALTER TABLE `ai_provider_config`
  ADD COLUMN `crawl_enabled` INT NOT NULL DEFAULT 0 COMMENT '网页爬取工具开关：1=启用（文本模型可调用 crawl_website）；0=关闭',
  ADD COLUMN `crawl_max_per_session` INT NOT NULL DEFAULT 3 COMMENT '单次文本会话最多爬取次数（1~6）';
