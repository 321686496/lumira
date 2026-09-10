// lumira-server/packages/backend/src/modules/ai/ai-config.service.spec.ts
// ai-config.service 单测：textModel 存取 / 留空回退 / 连通测试分支
// jest.mock llm-client（visionChat + textChat），DatabaseService 手工 stub

import { ServiceUnavailableException } from '@nestjs/common';
import { AiConfigService } from './ai-config.service';
import { DatabaseService } from '../../database/database.service';
import { visionChat, textChat } from './llm-client';

jest.mock('./llm-client', () => ({
  visionChat: jest.fn(),
  textChat: jest.fn(),
}));

const visionChatMock = visionChat as jest.MockedFunction<typeof visionChat>;
const textChatMock = textChat as jest.MockedFunction<typeof textChat>;

/** DB 行夹具（列名对齐 drizzle schema camelCase 映射） */
function row(overrides: Record<string, unknown> = {}) {
  return {
    id: 1,
    provider: 'qwen',
    baseUrl: 'https://x.example',
    apiKey: 'sk-1234567890',
    visionModel: 'qwen-vl-max',
    imageModel: 'wanx2.1-t2i-turbo',
    textModel: null,
    enabled: 1,
    createdAt: 1,
    updatedAt: 1,
    ...overrides,
  };
}

/** 只读 db mock（get / getActiveConfig / test 用）：query.aiProviderConfig.findFirst 恒返回 row */
function readonlyDb(r: Record<string, unknown> | undefined) {
  return {
    getDb: () => ({ query: { aiProviderConfig: { findFirst: async () => r } } }),
  } as unknown as DatabaseService;
}

describe('AiConfigService — textModel', () => {
  beforeEach(() => {
    visionChatMock.mockReset();
    textChatMock.mockReset();
    visionChatMock.mockResolvedValue('ok');
    textChatMock.mockResolvedValue('ok');
  });

  it('get() 无 textModel 列值 → textModel 空串、effectiveTextModel 回退 visionModel', async () => {
    const service = new AiConfigService(readonlyDb(row()));
    const view = await service.get();
    expect(view.configured).toBe(true);
    if (view.configured !== true) return;
    expect(view.textModel).toBe('');
    expect(view.effectiveTextModel).toBe('qwen-vl-max');
  });

  it('get() 有 textModel 列值 → 存储值原样、effectiveTextModel 同值', async () => {
    const service = new AiConfigService(readonlyDb(row({ textModel: 'qwen-plus' })));
    const view = await service.get();
    if (view.configured !== true) throw new Error('should be configured');
    expect(view.textModel).toBe('qwen-plus');
    expect(view.effectiveTextModel).toBe('qwen-plus');
  });

  it('getActiveConfig() 未配置独立 textModel → textModel=visionModel、hasCustomTextModel=false', async () => {
    const service = new AiConfigService(readonlyDb(row()));
    const cfg = await service.getActiveConfig();
    expect(cfg.textModel).toBe('qwen-vl-max');
    expect(cfg.hasCustomTextModel).toBe(false);
  });

  it('getActiveConfig() 配置独立 textModel → 有效值 + hasCustomTextModel=true', async () => {
    const service = new AiConfigService(readonlyDb(row({ textModel: 'qwen-plus' })));
    const cfg = await service.getActiveConfig();
    expect(cfg.textModel).toBe('qwen-plus');
    expect(cfg.hasCustomTextModel).toBe(true);
  });

  it('getActiveConfig() 未启用 → 503', async () => {
    const service = new AiConfigService(readonlyDb(row({ enabled: 0 })));
    await expect(service.getActiveConfig()).rejects.toThrow(ServiceUnavailableException);
  });

  it('test() 无独立 textModel → 不调 textChat，结果无 text 字段', async () => {
    const service = new AiConfigService(readonlyDb(row()));
    const result = await service.test();
    expect(result.vision.ok).toBe(true);
    expect(textChatMock).not.toHaveBeenCalled();
    expect('text' in result && result.text).toBeFalsy();
  });

  it('test() 有独立 textModel → 调 textChat，结果含 text', async () => {
    const service = new AiConfigService(readonlyDb(row({ textModel: 'qwen-plus' })));
    const result = await service.test();
    expect(textChatMock).toHaveBeenCalledTimes(1);
    expect(result.text?.ok).toBe(true);
  });

  it('test() textChat 失败 → text.ok=false 且 vision 不受影响', async () => {
    textChatMock.mockRejectedValue(new Error('boom'));
    const service = new AiConfigService(readonlyDb(row({ textModel: 'qwen-plus' })));
    const result = await service.test();
    expect(result.vision.ok).toBe(true);
    expect(result.text?.ok).toBe(false);
    expect(result.text?.error).toBe('boom');
  });
});

describe('AiConfigService — save() textModel 语义', () => {
  /** 可写 db mock：findFirst 状态化；insert/update 后同步内存行（save 末尾 get() 重新读取） */
  function writableDb(existing: Record<string, unknown> | undefined) {
    let current = existing;
    const insertValues = jest.fn(async (v: Record<string, unknown>) => {
      current = { ...row(), ...v };
    });
    const updateWhere = jest.fn(async () => undefined);
    const updateSet = jest.fn((patch: Record<string, unknown>) => {
      current = { ...(current as Record<string, unknown>), ...patch };
      return { where: updateWhere };
    });
    return {
      service: new AiConfigService({
        getDb: () => ({
          query: { aiProviderConfig: { findFirst: async () => current } },
          insert: () => ({ values: insertValues }),
          update: () => ({ set: updateSet }),
        }),
      } as unknown as DatabaseService),
      insertValues,
      updateSet,
    };
  }

  const dto = (textModel?: string) => ({
    provider: 'qwen',
    baseUrl: 'https://x.example',
    apiKey: 'sk-1234567890',
    visionModel: 'qwen-vl-max',
    imageModel: 'wanx2.1-t2i-turbo',
    ...(textModel !== undefined ? { textModel } : {}),
    enabled: true,
  });

  it('首次保存带 textModel → insert 收到该值', async () => {
    const { service, insertValues } = writableDb(undefined);
    const view = await service.save(dto('qwen-plus'));
    expect(insertValues).toHaveBeenCalledWith(expect.objectContaining({ textModel: 'qwen-plus' }));
    expect(view.effectiveTextModel).toBe('qwen-plus');
  });

  it('更新时 textModel 空串 → 清除（update 收到 textModel: ""）', async () => {
    const { service, updateSet } = writableDb(row({ textModel: 'qwen-plus' }));
    const view = await service.save(dto(''));
    expect(updateSet).toHaveBeenCalledWith(expect.objectContaining({ textModel: '' }));
    expect(view.textModel).toBe('');
    expect(view.effectiveTextModel).toBe('qwen-vl-max');
  });

  it('更新时缺省 textModel → 同样清除为空串（不保留旧值）', async () => {
    const { service, updateSet } = writableDb(row({ textModel: 'qwen-plus' }));
    await service.save(dto());
    expect(updateSet).toHaveBeenCalledWith(expect.objectContaining({ textModel: '' }));
  });
});
