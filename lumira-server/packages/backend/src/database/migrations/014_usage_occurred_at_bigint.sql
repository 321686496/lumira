-- lumira-server/packages/backend/src/database/migrations/014_usage_occurred_at_bigint.sql
ALTER TABLE `usage_events` MODIFY COLUMN `occurred_at` BIGINT NOT NULL;