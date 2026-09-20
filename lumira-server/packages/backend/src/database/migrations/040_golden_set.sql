-- 040: AI Golden Set 回归门禁 + Trend Index 新鲜度衰减 + 失败案例库（Task 11）
-- 新增两张表（幂等由 _migrations 表保证只执行一次；CREATE IF NOT EXISTS 兜底）。
CREATE TABLE IF NOT EXISTS trend_index (
  id INT PRIMARY KEY AUTO_INCREMENT,
  topic VARCHAR(255) NOT NULL,
  source VARCHAR(64) NOT NULL DEFAULT '',
  trend_date VARCHAR(32) NOT NULL DEFAULT '',
  title TEXT NOT NULL,
  snippet TEXT NULL,
  keywords_json TEXT NULL,
  img_url TEXT NULL,
  url TEXT NULL,
  popularity DOUBLE NULL,
  payload_json LONGTEXT NULL,
  created_at INT NOT NULL,
  updated_at INT NOT NULL,
  UNIQUE KEY uq_trend_topic_source_date (topic, source, trend_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS template_fail_cases (
  id INT PRIMARY KEY AUTO_INCREMENT,
  template_id TEXT NULL,
  trace_json LONGTEXT NULL,
  reasons_json TEXT NULL,
  fail_count INT NOT NULL DEFAULT 1,
  created_at INT NOT NULL,
  updated_at INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;