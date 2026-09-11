// lumira-server/packages/backend/src/modules/ai/ai-config.service.spec.ts
// ai-config.service 单测：textModel 存取 / 留空回退 / 连通测试分支
// jest.mock llm-client（visionChat + textChat），DatabaseService 手工 stub

import { BadRequestException, ServiceUnavailableException } from '@nestjs/common';
import { AiConfigService } from './ai-config.service';
import { DatabaseService } from '../../database/database.service';
import { visionChat, textChat } from './llm-client';
import { generateImage } from './image-client';

jest.mock('./llm-client', () => ({
  visionChat: jest.fn(),
  textChat: jest.fn(),
}));
jest.mock('./image-client', () => ({
  generateImage: jest.fn(),
  mapSize: jest.fn(() => '1024*1024'),
}));

const visionChatMock = visionChat as jest.MockedFunction<typeof visionChat>;
const textChatMock = textChat as jest.MockedFunction<typeof textChat>;
const generateImageMock = generateImage as jest.MockedFunction<typeof generateImage>;

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
    textProvider: null,
    textBaseUrl: null,
    textApiKey: null,
    imageProvider: null,
    imageBaseUrl: null,
    imageApiKey: null,
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

/** 可写 db mock（save 用）：findFirst 状态化；insert/update 后同步内存行（save 末尾 get() 重新读取） */
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

