// lumira-server/packages/backend/src/database/database.service.ts

import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { createPool, Pool } from 'mysql2/promise';
import { drizzle, MySql2Database } from 'drizzle-orm/mysql2';
import * as fs from 'fs';
import * as path from 'path';
import * as schema from './schema';

@Injectable()
export class DatabaseService implements OnModuleInit, OnModuleDestroy {
  private pool!: Pool;
  private db!: MySql2Database<typeof schema>;

  async onModuleInit() {
    const host = process.env.DB_HOST || '127.0.0.1';
    const port = parseInt(process.env.DB_PORT || '3306', 10);
    const user = process.env.DB_USER || 'root';
    const password = process.env.DB_PASSWORD || 'root';
    const database = process.env.DB_NAME || 'lumira';

    this.pool = createPool({
      host,
      port,
      user,
      password,
      database,
      waitForConnections: true,
      connectionLimit: 10,
      // 迁移文件含多条语句，需开启 multipleStatements
      multipleStatements: true,
    });

    this.db = drizzle(this.pool, { schema, mode: 'default' });

    await this.runMigrations();
  }

  async onModuleDestroy() {
    // 关闭连接池，避免 e2e 测试结束后 Jest 因未释放的 mysql 句柄无法退出
    if (this.pool) {
      await this.pool.end();
    }
  }

  /**
   * 版本化迁移执行器：
   * 建 _migrations 表记录已执行的文件名，仅执行未记录的迁移，保证幂等。
   * 目录解析同原 SQLite 版（prod 走 dist，dev 走 src）。
   */
  private async runMigrations() {
    const candidates = [
      path.join(__dirname, 'migrations'),
      path.join(__dirname, '..', '..', 'src', 'database', 'migrations'),
    ];
    const migrationsDir = candidates.find((p) => fs.existsSync(p));
    if (!migrationsDir) {
      throw new Error(`Migrations directory not found. Tried: ${candidates.join(', ')}`);
    }

    const conn = await this.pool.getConnection();

    try {
      await conn.query(
        'CREATE TABLE IF NOT EXISTS _migrations (`name` VARCHAR(255) PRIMARY KEY, `applied_at` INT NOT NULL)',
      );
      const [rows] = await conn.query('SELECT `name` FROM _migrations');
      const applied = new Set((rows as Array<{ name: string }>).map((r) => r.name));

      const files = fs.readdirSync(migrationsDir)
        .filter((f) => f.endsWith('.sql'))
        .sort();

      for (const file of files) {
        if (applied.has(file)) continue;
        const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf-8');
        // 逐条执行并记录，迁移中途失败时该文件不会被标记，重启后重试
        await conn.query(sql);
        await conn.query('INSERT INTO _migrations (`name`, `applied_at`) VALUES (?, ?)', [
          file,
          Math.floor(Date.now() / 1000),
        ]);
        console.log(`[migrate] applied ${file}`);
      }
    } finally {
      conn.release();
    }
  }

  getDb(): MySql2Database<typeof schema> {
    return this.db;
  }
}
