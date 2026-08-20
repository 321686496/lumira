-- lumira-server/packages/backend/src/database/migrations/005_usage_and_scenes.sql
CREATE TABLE IF NOT EXISTS `usage_events` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `device_id` TEXT NOT NULL,
  `client_event_id` TEXT NOT NULL,
  `item_type` TEXT NOT NULL,
  `item_id` TEXT NOT NULL,
  `item_source` TEXT NOT NULL,
  `event_type` TEXT NOT NULL,
  `occurred_at` INT NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_usage_client_event` (`client_event_id`(191))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `system_scenes` (
  `id` VARCHAR(128) NOT NULL,
  `name` TEXT NOT NULL,
  `category` TEXT NOT NULL,
  `style` TEXT NOT NULL DEFAULT '',
  `icon` TEXT NOT NULL DEFAULT '',
  `vibe` TEXT NOT NULL DEFAULT '',
  `description` TEXT NOT NULL DEFAULT '',
  `filter_json` LONGTEXT NOT NULL DEFAULT '{}',
  `tips_json` TEXT NOT NULL DEFAULT '[]',
  `example_images_json` TEXT NOT NULL DEFAULT '[]',
  `where_to_shoot` TEXT NOT NULL DEFAULT '',
  `best_time` TEXT NOT NULL DEFAULT '',
  `related_category` TEXT NOT NULL DEFAULT '',
  `recommended_tag_ids_json` TEXT NOT NULL DEFAULT '[]',
  `sort_order` INT NOT NULL DEFAULT 0,
  `is_active` INT NOT NULL DEFAULT 1,
  `created_at` INT NOT NULL,
  `updated_at` INT NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_system_scenes_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;