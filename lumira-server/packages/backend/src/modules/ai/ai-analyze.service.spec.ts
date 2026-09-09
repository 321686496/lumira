// lumira-server/packages/backend/src/modules/ai/ai-analyze.service.spec.ts
// ai-analyze 编排单测（Task 5）：jest.mock llm-client，DatabaseService/AiConfigService 手工 stub
// 覆盖：成功路径提示词注入与归一化返回 / 编排顺序 / mimetype 校验 400 / 超限 400 /
// 未配置 503 透传 / 模型输出经 normalize 后 warnings 透传 / 非法 JSON 400

import { BadRequestException, ServiceUnavailableException } from '@nestjs/common';
import { AiAnalyzeService } from './ai-analyze.service';
import { DatabaseService } from '../../database/database.service';
import { AiConfigService } from './ai-config.service';
import { MAX_IMAGE_BYTES, UploadFile } from '../templates/admin-templates.service';
import { visionChat } from './llm-client';

jest.mock('./llm-client', () => ({
  visionChat: jest.fn(),
}));

const visionChatMock = visionChat as jest.MockedFunction<typeof visionChat>;

/** 可 await 的 drizzle 查询链 mock：select().from().where() 链式后 resolve 出 rows */
function chainable(rows: unknown) {
  const promise = Promise.resolve(rows);
  const chain: Record<string, unknown> = {
    from: () => chain,
    where: () => chain,
    then: promise.then.bind(promise),
    catch: promise.catch.bind(promise),
  };
  return chain as never;
}

/** 分类树行（DB 行结构，含 CategoryNode 之外的字段以贴近真实返回） */
const CATEGORY_ROWS = [
  { id: 1, key: 'portrait', name: '人像', parentKey: null, level: 1, isActive: 1 },
  { id: 2, key: 'fresh_healing', name: '清新治愈', parentKey: 'portrait', level: 2, isActive: 1 },
  { id: 3, key: 'japanese', name: '日系', parentKey: 'fresh_healing', level: 3, isActive: 1 },
];

const ACTIVE_CFG = {
  provider: 'qwen',
  baseUrl: 'https://dashscope.example.com/compatible-mode/v1',
  apiKey: 'sk-test',
  visionModel: 'qwen-vl-max',
  imageModel: 'qwen-max',
};

function buildService(opts: { categoryRows?: unknown[]; cfgError?: Error } = {}) {
  const select = jest.fn(() => chainable(opts.categoryRows ?? CATEGORY_ROWS));
  const db = { select };
  const dbService = { getDb: () => db } as unknown as DatabaseService;
  const getActiveConfig = jest.fn(() => {
    if (opts.cfgError) return Promise.reject(opts.cfgError);
    return Promise.resolve(ACTIVE_CFG);
  });
  const aiConfigService = { getActiveConfig } as unknown as AiConfigService;
  return {
    service: new AiAnalyzeService(dbService, aiConfigService),
    select,
    getActiveConfig,
  };
}

function imageFile(opts: { mimetype?: string; size?: number } = {}): UploadFile {
  return {
    buffer: Buffer.alloc(opts.size ?? 4, 1),
    filename: 'a.jpg',
    mimetype: opts.mimetype ?? 'image/jpeg',
  };
}

beforeEach(() => {
  visionChatMock.mockReset();
});