describe('AiConfigService — textModel', () => {
  beforeEach(() => {
    visionChatMock.mockReset();
    textChatMock.mockReset();
    generateImageMock.mockReset();
    visionChatMock.mockResolvedValue('ok');
    textChatMock.mockResolvedValue('ok');
    generateImageMock.mockResolvedValue({ base64: 'aW1hZ2U=', mimeType: 'image/png' });
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

  it('get() textModel 仅空白 → effectiveTextModel 回退 visionModel（与 getActiveConfig 判定一致）', async () => {
    const service = new AiConfigService(readonlyDb(row({ textModel: '   ' })));
    const view = await service.get();
    if (view.configured !== true) throw new Error('should be configured');
    expect(view.textModel).toBe('   ');
    expect(view.effectiveTextModel).toBe('qwen-vl-max');
  });

  it('getActiveConfig() 无覆盖 → 三模态均用共享平台；text.model 回退 visionModel、hasCustomTextModel=false', async () => {
    const service = new AiConfigService(readonlyDb(row()));
    const cfg = await service.getActiveConfig();
    const shared = { provider: 'qwen', baseUrl: 'https://x.example', apiKey: 'sk-1234567890' };
    expect(cfg.vision).toEqual({ ...shared, model: 'qwen-vl-max' });
    expect(cfg.text).toEqual({ ...shared, model: 'qwen-vl-max' }); // 未配置 textModel → 回退 visionModel
    expect(cfg.image).toEqual({ ...shared, model: 'wanx2.1-t2i-turbo' });
    expect(cfg.hasCustomTextModel).toBe(false);
  });

  it('getActiveConfig() 有独立 textModel（无独立平台）→ text.model=存值（仍走共享平台）、hasCustomTextModel=true', async () => {
    const service = new AiConfigService(readonlyDb(row({ textModel: 'qwen-plus' })));
    const cfg = await service.getActiveConfig();
    expect(cfg.text.model).toBe('qwen-plus');
    expect(cfg.text.baseUrl).toBe('https://x.example'); // 平台仍为共享
    expect(cfg.hasCustomTextModel).toBe(true);
  });

  it('getActiveConfig() 文本独立平台启用 → text 端点用覆盖平台 + 覆盖模型，其余模态不受影响', async () => {
    const service = new AiConfigService(
      readonlyDb(
        row({ textProvider: 'openai', textBaseUrl: 'https://o.example/v1', textApiKey: 'sk-text-key', textModel: 'gpt-x' }),
      ),
    );
    const cfg = await service.getActiveConfig();
    expect(cfg.text).toEqual({ provider: 'openai', baseUrl: 'https://o.example/v1', apiKey: 'sk-text-key', model: 'gpt-x' });
    expect(cfg.vision.provider).toBe('qwen');
    expect(cfg.image.provider).toBe('qwen');
  });

  it('getActiveConfig() 生图独立平台启用 → image 端点用覆盖平台 + imageModel，其余模态不受影响', async () => {
    const service = new AiConfigService(
      readonlyDb(row({ imageProvider: 'zhipu', imageBaseUrl: 'https://z.example/v1', imageApiKey: 'sk-img-key' })),
    );
    const cfg = await service.getActiveConfig();
    expect(cfg.image).toEqual({ provider: 'zhipu', baseUrl: 'https://z.example/v1', apiKey: 'sk-img-key', model: 'wanx2.1-t2i-turbo' });
    expect(cfg.vision.provider).toBe('qwen');
    expect(cfg.text.model).toBe('qwen-vl-max'); // text 未配置 → 回退 visionModel
  });

  it('getActiveConfig() 文本独立平台 provider/baseUrl 已设但 apiKey 为 NULL → 视为未配置，回退共享平台（防御手工 SQL 缺 key）', async () => {
    const service = new AiConfigService(
      readonlyDb(row({ textProvider: 'openai', textBaseUrl: 'https://o.example/v1', textApiKey: null, textModel: 'gpt-x' })),
    );
    const cfg = await service.getActiveConfig();
    expect(cfg.text).toEqual({ provider: 'qwen', baseUrl: 'https://x.example', apiKey: 'sk-1234567890', model: 'gpt-x' });
  });

  it('getActiveConfig() 生图独立平台缺 apiKey → 视为未配置，回退共享平台', async () => {
    const service = new AiConfigService(
      readonlyDb(row({ imageProvider: 'zhipu', imageBaseUrl: 'https://z.example/v1', imageApiKey: '' })),
    );
    const cfg = await service.getActiveConfig();
    expect(cfg.image).toEqual({ provider: 'qwen', baseUrl: 'https://x.example', apiKey: 'sk-1234567890', model: 'wanx2.1-t2i-turbo' });
  });

  it('getActiveConfig() 未启用 → 503', async () => {
    const service = new AiConfigService(readonlyDb(row({ enabled: 0 })));
    await expect(service.getActiveConfig()).rejects.toThrow(ServiceUnavailableException);
  });

  it('test() 默认测试全部目标，文本回退视觉模型，剪影回退生图端点', async () => {
    const service = new AiConfigService(readonlyDb(row()));
    const result = await service.test();
    expect(result.vision.ok).toBe(true);
    expect(result.text?.ok).toBe(true);
    expect(result.image?.ok).toBe(true);
    expect(result.silhouette?.ok).toBe(true);
    expect(visionChatMock.mock.calls[0][0]).toEqual({
      provider: 'qwen',
      baseUrl: 'https://x.example',
      apiKey: 'sk-1234567890',
      model: 'qwen-vl-max',
    });
    expect(textChatMock.mock.calls[0][0]).toEqual({
      provider: 'qwen',
      baseUrl: 'https://x.example',
      apiKey: 'sk-1234567890',
      model: 'qwen-vl-max',
    });
    expect(generateImageMock).toHaveBeenCalledTimes(2);
    expect(generateImageMock.mock.calls[0][0]).toEqual({
      provider: 'qwen',
      baseUrl: 'https://x.example',
      apiKey: 'sk-1234567890',
      model: 'wanx2.1-t2i-turbo',
    });
    expect(generateImageMock.mock.calls[0][1]).toMatchObject({ prompt: 'connectivity test', size: '1024*1024' });
    expect(generateImageMock.mock.calls[0][2]).toEqual({ requestTimeoutMs: 30_000 });
    expect(generateImageMock.mock.calls[1][0]).toMatchObject({ model: 'wanx2.1-t2i-turbo' });
  });

  it('test() 指定子集 → 只执行所选目标', async () => {
    const service = new AiConfigService(readonlyDb(row({ silhouetteModel: 'sil-x' })));
    const result = await service.test(['silhouette']);
    expect(visionChatMock).not.toHaveBeenCalled();
    expect(textChatMock).not.toHaveBeenCalled();
    expect(generateImageMock).toHaveBeenCalledTimes(1);
    expect(generateImageMock.mock.calls[0][0]).toMatchObject({ model: 'sil-x' });
    expect(Object.keys(result).filter((key) => key !== 'note')).toEqual(['silhouette']);
  });

  it.each([
    ['空数组', []],
    ['未知目标', ['vision', 'video'] as never],
    ['重复目标', ['vision', 'vision'] as never],
  ])('test() %s → 400', async (_name, targets) => {
    const service = new AiConfigService(readonlyDb(row()));
    await expect(service.test(targets)).rejects.toThrow(BadRequestException);
  });

  it('test() 有独立 textModel → 调 textChat（收到 text 端点），结果含 text', async () => {
    const service = new AiConfigService(readonlyDb(row({ textModel: 'qwen-plus' })));
    const result = await service.test();
    expect(textChatMock).toHaveBeenCalledTimes(1);
    expect(textChatMock.mock.calls[0][0]).toEqual({
      provider: 'qwen',
      baseUrl: 'https://x.example',
      apiKey: 'sk-1234567890',
      model: 'qwen-plus',
    });
    expect(result.text?.ok).toBe(true);
  });

  it('test() 视觉测试图边长 >10px（部分厂商拒绝 1×1 图，回归防护）', async () => {
    const service = new AiConfigService(readonlyDb(row()));
    await service.test();
    expect(visionChatMock).toHaveBeenCalledTimes(1);
    const imgArg = visionChatMock.mock.calls[0][1] as { imageBase64: string };
    const buf = Buffer.from(imgArg.imageBase64, 'base64');
    // PNG 签名 + IHDR：宽高位于字节 16-23（大端 uint32）
    expect(buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))).toBe(true);
    expect(buf.readUInt32BE(16)).toBeGreaterThan(10);
    expect(buf.readUInt32BE(20)).toBeGreaterThan(10);
  });

  it('test() textChat 失败 → text.ok=false 且 vision 不受影响', async () => {
    textChatMock.mockRejectedValue(new Error('boom'));
    const service = new AiConfigService(readonlyDb(row({ textModel: 'qwen-plus' })));
    const result = await service.test();
    expect(result.vision.ok).toBe(true);
    expect(result.text?.ok).toBe(false);
    expect(result.text?.error).toBe('boom');
  });

  it('test() 生图失败 → image.ok=false 且其他目标不受影响', async () => {
    generateImageMock.mockRejectedValueOnce(new Error('image boom'));
    const service = new AiConfigService(readonlyDb(row()));
    const result = await service.test();
    expect(result.vision.ok).toBe(true);
    expect(result.text?.ok).toBe(true);
    expect(result.image?.ok).toBe(false);
    expect(result.image?.error).toBe('image boom');
    expect(result.silhouette?.ok).toBe(true);
  });
});

