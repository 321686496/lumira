// lumira-server/packages/backend/src/modules/templates/templates.service.spec.ts
import { HttpException, HttpStatus } from '@nestjs/common';
import { TemplatesService } from './templates.service';
import { DatabaseService } from '../../database/database.service';
import { PointsService } from '../points/points.service';
import { RedisService } from '../../common/redis/redis.service';
import { UsageService } from '../usage/usage.service';
import type { TemplateSearchSort } from '@lumira/shared';

/** 构造一个 search base 项（Redis 物化缓存中的数据形态） */
function item(id: string, over: {
  category?: string;
  description?: string;
  tags?: string[];
  sortOrder?: number;
  updatedAt?: number;
  hotScore?: number;
  shootCount?: number;
  openCount?: number;
} = {}) {
  const name = over.category !== undefined ? id : id; // 名称即 id，便于断言
  return {
    meta: {
      id,
      name,
      author: 'Lumira',
      category: over.category ?? 'portrait',
      description: over.description ?? '',
      tags: over.tags ?? [],
      sortOrder: over.sortOrder ?? 0,
      updatedAt: over.updatedAt ?? 0,
      shortDesc: '',
      referenceSource: '',
      version: '1.0.0',
      price: 0,
      coverUrl: '',
      ambience: {},
      classification: { type: over.category ?? 'portrait', style: '', method: '' },
      tagIds: [],
    },
    base: {
      name,
      author: 'Lumira',
      category: over.category ?? 'portrait',
      description: over.description ?? '',
      tags: over.tags ?? [],
      sortOrder: over.sortOrder ?? 0,
    },
    hotScore: over.hotScore ?? 0,
    shootCount: over.shootCount ?? 0,
    openCount: over.openCount ?? 0,
  };
}

describe('TemplatesService.searchTemplates', () => {
  function buildService(base: any[], rateCount = 0) {
    const redis = {
      getJson: jest.fn(async (key: string) => {
        if (String(key).includes('templateSearch:base')) return base;
        // 限流计数：返回预设值，setJson 不持久化（不影响正常路径）
        return rateCount === 0 ? 0 : rateCount;
      }),
      setJson: jest.fn(async () => undefined),
    } as unknown as RedisService;
    const dbService = {} as unknown as DatabaseService;
    const pointsService = {} as unknown as PointsService;
    const usageService = {} as unknown as UsageService;
    const service = new TemplatesService(dbService, pointsService, redis, usageService);
    return { service, redis };
  }

  const call = (service: TemplatesService, over: {
    q?: string; sort?: TemplateSearchSort; category?: string;
    page?: number; pageSize?: number;
  } = {}) => service.searchTemplates({
    deviceId: 'dev-1',
    q: over.q ?? '',
    sort: over.sort ?? 'comprehensive',
    category: over.category,
    page: over.page ?? 1,
    pageSize: over.pageSize ?? 20,
  });

  it('按关键词多字段过滤', async () => {
    const { service } = buildService([
      item('port-1', { description: '田园少女' }),
      item('land-1', { category: 'landscape', description: '' }),
      item('port-2', { description: '爱丽丝仙境' }),
    ]);
    const res = await call(service, { q: '田园' });
    expect(res.total).toBe(1);
    expect(res.items.map((i) => i.id)).toEqual(['port-1']);
  });

  it('hot 排序使用全站热度（2×拍摄数 + 1×查看数）', async () => {
    const { service } = buildService([
      item('a', { hotScore: 7, shootCount: 3, openCount: 1, updatedAt: 5 }),
      item('b', { hotScore: 9, shootCount: 2, openCount: 5, updatedAt: 3 }),
      item('c', { hotScore: 7, shootCount: 3, openCount: 1, updatedAt: 9 }),
    ]);
    const res = await call(service, { sort: 'hot' });
    expect(res.items.map((i) => i.id)).toEqual(['b', 'c', 'a']); // 热度降序，并列按 updatedAt 降序
    expect(res.items.map((i) => i.hotScore)).toEqual([9, 7, 7]);
  });

  it('latest 排序按更新先后', async () => {
    const { service } = buildService([
      item('old', { updatedAt: 100 }),
      item('new', { updatedAt: 300 }),
      item('mid', { updatedAt: 200 }),
    ]);
    const res = await call(service, { sort: 'latest' });
    expect(res.items.map((i) => i.id)).toEqual(['new', 'mid', 'old']);
  });

  it('photos 排序按全站拍摄数，并列按名称', async () => {
    const { service } = buildService([
      item('z', { shootCount: 1 }),
      item('a', { shootCount: 9 }),
      item('b', { shootCount: 9 }),
    ]);
    const res = await call(service, { sort: 'photos' });
    expect(res.items.map((i) => i.id)).toEqual(['a', 'b', 'z']);
  });

  it('分页切片', async () => {
    const { service } = buildService([
      item('1', { updatedAt: 1 }), item('2', { updatedAt: 2 }),
      item('3', { updatedAt: 3 }), item('4', { updatedAt: 4 }),
    ]);
    const res = await call(service, { sort: 'latest', page: 2, pageSize: 2 });
    expect(res.total).toBe(4);
    expect(res.page).toBe(2);
    expect(res.items.map((i) => i.id)).toEqual(['2', '1']);
  });

  it('单设备触发限流（60 次/分钟）返回 429', async () => {
    const { service } = buildService([item('a')], 60);
    await expect(call(service, { q: 'x' })).rejects.toMatchObject({
      status: HttpStatus.TOO_MANY_REQUESTS,
    });
  });

  it('限流未满时正常返回', async () => {
    const { service } = buildService([item('a', { updatedAt: 1 })], 59);
    const res = await call(service, {});
    expect(res.total).toBe(1);
    expect(res.items.map((i) => i.id)).toEqual(['a']);
  });

  it('违规 sort 由 controller 兜底为 comprehensive（service 不做校验）', async () => {
    const { service } = buildService([item('a', { sortOrder: 1 })]);
    const res = await service.searchTemplates({
      deviceId: 'dev-1', q: '', sort: 'comprehensive' as TemplateSearchSort,
      page: 1, pageSize: 20,
    });
    expect(res.items.map((i) => i.id)).toEqual(['a']);
  });
});