describe('AiAnalyzeService', () => {
  it('成功路径：visionChat 收到分类树提示词 + base64 图 + jsonMode，返回归一化结果', async () => {
    const { service } = buildService();
    visionChatMock.mockResolvedValueOnce(JSON.stringify({
      meta: { name: '晴空田园少女人像侧拍逆光清新风格模板', category: 'portrait' },
    }));

    const image = imageFile();
    const res = await service.analyze(image);

    expect(visionChatMock).toHaveBeenCalledTimes(1);
    const [cfg, input] = visionChatMock.mock.calls[0];
    expect(cfg).toEqual(ACTIVE_CFG);
    // 系统提示词注入：分类树（按层级缩进）+ 枚举中文标签 + JSON 契约示例
    expect(input.systemPrompt).toContain('- portrait 人像');
    expect(input.systemPrompt).toContain('  - fresh_healing 清新治愈');
    expect(input.systemPrompt).toContain('日系清新'); // LUT 中文标签
    expect(input.systemPrompt).toContain('黄金比例'); // overlayType 中文标签
    expect(input.systemPrompt).toContain('晴空田园少女人像侧拍'); // 契约示例
    expect(input.userText.length).toBeGreaterThan(0);
    expect(input.imageBase64).toBe(image.buffer.toString('base64'));
    expect(input.imageMime).toBe('image/jpeg');
    expect(input.temperature).toBe(0.3);
    expect(input.jsonMode).toBe(true);
    // 返回为归一化结果（六段结构 + 默认姿势骨架）
    expect(res.draft.meta.category).toBe('portrait');
    expect(Array.isArray(res.draft.pose)).toBe(true);
    expect(res.warnings).toEqual([]);
  });

  it('编排顺序：分类查询 → 取配置 → visionChat', async () => {
    const order: string[] = [];
    const select = jest.fn(() => {
      order.push('categories');
      return chainable(CATEGORY_ROWS);
    });
    const dbService = { getDb: () => ({ select }) } as unknown as DatabaseService;
    const getActiveConfig = jest.fn(async () => {
      order.push('config');
      return ACTIVE_CFG;
    });
    const service = new AiAnalyzeService(
      dbService,
      { getActiveConfig } as unknown as AiConfigService,
    );
    visionChatMock.mockImplementationOnce(async () => {
      order.push('visionChat');
      return '{}';
    });

    await service.analyze(imageFile());

    expect(order).toEqual(['categories', 'config', 'visionChat']);
  });

  it('mimetype 非法 → 400「仅支持 jpg/png/webp 图片」，不触达分类查询 / 配置 / 模型', async () => {
    const { service, select, getActiveConfig } = buildService();

    const p = service.analyze(imageFile({ mimetype: 'text/plain' }));
    await expect(p).rejects.toBeInstanceOf(BadRequestException);
    await expect(p).rejects.toThrow('仅支持 jpg/png/webp 图片');

    expect(select).not.toHaveBeenCalled();
    expect(getActiveConfig).not.toHaveBeenCalled();
    expect(visionChatMock).not.toHaveBeenCalled();
  });

  it('图片超过 8MB → 400（assertFileSize 风格文案），不调用模型', async () => {
    const { service } = buildService();

    await expect(service.analyze(imageFile({ size: MAX_IMAGE_BYTES + 1 })))
      .rejects.toThrow('示例图不能超过 8MB');

    expect(visionChatMock).not.toHaveBeenCalled();
  });

  it('未配置/未启用（getActiveConfig 503）→ 异常透传，不调用模型', async () => {
    const { service } = buildService({
      cfgError: new ServiceUnavailableException('AI 未配置或未启用，请先在后台「AI 设置」中完成配置并启用'),
    });

    await expect(service.analyze(imageFile())).rejects.toBeInstanceOf(ServiceUnavailableException);
    expect(visionChatMock).not.toHaveBeenCalled();
  });

  it('模型输出经 normalize 后：非法枚举丢弃 + 数值夹取，warnings 透传', async () => {
    const { service } = buildService();
    visionChatMock.mockResolvedValueOnce(JSON.stringify({
      meta: {
        name: '晴空田园少女人像侧拍逆光清新风格模板',
        category: 'portrait',
        classification: { majorStyle: 'fresh_healing', style: 'japanese' },
      },
      composition: { overlayType: 'bogus_overlay', opacity: 2 },
    }));

    const res = await service.analyze(imageFile());

    const composition = res.draft.composition as Record<string, unknown>;
    expect(composition.overlayType).toBeUndefined(); // 非法枚举丢弃
    expect(composition.opacity).toBe(1); // 越界夹取
    const classification = (res.draft.meta as Record<string, unknown>).classification as Record<string, unknown>;
    expect(classification).toEqual({ type: 'portrait', majorStyle: 'fresh_healing', style: 'japanese' });
    const joined = res.warnings.join('\n');
    expect(joined).toContain('composition.overlayType');
    expect(joined).toContain('composition.opacity');
  });

  it('模型输出无法解析为 JSON → 400「模型输出无法解析为 JSON，请重试识别」', async () => {
    const { service } = buildService();
    visionChatMock.mockResolvedValueOnce('抱歉，这张图片我无法分析。');

    await expect(service.analyze(imageFile())).rejects.toThrow('模型输出无法解析为 JSON，请重试识别');
  });
});
