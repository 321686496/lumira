-- lumira-server/packages/backend/src/database/migrations/017_builtin_scenes.sql
CREATE TABLE IF NOT EXISTS `builtin_scenes` (
  `id` VARCHAR(128) NOT NULL,
  `name` TEXT NOT NULL,
  `updated_at` BIGINT NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;