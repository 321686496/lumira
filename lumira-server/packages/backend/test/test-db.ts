// lumira-server/packages/backend/test/test-db.ts
import { createConnection } from 'mysql2/promise';

/**
 * 测试库隔离：DROP + CREATE 目标测试库，实现与旧版内存库等效的每文件干净状态。
 * 连接参数与环境变量一致；测试库默认 lumira_test。
 */
export async function resetTestDatabase(): Promise<void> {
  const host = process.env.DB_HOST || '127.0.0.1';
  const port = parseInt(process.env.DB_PORT || '3306', 10);
  const user = process.env.DB_USER || 'root';
  const password = process.env.DB_PASSWORD || 'root';
  const database = process.env.DB_NAME || 'lumira_test';

  // 用 root 连接（不指定 database）重建测试库
  const conn = await createConnection({ host, port, user, password, multipleStatements: true });
  try {
    await conn.query(`DROP DATABASE IF EXISTS \`${database}\``);
    await conn.query(`CREATE DATABASE \`${database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
  } finally {
    await conn.end();
  }
}
