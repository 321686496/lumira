// lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.spec.ts
// 生图编排单测（Task 7）：jest.mock image-client（generateImage mock，mapSize 保留真实），
// AiConfigService 手工 stub（同 ai-analyze.service.spec.ts 模式）。
// 覆盖：成功路径 prompt/size/参考图透传 / 未配置 503 / meta 非法 JSON 400 /
// meta 非对象 400 / meta 缺省空草稿兜底 / 无参考图字段缺省 / 结果透传。

import { BadRequestException, ServiceUnavailableException } from '@nestjs/common';
import { AiGenerateImageService } from './ai-generate-image.service';
import { AiConfigService } from './ai-config.service';
import { generateImage } from './image-client';
import { buildImagePrompt } from './image-prompt.builder';
import { UploadFile } from '../templates/admin-templates.service';

// generateImage mock（网络层）；mapSize / buildImagePrompt 纯函数保留真实实现
jest.mock('./image-client', () => {
  const actual = jest.requireActual('./image-client');
  return { ...actual, generateImage: jest.fn() };
});

const generateImageMock = generateImage as jest.MockedFunction<typeof generateImage>;

const ACTIVE_CFG = {
  provider: 'doubao',
  baseUrl: 'https://ark.example.com/api/v3',
  apiKey: 'sk-test',
  visionModel: 'doubao-vision',
  imageModel: 'doubao-seedream',
};

/** 完整草稿（Task 5 归一化结构：顶层 meta/composition/sceneGuide） */
const DRAFT = {
  meta: { category: 'portrait', shortDesc: '温柔', tags: ['日系', '清新'] },
  composition: { aspectRatio: '3:4' },
  sceneGuide: { lightDirection: '逆光', bestTime: '午后4-6点' },
};

function buildService(opts: { cfgError?: Error } = {}) {
  const getActiveConfig = jest.fn(() => {
    if (opts.cfgError) return Promise.reject(opts.cfgError);
    return Promise.resolve(ACTIVE_CFG);
  });
  const aiConfigService = { getActiveConfig } as unknown as AiConfigService;
  return { service: new AiGenerateImageService(aiConfigService), getActiveConfig };
}

function referenceFile(): UploadFile {
  return { buffer: Buffer.from('ref-bytes'), filename: 'ref.jpg', mimetype: 'image/jpeg' };
}

beforeEach(() => {
  generateImageMock.mockReset();
});

describe('AiGenerateImageService', () => {
  it('成功路径：prompt=buildImagePrompt(草稿)、size=mapSize(provider,ratio)、参考图 base64/mime 透传、结果透传', async () => {
    const { service } = buildService();
    generateImageMock.mockResolvedValueOnce({ base64: 'aGVsbG8=', mimeType: 'image/png' });

    const res = await service.generate(referenceFile(), JSON.stringify(DRAFT));

    expect(generateImageMock).toHaveBeenCalledTimes(1);
    const [cfg, input] = generateImageMock.mock.calls[0];
    expect(cfg).toEqual(ACTIVE_CFG);
    expect(input.prompt).toBe(buildImagePrompt(DRAFT)); // 真实函数生成的期望值
    expect(input.size).toBe('864x1152'); // mapSize('doubao', '3:4')
    expect(input.referenceBase64).toBe(Buffer.from('ref-bytes').toString('base64'));
    expect(input.referenceMime).toBe('image/jpeg');
    expect(res).toEqual({ base64: 'aGVsbG8=', mimeType: 'image/png' });
  });

  it('无参考图 → referenceBase64/referenceMime 为 undefined', async () => {
    const { service } = buildService();
    generateImageMock.mockResolvedValueOnce({ base64: 'aGVsbG8=', mimeType: 'image/png' });

    await service.generate(undefined, JSON.stringify(DRAFT));

    const input = generateImageMock.mock.calls[0][1];
    expect(input.referenceBase64).toBeUndefined();
    expect(input.referenceMime).toBeUndefined();
  });

  it('metaJson 为 null → 空草稿兜底：prompt 为兜底文案、size 兜底 1:1', async () => {
    const { service } = buildService();
    generateImageMock.mockResolvedValueOnce({ base64: 'aGVsbG8=', mimeType: 'image/png' });

    await service.generate(undefined, null);

    const input = generateImageMock.mock.calls[0][1];
    expect(input.prompt).toBe(buildImagePrompt({})); // 空草稿兜底 prompt
    expect(input.size).toBe('1024x1024'); // mapSize('doubao', undefined)
  });

  it('meta 非法 JSON → 400，不调用生图客户端', async () => {
    const { service, getActiveConfig } = buildService();

    await expect(service.generate(undefined, '{not valid json')).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.generate(undefined, '{not valid json')).rejects.toThrow('meta');

    expect(getActiveConfig).toHaveBeenCalledTimes(2); // 配置读取在 meta 解析之前
    expect(generateImageMock).not.toHaveBeenCalled();
  });

  it('meta JSON 解析结果非对象（如数字）→ 400', async () => {
    const { service } = buildService();

    await expect(service.generate(undefined, '123')).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.generate(undefined, '"text"')).rejects.toThrow('meta');

    expect(generateImageMock).not.toHaveBeenCalled();
  });

  it('未配置/未启用（getActiveConfig 503）→ 异常透传，不调用生图客户端', async () => {
    const { service } = buildService({
      cfgError: new ServiceUnavailableException('AI 未配置或未启用，请先在后台「AI 设置」中完成配置并启用'),
    });

    await expect(service.generate(referenceFile(), JSON.stringify(DRAFT)))
      .rejects.toBeInstanceOf(ServiceUnavailableException);
    expect(generateImageMock).not.toHaveBeenCalled();
  });
});
