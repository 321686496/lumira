// lumira-server/packages/backend/src/modules/banners/banners.service.spec.ts
import { ConflictException } from '@nestjs/common';
import { BannersService } from './banners.service';
import { DatabaseService } from '../../database/database.service';
import { RedisService } from '../../common/redis/redis.service';
import type { CreateBannerDto } from './dto/create-banner.dto';

/** 可 await 的 drizzle 查询链 mock：from/where/orderBy/limit 链式后 resolve 出 rows */
function chainable(rows: unknown) {
  const promise = Promise.resolve(rows);
  const chain: Record<string, unknown> = {
    from: () => chain,
    where: () => chain,
    orderBy: () => chain,
    limit: () => chain,
    then: promise.then.bind(promise),
    catch: promise.catch.bind(promise),
  };
  return chain as never;
}

function buildService(opts: { selectRows?: unknown[]; cached?: unknown } = {}) {
  const select = jest.fn(() => chainable(opts.selectRows ?? []));
  const insertValues = jest.fn(async () => undefined);
  const insert = jest.fn(() => ({ values: insertValues }));
  const updateWhere = jest.fn(async () => undefined);
  const updateSet = jest.fn(() => ({ where: updateWhere }));
  const update = jest.fn(() => ({ set: updateSet }));
  const deleteWhere = jest.fn(async () => undefined);
  const del = jest.fn(() => ({ where: deleteWhere }));
  const db = { select, insert, update, delete: del };
  const dbService = { getDb: () => db } as unknown as DatabaseService;
  const redis = {
    getJson: jest.fn(async () => opts.cached ?? null),
    setJson: jest.fn(async () => undefined),
    delByPattern: jest.fn(async () => undefined),
  } as unknown as RedisService;
  return { service: new BannersService(dbService, redis), select, insertValues, updateSet, redis };
}

const ROW = {
  id: 'op_invite', title: 'T', subtitle: 'S', tag: '邀请有礼',
  route: '/invite', condition: 'nonNewUserNotInvited',
  isActive: 1, sortOrder: 1, createdAt: 1, updatedAt: 1,
};

const CREATE_DTO: CreateBannerDto = {
  title: 'T', subtitle: 'S', tag: '邀请有礼',
  route: '/invite', condition: 'nonNewUserNotInvited',
};

describe('BannersService', () => {
  it('listForApp 只暴露渲染字段并写入 60s 缓存', async () => {
    const { service, redis } = buildService({ selectRows: [ROW] });
    const res = await service.listForApp();
    expect(res.banners).toEqual([{
      id: 'op_invite', title: 'T', subtitle: 'S', tag: '邀请有礼',
      route: '/invite', condition: 'nonNewUserNotInvited',
    }]);
    expect(redis.setJson).toHaveBeenCalledWith('lumira:cache:bannerList', expect.anything(), 60);
  });

  it('listForApp 命中缓存时不再打 DB', async () => {
    const cached = { banners: [] };
    const { service, select } = buildService({ cached });
    expect(await service.listForApp()).toEqual(cached);
    expect(select).not.toHaveBeenCalled();
  });

  it('create 指定已存在 id 时抛 ConflictException', async () => {
    const { service } = buildService({ selectRows: [ROW] });
    await expect(service.create({ ...CREATE_DTO, id: 'op_invite' })).rejects.toThrow(ConflictException);
  });

  it('create 未指定 id 时自动生成并默认 isActive=1/sortOrder=0', async () => {
    const { service, insertValues } = buildService();
    await service.create(CREATE_DTO);
    expect(insertValues).toHaveBeenCalledTimes(1);
    const row = insertValues.mock.calls[0][0];
    expect(row.id).toMatch(/^op-/);
    expect(row.isActive).toBe(1);
    expect(row.sortOrder).toBe(0);
  });

  it('toggleActive 将 1 翻为 0 并失效缓存', async () => {
    const { service, updateSet, redis } = buildService({ selectRows: [ROW] });
    const res = await service.toggleActive('op_invite');
    expect(res.isActive).toBe(false);
    expect(updateSet).toHaveBeenCalledWith(expect.objectContaining({ isActive: 0 }));
    expect(redis.delByPattern).toHaveBeenCalled();
  });

  it('update 只 patch 提供的字段', async () => {
    const { service, updateSet } = buildService({ selectRows: [ROW] });
    await service.update('op_invite', { title: '新标题' });
    const patch = updateSet.mock.calls[0][0];
    expect(patch.title).toBe('新标题');
    expect(patch.subtitle).toBeUndefined();
    expect(patch.updatedAt).toEqual(expect.any(Number));
  });
});
