import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { UnauthorizedException } from '@nestjs/common';
import { AdminService } from './admin.service';
import { DatabaseService } from '../../database/database.service';
import { PointsService } from '../points/points.service';

function createQueryBuilder(result: unknown = undefined) {
  const builder: Record<string, unknown> = {};
  const methods = ['innerJoin', 'leftJoin', 'where', 'groupBy', 'limit', 'offset', 'orderBy'];
  for (const method of methods) {
    builder[method] = jest.fn(() => builder);
  }
  builder.from = jest.fn(() => builder);
  builder.set = jest.fn(() => builder);
  builder.values = jest.fn(() => builder);
  builder.execute = jest.fn(async () => result);
  builder.then = jest.fn(async (onFulfilled?: (value: unknown) => unknown) => (
    onFulfilled ? onFulfilled(result) : result
  ));
  builder.catch = jest.fn(async () => result);
  return builder;
}

describe('AdminService.deleteDevice', () => {
  const deviceId = 'device-to-delete';
  let uploadDir: string;
  let transaction: jest.Mock;
  let tx: Record<string, jest.Mock>;
  let getDb: jest.Mock;

  beforeEach(() => {
    uploadDir = fs.mkdtempSync(path.join(os.tmpdir(), 'lumira-admin-delete-'));
    process.env.ADMIN_TOKEN = 'test-admin-key';
    process.env.UPLOAD_DIR = uploadDir;
    fs.mkdirSync(path.join(uploadDir, 'users', deviceId), { recursive: true });

    tx = {
      select: jest.fn(() => createQueryBuilder([])),
      update: jest.fn(() => createQueryBuilder()),
      delete: jest.fn(() => createQueryBuilder()),
    };
    transaction = jest.fn(async (callback: (transaction: unknown) => Promise<unknown>) => callback(tx));
    const db = {
      select: jest.fn(() => createQueryBuilder([])),
      transaction,
    };
    getDb = jest.fn(() => db);
  });

  afterEach(() => {
    fs.rmSync(uploadDir, { recursive: true, force: true });
    delete process.env.ADMIN_TOKEN;
    delete process.env.UPLOAD_DIR;
  });

  function buildService() {
    const dbService = { getDb } as unknown as DatabaseService;
    const pointsService = {} as PointsService;
    return new AdminService(dbService, pointsService);
  }

  it('rejects an invalid login key', async () => {
    await expect(buildService().deleteDevice(deviceId, 'wrong-key'))
      .rejects.toThrow(UnauthorizedException);
    expect(transaction).not.toHaveBeenCalled();
  });

  it('deletes all device rows in one transaction and resets redemption usage', async () => {
    const existingBuilder = createQueryBuilder([{ deviceId }]);
    const feedbackBuilder = createQueryBuilder([{ id: 'fb_1' }]);
    const db = getDb();
    (db as { select: jest.Mock }).select
      .mockReturnValueOnce(existingBuilder)
      .mockReturnValueOnce(feedbackBuilder);

    const usageBuilder = createQueryBuilder([
      { batchId: 7, code: 'CODE-1', usedCount: 2 },
    ]);
    (tx.select as jest.Mock).mockReturnValueOnce(usageBuilder);

    const result = await buildService().deleteDevice(deviceId, 'test-admin-key');

    expect(result).toEqual({ success: true });
    expect(transaction).toHaveBeenCalledTimes(1);
    expect(tx.update).toHaveBeenCalledTimes(2);
    expect(tx.delete).toHaveBeenCalledTimes(15);
  });
});
