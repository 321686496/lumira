// lumira-server/packages/backend/src/database/database.service.ts

import { Injectable, OnModuleInit } from '@nestjs/common';
import Database from 'better-sqlite3';
import { drizzle, BetterSQLite3Database } from 'drizzle-orm/better-sqlite3';
import * as fs from 'fs';
import * as path from 'path';
import * as schema from './schema';

@Injectable()
export class DatabaseService implements OnModuleInit {
  private sqlite!: Database.Database;
  private db!: BetterSQLite3Database<typeof schema>;

  onModuleInit() {
    const dbPath = process.env.DB_PATH || './data/lumira.db';
    const dir = path.dirname(dbPath);

    // 确保数据目录存在
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    this.sqlite = new Database(dbPath);
    this.sqlite.pragma('journal_mode = WAL');
    this.sqlite.pragma('foreign_keys = ON');

    // 兼容旧库：template_categories 主键从 key 改为自增 id（spec 11 三级分类扩展）。
    // SQLite 不支持 ALTER TABLE 修改主键，故在迁移执行前检测旧 schema 并重建表。
    this.upgradeCategorySchemaIfNeeded();

    this.db = drizzle(this.sqlite, { schema });

    // 执行初始迁移
    this.runMigrations();
  }

  /**
   * 检测 template_categories 是否为旧 schema（key PRIMARY KEY，无 parent_key/level/id），
   * 若是则重建为新 schema（id 自增主键 + parent_key + level + 联合唯一索引）。
   * 必须在 runMigrations() 之前执行，确保 005 迁移的 INSERT 能找到 parent_key 列。
   */
  private upgradeCategorySchemaIfNeeded(): void {
    const cols = this.sqlite.prepare('PRAGMA table_info(template_categories)').all() as { name: string }[];
    if (cols.length === 0) {
      // 表不存在（全新库），003 迁移会以新 schema 创建，无需处理
      return;
    }
    if (cols.some((c) => c.name === 'parent_key')) {
      // 新 schema 已就位
      return;
    }

    // 旧 schema：重建表
    this.sqlite.exec(`
      CREATE TABLE template_categories_new (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        key         TEXT NOT NULL,
        name        TEXT NOT NULL,
        icon_url    TEXT NOT NULL,
        parent_key  TEXT,
        level       INTEGER NOT NULL DEFAULT 1,
        sort_order  INTEGER NOT NULL DEFAULT 0,
        is_system   INTEGER NOT NULL DEFAULT 0,
        is_active   INTEGER NOT NULL DEFAULT 1,
        created_at  INTEGER NOT NULL,
        updated_at  INTEGER NOT NULL
      );
      CREATE UNIQUE INDEX uq_category_key_parent ON template_categories_new(key, parent_key);

      INSERT INTO template_categories_new (key, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at)
      SELECT key, name, icon_url, NULL, 1, sort_order, is_system, is_active, created_at, updated_at
      FROM template_categories;

      DROP TABLE template_categories;
      ALTER TABLE template_categories_new RENAME TO template_categories;
    `);
  }

  private runMigrations() {
    // dist/database/migrations/ (prod, copied by nest build assets)
    // src/database/migrations/  (dev, nest start --watch doesn't copy assets)
    const candidates = [
      path.join(__dirname, 'migrations'),
      path.join(__dirname, '..', '..', 'src', 'database', 'migrations'),
    ];
    const migrationsDir = candidates.find((p) => fs.existsSync(p));
    if (!migrationsDir) {
      throw new Error(`Migrations directory not found. Tried: ${candidates.join(', ')}`);
    }
    const files = fs.readdirSync(migrationsDir)
      .filter((f) => f.endsWith('.sql'))
      .sort();
    for (const file of files) {
      const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf-8');
      this.sqlite.exec(sql);
    }

    // 兼容旧库：redemption_code_batches 的 reward_points / reward_templates 列。
    // 迁移使用 CREATE TABLE IF NOT EXISTS，不会修改已存在的表，故对旧库做幂等补充。
    const batchColumns = this.sqlite.prepare('PRAGMA table_info(redemption_code_batches)').all() as { name: string }[];
    if (!batchColumns.some((c) => c.name === 'reward_points')) {
      this.sqlite.exec('ALTER TABLE redemption_code_batches ADD COLUMN reward_points INTEGER NOT NULL DEFAULT 0');
    }
    if (!batchColumns.some((c) => c.name === 'reward_templates')) {
      this.sqlite.exec("ALTER TABLE redemption_code_batches ADD COLUMN reward_templates TEXT NOT NULL DEFAULT '[]'");
    }

    // 兼容旧库：移除 redemption_code_batches.reward_tier 列（007 迁移）。
    // 该列在旧 001_init.sql 中为 NOT NULL 且被 schema 移除，插入时必然违反约束；
    // SQLite 不支持 ALTER TABLE DROP COLUMN 外键列，故重建表（先补充列后再重建）。
    if (batchColumns.some((c) => c.name === 'reward_tier')) {
      this.sqlite.exec('PRAGMA foreign_keys = OFF');
      this.sqlite.exec(`
        CREATE TABLE redemption_code_batches_new (
          batch_id          INTEGER PRIMARY KEY AUTOINCREMENT,
          campaign_name     TEXT NOT NULL,
          max_uses_per_code INTEGER NOT NULL DEFAULT 1,
          total_generated   INTEGER NOT NULL,
          total_used        INTEGER NOT NULL DEFAULT 0,
          reward_points     INTEGER NOT NULL DEFAULT 0,
          reward_templates  TEXT NOT NULL DEFAULT '[]',
          valid_from        INTEGER,
          valid_until       INTEGER,
          is_active         INTEGER NOT NULL DEFAULT 1,
          created_at        INTEGER NOT NULL
        );
        INSERT INTO redemption_code_batches_new (
          batch_id, campaign_name, max_uses_per_code, total_generated, total_used,
          reward_points, reward_templates, valid_from, valid_until, is_active, created_at
        )
        SELECT
          batch_id, campaign_name, max_uses_per_code, total_generated, total_used,
          reward_points, COALESCE(reward_templates, '[]'), valid_from, valid_until, is_active, created_at
        FROM redemption_code_batches;
        DROP TABLE redemption_code_batches;
        ALTER TABLE redemption_code_batches_new RENAME TO redemption_code_batches;
      `);
      this.sqlite.exec('PRAGMA foreign_keys = ON');
    }

    // 兼容旧库：devices 表新增设备信息字段（009 迁移）
    const deviceColumns = this.sqlite.prepare('PRAGMA table_info(devices)').all() as { name: string }[];
    if (!deviceColumns.some((c) => c.name === 'platform')) {
      this.sqlite.exec('ALTER TABLE devices ADD COLUMN platform TEXT');
    }
    if (!deviceColumns.some((c) => c.name === 'os_version')) {
      this.sqlite.exec('ALTER TABLE devices ADD COLUMN os_version TEXT');
    }
    if (!deviceColumns.some((c) => c.name === 'device_model')) {
      this.sqlite.exec('ALTER TABLE devices ADD COLUMN device_model TEXT');
    }
    if (!deviceColumns.some((c) => c.name === 'app_version')) {
      this.sqlite.exec('ALTER TABLE devices ADD COLUMN app_version TEXT');
    }
  }

  getDb(): BetterSQLite3Database<typeof schema> {
    return this.db;
  }

  getRawDb(): Database.Database {
    return this.sqlite;
  }
}