describe('AiConfigService — save() textModel 语义', () => {
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

describe('AiConfigService — 模态独立平台（text/image override）', () => {
  const dto = (overrides: Record<string, unknown> = {}) => ({
    provider: 'qwen',
    baseUrl: 'https://x.example',
    apiKey: 'sk-1234567890',
    visionModel: 'qwen-vl-max',
    imageModel: 'wanx2.1-t2i-turbo',
    enabled: true,
    ...overrides,
  });

  it('save() 更新带 textProvider 组 → update set 收到覆盖组三列', async () => {
    const { service, updateSet } = writableDb(row());
    await service.save(
      dto({ textProvider: 'openai', textBaseUrl: 'https://o.example/v1', textApiKey: 'sk-text-key', textModel: 'gpt-x' }),
    );
    expect(updateSet).toHaveBeenCalledWith(
      expect.objectContaining({
        textProvider: 'openai',
        textBaseUrl: 'https://o.example/v1',
        textApiKey: 'sk-text-key',
      }),
    );
  });

  it('save() 首次保存带 textProvider 组 → insert values 收到覆盖组三列', async () => {
    const { service, insertValues } = writableDb(undefined);
    await service.save(
      dto({ textProvider: 'openai', textBaseUrl: 'https://o.example/v1', textApiKey: 'sk-text-key', textModel: 'gpt-x' }),
    );
    expect(insertValues).toHaveBeenCalledWith(
      expect.objectContaining({
        textProvider: 'openai',
        textBaseUrl: 'https://o.example/v1',
        textApiKey: 'sk-text-key',
      }),
    );
  });

  it('save() textProvider 但 textBaseUrl 空 → 400 文本独立平台必须填写 baseUrl', async () => {
    const { service } = writableDb(row());
    await expect(
      service.save(dto({ textProvider: 'openai', textBaseUrl: '', textApiKey: 'sk-text-key', textModel: 'gpt-x' })),
    ).rejects.toThrow('文本独立平台必须填写 baseUrl');
  });

  it('save() textProvider 但 textModel 空 → 400（独立平台无法回退视觉模型）', async () => {
    const { service } = writableDb(row());
    await expect(
      service.save(dto({ textProvider: 'openai', textBaseUrl: 'https://o.example/v1', textApiKey: 'sk-text-key' })),
    ).rejects.toThrow('文本使用独立平台时必须填写文本模型（无法回退视觉模型）');
  });

  it('save() textProvider 无存量覆盖 key 且未传 textApiKey → 400 首次配置独立平台必须填写 API Key', async () => {
    const { service } = writableDb(row()); // row() 默认 textApiKey: null
    await expect(
      service.save(dto({ textProvider: 'openai', textBaseUrl: 'https://o.example/v1', textModel: 'gpt-x' })),
    ).rejects.toThrow('首次配置独立平台必须填写 API Key');
  });

  it('save() textProvider 传空 textApiKey 但存量有 → 保留存量值', async () => {
    const { service, updateSet } = writableDb(row({ textApiKey: 'sk-stored' }));
    await service.save(
      dto({ textProvider: 'openai', textBaseUrl: 'https://o.example/v1', textApiKey: '', textModel: 'gpt-x' }),
    );
    expect(updateSet).toHaveBeenCalledWith(expect.objectContaining({ textApiKey: 'sk-stored' }));
  });

  it('save() 不带 textProvider 但存量有覆盖 → update set 收到三列 null（显式清除）', async () => {
    const { service, updateSet } = writableDb(
      row({ textProvider: 'openai', textBaseUrl: 'https://o.example/v1', textApiKey: 'sk-stored' }),
    );
    await service.save(dto());
    expect(updateSet).toHaveBeenCalledWith(
      expect.objectContaining({ textProvider: null, textBaseUrl: null, textApiKey: null }),
    );
  });

  it('get() 行含 textProvider+textBaseUrl → textPlatform 返回组（apiKey 脱敏）、imagePlatform 为 null', async () => {
    const service = new AiConfigService(
      readonlyDb(row({ textProvider: 'openai', textBaseUrl: 'https://o.example/v1', textApiKey: 'sk-text-key-123456' })),
    );
    const view = await service.get();
    if (view.configured !== true) throw new Error('should be configured');
    expect(view.textPlatform).toEqual({
      provider: 'openai',
      baseUrl: 'https://o.example/v1',
      apiKeyMasked: 'sk-****56',
    });
    expect(view.imagePlatform).toBe(null);
  });

  it('get() 行无覆盖 → textPlatform / imagePlatform 均为 null', async () => {
    const service = new AiConfigService(readonlyDb(row()));
    const view = await service.get();
    if (view.configured !== true) throw new Error('should be configured');
    expect(view.textPlatform).toBe(null);
    expect(view.imagePlatform).toBe(null);
  });

  it('image 组：保存带 imageProvider 组 → 收到三列；再保存不带 → 清除为 null', async () => {
    const { service, updateSet } = writableDb(row());
    await service.save(dto({ imageProvider: 'zhipu', imageBaseUrl: 'https://z.example/v1', imageApiKey: 'sk-img-key' }));
    expect(updateSet).toHaveBeenCalledWith(
      expect.objectContaining({
        imageProvider: 'zhipu',
        imageBaseUrl: 'https://z.example/v1',
        imageApiKey: 'sk-img-key',
      }),
    );
    await service.save(dto());
    expect(updateSet).toHaveBeenLastCalledWith(
      expect.objectContaining({ imageProvider: null, imageBaseUrl: null, imageApiKey: null }),
    );
  });
});
