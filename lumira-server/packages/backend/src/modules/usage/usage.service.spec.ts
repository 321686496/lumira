// lumira-server/packages/backend/src/modules/usage/usage.service.spec.ts
import { UsageService } from './usage.service';
import { DatabaseService } from '../../database/database.service';
import type { EventInputDto } from './dto/batch-events.dto';

describe('UsageService', () => {
  const fakeEvents: EventInputDto[] = [
    { clientEventId: 'e1', itemType: 'template', itemId: 't1', itemSource: 'builtin', eventType: 'open_detail', occurredAt: 1000 },
    { clientEventId: 'e2', itemType: 'template', itemId: 't1', itemSource: 'builtin', eventType: 'use_shoot', occurredAt: 1001 },
    { clientEventId: 'e3', itemType: 'scene', itemId: 's1', itemSource: 'system', eventType: 'scene_select', occurredAt: 1002 },
  ];

  function buildService(opts: { execRows?: unknown[]; execImpl?: () => void } = {}) {
    const execute = jest.fn();
    execute.mockImplementation(opts.execImpl ?? (() => { throw new Error('use execRows'); }));
    execute.mockResolvedValueOnce(opts.execRows ? [opts.execRows] : []);
    const dbService = { getDb: jest.fn(() => ({ execute })) } as unknown as DatabaseService;
    return { service: new UsageService(dbService), execute };
  }

  it('recordBatch 返回 inserted=events.length 且逐条但未空数组时返回 0', async () => {
    const { service, execute } = buildService({
      execImpl: () => Promise.resolve([{ affectedRows: 1 }]),
    });
    const res = await service.recordBatch('device-1', fakeEvents);
    expect(res.inserted).toBe(3);
    expect(execute).toHaveBeenCalledTimes(3);

    const empty = await service.recordBatch('device-1', []);
    expect(empty.inserted).toBe(0);
  });

  it('stats 按 itemId+itemType 聚合各事件次数', async () => {
    const rows = [
      { itemId: 't1', itemType: 'template', eventType: 'open_detail', cnt: 5 },
      { itemId: 't1', itemType: 'template', eventType: 'use_shoot', cnt: 3 },
      { itemId: 's1', itemType: 'scene', eventType: 'scene_select', cnt: 2 },
    ];
    const { service } = buildService({ execRows: rows });
    const res = await service.stats();
    expect(res.items).toHaveLength(2);
    const t1 = res.items.find((i) => i.itemId === 't1');
    expect(t1).toEqual({ itemId: 't1', itemType: 'template', useShoot: 3, openDetail: 5, sceneSelect: 0 });
    const s1 = res.items.find((i) => i.itemId === 's1');
    expect(s1).toEqual({ itemId: 's1', itemType: 'scene', useShoot: 0, openDetail: 0, sceneSelect: 2 });
  });

  it('stats 支持 itemType 过滤时仍聚合正确', async () => {
    const rows = [
      { itemId: 't1', itemType: 'template', eventType: 'use_shoot', cnt: 2 },
    ];
    const { service } = buildService({ execRows: rows });
    const res = await service.stats('template');
    expect(res.items).toEqual([{ itemId: 't1', itemType: 'template', useShoot: 2, openDetail: 0, sceneSelect: 0 }]);
  });
});