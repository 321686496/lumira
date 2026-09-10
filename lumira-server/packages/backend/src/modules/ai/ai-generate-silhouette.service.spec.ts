// lumira-server/packages/backend/src/modules/ai/ai-generate-silhouette.service.spec.ts
// 剪影编排单测（Task 9 + Phase 2 增强）：
// jest.mock silhouette.pipeline（generateSilhouettePng mock，computeAlphaBbox 保持真实）与
// image-client（generateImage mock，mapSize 保持真实）、sharp（链式 Proxy 桩按输入分派）。
// 覆盖：engine='local' 缺省/显式兼容（不触达 AI 配置）/ engine='ai' 分支（剪影模型 + 参考图 +
// 阈值二值化 + 可选裁剪）/ engine 非法 400 / 非法 mimetype 400 / 超 8MB 400 /
// meta 非法 JSON 400 / mode 非法 400。
// e2e（含模型缺失 503 分支）由 CI 的 MySQL + 无模型环境验证。

import { BadRequestException } from '@nestjs/common';
import { AiSilhouetteService } from './ai-generate-silhouette.service';
import { AiConfigService } from './ai-config.service';
import { generateSilhouettePng } from './silhouette.pipeline';
import { generateImage } from './image-client';
import { UploadFile } from '../templates/admin-templates.service';
import sharp from 'sharp';

// 本地流水线 mock：只替换 generateSilhouettePng，computeAlphaBbox 等 保持真实实现
jest.mock('./silhouette.pipeline', () => {
  const actual = jest.requireActual('./silhouette.pipeline');
  return { ...actual, generateSilhouettePng: jest.fn() };
});

// 生图客户端 mock：只替换 generateImage，mapSize 保持真实实现
jest.mock('./image-client', () => {
  const actual = jest.requireActual('./image-client');
  return { ...actual, generateImage: jest.fn() };
});

// sharp mock：默认抛错（各 AI 用例自行 mockImplementation 分派），本地路径不触达
jest.mock('sharp', () => ({ __esModule: true, default: jest.fn() }));

const generateSilhouettePngMock = generateSilhouettePng as jest.MockedFunction<typeof generateSilhouettePng>;
const generateImageMock = generateImage as jest.MockedFunction<typeof generateImage>;
const sharpMock = sharp as unknown as jest.Mock;

function image(overrides: Partial<UploadFile> = {}): UploadFile {
  return {
    buffer: Buffer.from('fake-jpeg-bytes'),
    filename: 'a.jpg',
    mimetype: 'image/jpeg',
    ...overrides,
  };
}

/** getActiveConfig 透传桩：返回指定活跃配置（按模态分组 + 专用剪影模型） */
const IMAGE_ENDPOINT = {
  provider: 'qwen',
  baseUrl: 'https://dashscope.example.com/compatible-mode/v1',
  apiKey: 'sk-test',
  model: 'wanx2.1-t2i-turbo',
};
const ACTIVE_CFG = {
  vision: { ...IMAGE_ENDPOINT, model: 'qwen-vl-max' },
  text: { ...IMAGE_ENDPOINT, model: 'qwen-plus' },
  image: IMAGE_ENDPOINT,
  silhouetteModel: 'wanx-sil-special',
  hasCustomTextModel: true,
};

function cfgService(): AiConfigService {
  return { getActiveConfig: jest.fn(async () => ACTIVE_CFG) } as unknown as AiConfigService;
}

/** 链式 sharp 调用桩：未指定的方法返回 proxy 自身（链式），指定方法返回给定值 */
function sharpChain(methods: Record<string, () => unknown>): Record<string, unknown> {
  const chain: Record<string, unknown> = {};
  const proxy = new Proxy(chain, {
    get(_t, prop: string) {
      if (prop === 'then' || prop === 'catch' || prop === 'finally') return undefined;
      if (Object.prototype.hasOwnProperty.call(methods, prop)) return methods[prop];
      return () => proxy;
    },
  });
  return proxy;
}

/**
 * AI 引擎分支的 sharp 分派桩：
 * - 源图 buffer → metadata()（800x600 jpeg → 最近似比例 4:3）
 * - AI 生成图 buffer → toBuffer({resolveWithObject})（2x1 灰度：像素0 黑 / 像素1 白）
 * - {raw:{}} 构造调用 → outPng
 * - 其余 buffer（裁剪 extract 输入）→ croppedPng
 */
