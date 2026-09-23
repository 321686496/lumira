// lumira-server/packages/backend/src/modules/ai/golden-set.service.spec.ts
// Task 11 Golden Set 回归门禁 + Trend Index 新鲜度衰减 + 失败案例库（TDD）：
// - getFreshTrend：7 天内命中 → 返回条目；过期/miss → 触发增量（mock onMiss）返回空
// - upsertTrend：同 topic×source×trend_date 已存在 → 更新（inserted=false）；否则插入（inserted=true）
// - registerFailCase：写库返回新行 id
// - GoldenSetService.run：遍历 GOLDEN_SET 用例，逐一跑 orchestrator + imageScore 汇总

import { GoldenSetService, getFreshTrend, upsertTrend, registerFailCase } from './golden-set.service';
import type { AiOrchestratorService } from './ai-orchestrator.service';
import type { ImageScoreService } from './image-score.service';
import type { ImageDescription } from './image-describe.service';
import type { PoseRefSheet } from './pose-ref-sheet.service';
import { GOLDEN_SET } from './golden-set.data';
import type { MySql2Database } from 'drizzle-orm/mysql2';
import * as schema from '../../database/schema';

const DESC: ImageDescription = {
  global: {
    subject: '年轻女性，坐姿望向窗外', mood: '清冷', season: '秋', timeOfDay: 'goldenHour',
    palette: { dominant: ['#d2b48c'], tone: '暖', brightness: '中间调偏亮' }, light: {},
    composition: { leadLines: '', framing: '', symmetry: '', subjectFrame: {}, cropRatio: '3:4', negativeSpace: '', depthOfField: '' },
    reproducibility: { level: 'high', reason: '', enableFillLight: true, lightHint: '' },
  },
  people: [],
  scene: { location: '飘窗', depthLayers: { near: [], middle: [], far: [] }, props: [], furniture: [], texture: '', cleanliness: '' },
  cameraLike: { lightSuggestion: '', wbSuggestion: '', evSuggestion: '', focusDepth: '' },
};

const POSE_SHEET: PoseRefSheet = {
  shared: { outfit: '米色针织', scene: '飘窗', light: '窗光', aspectRatio: '3:4', mood: '清冷', palette: '暖棕' },
  perPose: [{ name: '坐姿侧靠', subjectPose: {}, camera: {}, frame: {}, lightOnPose: {}, differentiationNote: '侧靠偏左' }],
};

/** 可配置的 db mock：selectRows 决定 select 命中结果；insert 返回 insertId */
function fakeDb(selectRows: unknown[] = []) {
  const select = jest.fn(() => ({
    from: jest.fn(() => ({
      where: jest.fn(() => ({
        orderBy: jest.fn(() => ({ limit: jest.fn().mockResolvedValue(selectRows) })),
        limit: jest.fn().mockResolvedValue(selectRows),
      })),
      limit: jest.fn().mockResolvedValue(selectRows),
    })),
  }));
  const insert = jest.fn(() => ({ values: jest.fn().mockResolvedValue([{ insertId: 7 }]) }));
  const update = jest.fn(() => ({ set: jest.fn(() => ({ where: jest.fn().mockResolvedValue([{}]) })) }));
  return { select, insert, update };
}

const TrendRow = (over: Partial<Record<string, unknown>> = {}) => ({
  id: 1,
  topic: '秋季清冷感',
  source: 'bing',
  trendDate: new Date().toISOString().slice(0, 10),
  title: '秋日清冷感趋势',
  snippet: '低饱和莫兰迪色系流行',
  keywordsJson: JSON.stringify(['秋', '清冷', '莫兰迪']),
  imgUrl: null,
  url: 'https://x/y',
  popularity: 0.8,
  createdAt: 0,
  updatedAt: 0,
  ...over,
});

describe('getFreshTrend', () => {
  it('7 天内命中 → 返回条目，不触发增量回调', async () => {
    const rows = [TrendRow()];
    const db = fakeDb(rows) as unknown as MySql2Database<typeof schema>;
    const onMiss = jest.fn();

    const res = await getFreshTrend(db, '秋季清冷感', { onMiss });

    expect(res).toHaveLength(1);
    expect(res[0].title).toBe('秋日清冷感趋势');
    expect(res[0].keywords).toEqual(['秋', '清冷', '莫兰迪']);
    expect(onMiss).not.toHaveBeenCalled();
  });

  it('miss（无新鲜条目）→ 触发增量回调并返回空', async () => {
    const db = fakeDb([]) as unknown as MySql2Database<typeof schema>;
    const onMiss = jest.fn().mockResolvedValue(undefined);

    const res = await getFreshTrend(db, '不存在的话题', { onMiss });

    expect(res).toEqual([]);
    expect(onMiss).toHaveBeenCalledTimes(1);
  });
});

describe('upsertTrend', () => {
  it('同 topic×source×trendDate 已存在 → 走 update，返回 inserted=false', async () => {
    const db = fakeDb([TrendRow()]) as unknown as MySql2Database<typeof schema>;
    const res = await upsertTrend(db, { topic: '秋季清冷感', source: 'bing', trendDate: '2026-09-21', title: '更新标题' });
    expect(res.inserted).toBe(false);
  });

  it('不存在 → insert，返回 inserted=true', async () => {
    const db = fakeDb([]) as unknown as MySql2Database<typeof schema>;
    const res = await upsertTrend(db, { topic: '新话题', source: 'bing', trendDate: '2026-09-21', title: '标题' });
    expect(res.inserted).toBe(true);
  });
});

describe('registerFailCase', () => {
  it('写库并返回新行 id', async () => {
    const db = fakeDb() as unknown as MySql2Database<typeof schema>;
    const id = await registerFailCase(db, [{ step: 'score', resultBrief: '0.6' }], ['姿势不一致'], { templateId: 'tpl-1' });
    expect(id).toBeGreaterThan(0);
  });
});

describe('GoldenSetService.run', () => {
  it('遍历 GOLDEN_SET 用例，逐一跑 orchestrator + imageScore 并汇总 pass/score/reasons', async () => {
    const orchestrator = {
      run: jest.fn().mockResolvedValue({
        draft: { meta: { name: '秋日清冷感模板' } },
        warnings: [],
        trace: [{ step: 'imageScore', resultBrief: 'ok', score: 0.9 }],
      }),
    } as unknown as AiOrchestratorService;
    const imageScore = {
      score: jest.fn().mockResolvedValue({ score: 0.91, verdict: 'pass', reasons: ['风格成熟'], suggests: [] }),
    } as unknown as ImageScoreService;
    const db = fakeDb() as unknown as MySql2Database<typeof schema>;
    const svc = new GoldenSetService(db, orchestrator, imageScore);

    const results = await svc.run();

    expect(results.length).toBe(GOLDEN_SET.length);
    expect(orchestrator.run).toHaveBeenCalledTimes(GOLDEN_SET.length);
    expect(imageScore.score).toHaveBeenCalledTimes(GOLDEN_SET.length);
    for (const r of results) {
      expect(r).toHaveProperty('id');
      expect(typeof r.pass).toBe('boolean');
      expect(typeof r.score).toBe('number');
      expect(Array.isArray(r.reasons)).toBe(true);
    }
  });
});