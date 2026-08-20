// lumira-server/packages/backend/src/modules/scenes/scenes.service.spec.ts
import { ConflictException, NotFoundException } from '@nestjs/common';
import { ScenesService } from './scenes.service';
import { DatabaseService } from '../../database/database.service';
import { UsageService } from '../usage/usage.service';

/** insert/update 的 camelCase 字段名 -> 对应 DB snake_case 列名（select 结果按 DB 列名返回） */
const DB_KEY_MAP: Record<string, string> = {
  filterJson: 'filter_json',
  tipsJson: 'tips_json',
  exampleImagesJson: 'example_images_json',
  whereToShoot: 'where_to_shoot',
  bestTime: 'best_time',
  relatedCategory: 'related_category',
  recommendedTagIdsJson: 'recommended_tag_ids_json',
  sortOrder: 'sort_order',
  isActive: 'is_active',
  createdAt: 'created_at',
  updatedAt: 'updated_at',
};

function toDbKeys(v: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, val] of Object.entries(v)) {
    out[DB_KEY_MAP[k] ?? k] = val;
  }
  return out;
}

/**
 * 从 drizzle 的 `sql` where 节点提取列名与比较值。
 * queryChunks 结构（probe 实测）：
 *   - StringChunk（.value 为 string[]）：模板文本，如 ''、' = '、' = 1'
 *   - Column（.name/.table）：被比较的列，name 即 DB 列名，如 'is_active'、'id'
 *   - 原始 string chunk：作为比较值直接插入，如 id 查询的 'abc123'
 */
function buildWhere(node: unknown): (row: Record<string, unknown>) => boolean {
  const chunks: any[] = (node as any)?.queryChunks ?? [];
  let colName: string | null = null;
  let value: unknown;
  let valueSet = false;
  let text = '';
  for (const c of chunks) {
    if (typeof c === 'string') {
      if (!valueSet) { value = c; valueSet = true; }
      continue;
    }
    if (c && typeof c === 'object') {
      if (Array.isArray(c.value) && typeof c.value[0] === 'string') {
        text += c.value.join(''); // StringChunk 文本
        continue;
      }
      if (typeof c.name === 'string' && c.table) {
        colName = c.name; // Column
        continue;
      }
      if ('value' in c) { value = c.value; valueSet = true; continue; }
    }
  }
  // 如 listActive 的 `is_active = 1`：无原始 string 值，从文本解析数字
  if (!valueSet && /=\s*-?\d+/.test(text)) {
    const m = text.match(/=\s*(-?\d+)/);
    if (m) { value = Number(m[1]); valueSet = true; }
  }
  const col = colName;
  return (row) => (col !== null && valueSet ? row[col] === value : true);
}

/** 内存版假 DB：模拟 select/insert/update/delete 的可链式查询；rows 以 DB 列名存储 */
function createFakeDb(seed: Array<Record<string, unknown>>) {
  const rows = new Map<string, Record<string, unknown>>();
  for (const r of seed) rows.set(String(r.id), { ...r });

  const collectRows = (where?: unknown) => {
    const list = [...rows.values()];
    return where ? list.filter(buildWhere(where)) : list;
  };

  const makeQuery = () => {
    const state: { where?: unknown; order?: boolean; limit?: number } = { order: false };
    const q: any = {
      from: () => q,
      where: (w: unknown) => { state.where = w; return q; },
      orderBy: () => { state.order = true; return q; },
      limit: (n: number) => { state.limit = n; return q; },
      then(onF: any, onR: any) {
        let list = collectRows(state.where);
        if (state.order) list = [...list].sort((a, b) => Number(a.sort_order ?? 0) - Number(b.sort_order ?? 0));
        if (state.limit != null) list = list.slice(0, state.limit);
        return Promise.resolve(list).then(onF, onR);
      },
    };
    return q;
  };

  const db: any = {
    select: () => makeQuery(),
    insert: () => ({
      values: (v: Record<string, unknown>) => { rows.set(String(v.id), toDbKeys(v)); },
    }),
    update: () => ({
      set: (p: Record<string, unknown>) => ({
        where: (w: unknown) => { for (const r of collectRows(w)) Object.assign(r, toDbKeys(p)); },
      }),
    }),
    delete: () => ({
      where: (w: unknown) => { for (const r of collectRows(w)) rows.delete(String(r.id)); },
    }),
  };
  return { db, rows };
}

