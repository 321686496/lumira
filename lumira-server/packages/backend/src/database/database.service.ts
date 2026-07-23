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
      path.join(__dirname, 'migrations', '001_init.sql'),
      path.join(__dirname, '..', '..', 'src', 'database', 'migrations', '001_init.sql'),
    ];
    const migrationPath = candidates.find((p) => fs.existsSync(p));
    if (!migrationPath) {
      throw new Error(`Migration file not found. Tried: ${candidates.join(', ')}`);
    }
    const sql = fs.readFileSync(migrationPath, 'utf-8');
    this.sqlite.exec(sql);
  }

  getDb(): BetterSQLite3Database<typeof schema> {
    return this.db;
  }

  getRawDb(): Database.Database {
    return this.sqlite;
  }
}
