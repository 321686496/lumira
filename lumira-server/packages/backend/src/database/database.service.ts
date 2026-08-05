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

    this.db = drizzle(this.sqlite, { schema });

    // 执行初始迁移
    this.runMigrations();
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

    // 兼容旧库：redemption_code_batches 的 reward_points 列。
    // 迁移使用 CREATE TABLE IF NOT EXISTS，不会修改已存在的表，故对旧库做幂等补充。
    const batchColumns = this.sqlite.prepare('PRAGMA table_info(redemption_code_batches)').all() as { name: string }[];
    if (!batchColumns.some((c) => c.name === 'reward_points')) {
      this.sqlite.exec('ALTER TABLE redemption_code_batches ADD COLUMN reward_points INTEGER NOT NULL DEFAULT 0');
    }
  }

  getDb(): BetterSQLite3Database<typeof schema> {
    return this.db;
  }

  getRawDb(): Database.Database {
    return this.sqlite;
  }
}
