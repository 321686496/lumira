// lumira-server/packages/backend/src/modules/ai/ai-generate-silhouette.service.spec.ts
// 剪影编排单测（Task 9）：jest.mock silhouette.pipeline（generateSilhouettePng mock），
// 覆盖：成功路径（资源校验通过 + 参数按 meta 透传 + base64 结果）/
//       非法 mimetype 400 / 超 8MB 400 / meta 非法 JSON 400 / meta 非对象 400 /
//       mode 非法 400 / mode/crop 非法类型按缺省兜底。
// e2e（含模型缺失 503 分支）由 CI 的 MySQL + 无模型环境验证。

import { BadRequestException } from '@nestjs/common';
import { AiSilhouetteService } from './ai-generate-silhouette.service';
import { generateSilhouettePng } from './silhouette.pipeline';
import { UploadFile } from '../templates/admin-templates.service';

// 本地流水线 mock（粗粒度模拟：记录入参、返回固定 PNG 字节）
jest.mock('./silhouette.pipeline', () => {
  const actual = jest.requireActual('./silhouette.pipeline');
  return { ...actual, generateSilhouettePng: jest.fn() };
});

const generateSilhouettePngMock = generateSilhouettePng as jest.MockedFunction<typeof generateSilhouettePng>;

function image(overrides: Partial<UploadFile> = {}): UploadFile {
  return {
    buffer: Buffer.from('fake-jpeg-bytes'),
    filename: 'a.jpg',
    mimetype: 'image/jpeg',
    ...overrides,
  };
}

beforeEach(() => {
  generateSilhouettePngMock.mockReset();
});

describe('AiSilhouetteService', () => {
  it('成功路径：默认 meta（sketch + crop:true）透传，返回 base64 PNG', async () => {
    const service = new AiSilhouetteService();
    generateSilhouettePngMock.mockResolvedValueOnce(Buffer.from('png-bytes'));

    const res = await service.generate(image(), null);

    expect(generateSilhouettePngMock).toHaveBeenCalledWith(Buffer.from('fake-jpeg-bytes'), {
      mode: 'sketch',
      crop: true,
    });
    expect(res).toEqual({ image: Buffer.from('png-bytes').toString('base64'), mimeType: 'image/png' });
  });

  it('成功路径：meta 指定 solid + crop:false 透传', async () => {
    const service = new AiSilhouetteService();
    generateSilhouettePngMock.mockResolvedValueOnce(Buffer.from('png-bytes'));

    await service.generate(image(), JSON.stringify({ mode: 'solid', crop: false }));

    expect(generateSilhouettePngMock).toHaveBeenCalledWith(Buffer.from('fake-jpeg-bytes'), {
      mode: 'solid',
      crop: false,
    });
  });

  it('meta 缺省个别字段：mode 缺省 sketch、crop 缺省 true（crop 填字符串忽略）', async () => {
    const service = new AiSilhouetteService();
    generateSilhouettePngMock.mockResolvedValueOnce(Buffer.from('png-bytes'));

    await service.generate(image(), JSON.stringify({ crop: 'yes' }));

    expect(generateSilhouettePngMock).toHaveBeenCalledWith(Buffer.from('fake-jpeg-bytes'), {
      mode: 'sketch',
      crop: true,
    });
  });

  it('非法 mimetype → 400，不调用流水线', async () => {
    const service = new AiSilhouetteService();

    await expect(service.generate(image({ mimetype: 'text/plain' }), null)).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.generate(image({ mimetype: 'text/plain' }), null)).rejects.toThrow('jpg/png/webp');
    expect(generateSilhouettePngMock).not.toHaveBeenCalled();
  });

  it('超过 8MB → 400，不调用流水线', async () => {
    const service = new AiSilhouetteService();
    const big = image({ buffer: Buffer.alloc(8 * 1024 * 1024 + 1) });

    await expect(service.generate(big, null)).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.generate(big, null)).rejects.toThrow('8MB');
    expect(generateSilhouettePngMock).not.toHaveBeenCalled();
  });

  it('meta 非法 JSON → 400，不调用流水线', async () => {
    const service = new AiSilhouetteService();

    await expect(service.generate(image(), '{not valid json')).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.generate(image(), '{not valid json')).rejects.toThrow('meta');
    expect(generateSilhouettePngMock).not.toHaveBeenCalled();
  });

  it('meta 解析结果非对象（如数字/字符串）→ 400，不调用流水线', async () => {
    const service = new AiSilhouetteService();

    await expect(service.generate(image(), '123')).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.generate(image(), '"text"')).rejects.toThrow('meta');
    expect(generateSilhouettePngMock).not.toHaveBeenCalled();
  });

  it('mode 非法 → 400，不调用流水线', async () => {
    const service = new AiSilhouetteService();

    await expect(service.generate(image(), JSON.stringify({ mode: 'invalid' }))).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.generate(image(), JSON.stringify({ mode: 'invalid' }))).rejects.toThrow('mode 非法');
    expect(generateSilhouettePngMock).not.toHaveBeenCalled();
  });

  it('流水线异常（含模型缺失 503）原样透传', async () => {
    const service = new AiSilhouetteService();
    generateSilhouettePngMock.mockRejectedValueOnce(new Error('剪影模型未安装，请在服务器执行 scripts/fetch-rmbg-model.mjs'));

    await expect(service.generate(image(), null)).rejects.toThrow('剪影模型未安装');
  });
});