describe('ScenesService', () => {
  function buildService(seed: Array<Record<string, unknown>>, statsItems: any[] = []) {
    const fake = createFakeDb(seed);
    const dbService = { getDb: jest.fn(() => fake.db) } as unknown as DatabaseService;
    const usageService = {
      stats: jest.fn().mockResolvedValue({ items: statsItems }),
    } as unknown as UsageService;
    return { service: new ScenesService(dbService, usageService), fake, usageService };
  }

  const activeScene = (id: string, over: Record<string, unknown> = {}) => ({
    id,
    name: `${id}-名`,
    category: 'light',
    style: '',
    icon: '',
    vibe: '',
    description: '',
    filter_json: '{"brightness":80}',
    tips_json: '["t1"]',
    example_images_json: '[]',
    where_to_shoot: '海边',
    best_time: '清晨',
    related_category: '',
    recommended_tag_ids_json: '["r1"]',
    sort_order: 1,
    is_active: 1,
    updated_at: 100,
    ...over,
  });

  it('listActive 只返回启用场景，并按 usage.stats 合并次数、缺省为 0', async () => {
    const seed = [
      activeScene('s1'),
      activeScene('s2', { is_active: 0 }),
      activeScene('s3'),
    ];
    const { service, usageService } = buildService(seed, [
      { itemId: 's1', itemType: 'scene', useShoot: 3, openDetail: 2, sceneSelect: 1 },
    ]);
    const res = await service.listActive();
    expect(res.scenes).toHaveLength(2);
    expect(res.scenes.map((s) => s.id).sort()).toEqual(['s1', 's3']);
    const s1 = res.scenes.find((s) => s.id === 's1')!;
    expect(s1.usage).toEqual({ useShoot: 3, openDetail: 2, sceneSelect: 1 });
    expect(s1.filter).toEqual({ brightness: 80 });
    expect(s1.tips).toEqual(['t1']);
    const s3 = res.scenes.find((s) => s.id === 's3')!;
    expect(s3.usage).toEqual({ useShoot: 0, openDetail: 0, sceneSelect: 0 });
  });

  it('create 创建成功；重复 id 抛 ConflictException', async () => {
    const { service } = buildService([activeScene('s1')]);
    const created = await service.create({
      id: 's2', name: '夜晚', category: 'mood', filter: { dark: true },
    });
    expect(created.id).toBe('s2');
    expect(created.isActive).toBe(true);
    expect(created.filter).toEqual({ dark: true });

    await expect(service.create({ id: 's1', name: 'x', category: 'mood' }))
      .rejects.toThrow(ConflictException);
  });

  it('update 修改字段并刷新 updatedAt；不存在抛 NotFoundException', async () => {
    const { service } = buildService([activeScene('s1')]);
    const updated = await service.update('s1', { name: '新名', filter: { x: 2 } });
    expect(updated.name).toBe('新名');
    expect(updated.filter).toEqual({ x: 2 });
    expect(updated.updatedAt).toBeGreaterThanOrEqual(100);

    await expect(service.update('nope', { name: 'x' })).rejects.toThrow(NotFoundException);
  });

  it('remove 删除成功；不存在抛 NotFoundException', async () => {
    const { service } = buildService([activeScene('s1')]);
    expect(await service.remove('s1')).toEqual({ success: true });
    const after = await service.listAdmin();
    expect(after.scenes).toHaveLength(0);

    await expect(service.remove('s1')).rejects.toThrow(NotFoundException);
  });

  it('toggleActive 切换启用/停用', async () => {
    const { service } = buildService([activeScene('s1')]);
    const off = await service.toggleActive('s1');
    expect(off).toEqual({ id: 's1', isActive: false });
    const on = await service.toggleActive('s1');
    expect(on).toEqual({ id: 's1', isActive: true });
  });
});