function setupSharpForAi(outPng: Buffer, croppedPng: Buffer) {
  const srcBuf = Buffer.from('fake-jpeg-bytes');
  const aiBuf = Buffer.from('ai-gen-raw');
  const grayData = Buffer.from([0x00, 0xff]);
  sharpMock.mockImplementation((input: unknown, opts?: { raw?: unknown }) => {
    if (opts && opts.raw) {
      return sharpChain({ toBuffer: () => Promise.resolve(outPng) });
    }
    if (Buffer.isBuffer(input)) {
      if (input.equals(srcBuf)) {
        return sharpChain({
          metadata: () => Promise.resolve({ width: 800, height: 600, format: 'jpeg' }),
        });
      }
      if (input.equals(aiBuf)) {
        return sharpChain({
          toBuffer: () => Promise.resolve({ data: grayData, info: { width: 2, height: 1, channels: 1 } }),
        });
      }
      return sharpChain({ toBuffer: () => Promise.resolve(croppedPng) });
    }
    throw new Error('unexpected sharp input');
  });
  return { srcBuf, aiBuf, grayData };
}

beforeEach(() => {
  generateSilhouettePngMock.mockReset();
  generateImageMock.mockReset();
  sharpMock.mockReset();
});

describe('AiSilhouetteService', () => {
  describe('engine=local（缺省，向后兼容）', () => {
    it('成功路径：meta 缺省（sketch + crop:true + local）透传本地流水线，不触达 AI 配置', async () => {
      const cfg = cfgService();
      const service = new AiSilhouetteService(cfg);
      generateSilhouettePngMock.mockResolvedValueOnce(Buffer.from('png-bytes'));

      const res = await service.generate(image(), null);

      expect(generateSilhouettePngMock).toHaveBeenCalledWith(Buffer.from('fake-jpeg-bytes'), {
        mode: 'sketch',
        crop: true,
      });
      expect(res).toEqual({ image: Buffer.from('png-bytes').toString('base64'), mimeType: 'image/png' });
      // 本地引擎不依赖 AI 配置
      expect((cfg as unknown as { getActiveConfig: jest.Mock }).getActiveConfig).not.toHaveBeenCalled();
      expect(generateImageMock).not.toHaveBeenCalled();
    });

    it('成功路径：meta 指定 solid + crop:false + engine=local 显式透传', async () => {
      const service = new AiSilhouetteService(cfgService());
      generateSilhouettePngMock.mockResolvedValueOnce(Buffer.from('png-bytes'));

      await service.generate(image(), JSON.stringify({ mode: 'solid', crop: false, engine: 'local' }));

      expect(generateSilhouettePngMock).toHaveBeenCalledWith(Buffer.from('fake-jpeg-bytes'), {
        mode: 'solid',
        crop: false,
      });
    });

    it('meta 缺省个别字段：mode 缺省 sketch、crop 缺省 true（crop 填字符串忽略）', async () => {
      const service = new AiSilhouetteService(cfgService());
      generateSilhouettePngMock.mockResolvedValueOnce(Buffer.from('png-bytes'));

      await service.generate(image(), JSON.stringify({ crop: 'yes' }));

      expect(generateSilhouettePngMock).toHaveBeenCalledWith(Buffer.from('fake-jpeg-bytes'), {
        mode: 'sketch',
        crop: true,
      });
    });

    it('流水线异常（含模型缺失 503）原样透传', async () => {
      const service = new AiSilhouetteService(cfgService());
      generateSilhouettePngMock.mockRejectedValueOnce(
        new Error('剪影模型未安装，请在服务器执行 scripts/fetch-rmbg-model.mjs'),
      );

      await expect(service.generate(image(), null)).rejects.toThrow('剪影模型未安装');
    });
  });

  describe('engine=ai（AI 生图引擎）', () => {
    it('成功路径：走生图（剪影模型生效 + 参考图 + sketch 线稿提示词 + 最近似比例），阈值二值化转透明底', async () => {
      const service = new AiSilhouetteService(cfgService());
      const outPng = Buffer.from('final-png');
      setupSharpForAi(outPng, Buffer.from('unused'));
      generateImageMock.mockResolvedValueOnce({
        base64: Buffer.from('ai-gen-raw').toString('base64'),
        mimeType: 'image/png',
      });

      const res = await service.generate(image(), JSON.stringify({ mode: 'sketch', crop: false, engine: 'ai' }));

      // 生图参数：剪影模型覆盖 imageModel；线稿提示词；800x600 → 4:3；参考图 = 源图 base64
      expect(generateImageMock).toHaveBeenCalledTimes(1);
      const [genCfg, genInput] = generateImageMock.mock.calls[0];
      expect(genCfg).toEqual({ ...ACTIVE_CFG.image, model: 'wanx-sil-special' });
      expect(genInput.prompt).toContain('线稿');
      expect(genInput.size).toBe('1280*720'); // mapSize('qwen','4:3')
      expect(genInput.referenceBase64).toBe(Buffer.from('fake-jpeg-bytes').toString('base64'));
      expect(genInput.referenceMime).toBe('image/jpeg');
      // 不走本地流水线
      expect(generateSilhouettePngMock).not.toHaveBeenCalled();
      // 结果 = 二值化合成 PNG 的 base64
      expect(res).toEqual({ image: outPng.toString('base64'), mimeType: 'image/png' });
    });

    it('solid 模式：提示词为黑色实心人形剪影', async () => {
      const service = new AiSilhouetteService(cfgService());
      setupSharpForAi(Buffer.from('final-png'), Buffer.from('unused'));
      generateImageMock.mockResolvedValueOnce({
        base64: Buffer.from('ai-gen-raw').toString('base64'),
        mimeType: 'image/png',
      });

      await service.generate(image(), JSON.stringify({ mode: 'solid', crop: false, engine: 'ai' }));

      const [, genInput] = generateImageMock.mock.calls[0];
      expect(genInput.prompt).toContain('黑色实心人形剪影');
    });

    it('crop=true：按前景包围盒裁剪（黑像素 bbox 1x1），返回裁剪后 PNG', async () => {
      const service = new AiSilhouetteService(cfgService());
      const croppedPng = Buffer.from('cropped-png');
      setupSharpForAi(Buffer.from('final-png'), croppedPng);
      generateImageMock.mockResolvedValueOnce({
        base64: Buffer.from('ai-gen-raw').toString('base64'),
        mimeType: 'image/png',
      });

      const res = await service.generate(image(), JSON.stringify({ mode: 'sketch', crop: true, engine: 'ai' }));

      expect(res.image).toBe(croppedPng.toString('base64'));
    });

    it('未配置/未启用（getActiveConfig 503）→ 异常透传，不触达生图客户端', async () => {
      const cfg = {
        getActiveConfig: jest.fn(async () => {
          throw new Error('AI 未配置或未启用');
        }),
      };
      const service = new AiSilhouetteService(cfg as unknown as AiConfigService);

      await expect(service.generate(image(), JSON.stringify({ engine: 'ai' }))).rejects.toThrow('AI 未配置或未启用');
      expect(generateImageMock).not.toHaveBeenCalled();
      expect(generateSilhouettePngMock).not.toHaveBeenCalled();
    });
  });

  describe('参数校验（engine 无关）', () => {
    it('engine 非法 → 400，两条管线均不调用', async () => {
      const service = new AiSilhouetteService(cfgService());

      await expect(service.generate(image(), JSON.stringify({ engine: 'cloud' }))).rejects.toBeInstanceOf(
        BadRequestException,
      );
      await expect(service.generate(image(), JSON.stringify({ engine: 'cloud' }))).rejects.toThrow('engine 非法');
      expect(generateSilhouettePngMock).not.toHaveBeenCalled();
      expect(generateImageMock).not.toHaveBeenCalled();
    });

    it('非法 mimetype → 400，不调用流水线', async () => {
      const service = new AiSilhouetteService(cfgService());

      await expect(service.generate(image({ mimetype: 'text/plain' }), null)).rejects.toBeInstanceOf(
        BadRequestException,
      );
      await expect(service.generate(image({ mimetype: 'text/plain' }), null)).rejects.toThrow('jpg/png/webp');
      expect(generateSilhouettePngMock).not.toHaveBeenCalled();
    });

    it('超过 8MB → 400，不调用流水线', async () => {
      const service = new AiSilhouetteService(cfgService());
      const big = image({ buffer: Buffer.alloc(8 * 1024 * 1024 + 1) });

      await expect(service.generate(big, null)).rejects.toBeInstanceOf(BadRequestException);
      await expect(service.generate(big, null)).rejects.toThrow('8MB');
      expect(generateSilhouettePngMock).not.toHaveBeenCalled();
    });

    it('meta 非法 JSON → 400，不调用流水线', async () => {
      const service = new AiSilhouetteService(cfgService());

      await expect(service.generate(image(), '{not valid json')).rejects.toBeInstanceOf(BadRequestException);
      await expect(service.generate(image(), '{not valid json')).rejects.toThrow('meta');
      expect(generateSilhouettePngMock).not.toHaveBeenCalled();
    });

    it('meta 解析结果非对象（如数字/字符串）→ 400，不调用流水线', async () => {
      const service = new AiSilhouetteService(cfgService());

      await expect(service.generate(image(), '123')).rejects.toBeInstanceOf(BadRequestException);
      await expect(service.generate(image(), '"text"')).rejects.toThrow('meta');
      expect(generateSilhouettePngMock).not.toHaveBeenCalled();
    });

    it('mode 非法 → 400，不调用流水线', async () => {
      const service = new AiSilhouetteService(cfgService());

      await expect(service.generate(image(), JSON.stringify({ mode: 'invalid' }))).rejects.toBeInstanceOf(
        BadRequestException,
      );
      await expect(service.generate(image(), JSON.stringify({ mode: 'invalid' }))).rejects.toThrow('mode 非法');
      expect(generateSilhouettePngMock).not.toHaveBeenCalled();
    });
  });
});
