// lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.spec.ts
// 生图编排单测（Task 7）：jest.mock image-client（generateImage mock，mapSize 保留真实），
// AiConfigService 手工 stub（同 ai-analyze.service.spec.ts 模式）。
// Task 4 接入润色：jest.mock llm-client（textChat 默认返回润色值，回退用例单独 reject）。
// 覆盖：成功路径 prompt/size/参考图透传 / 未配置 503 / meta 非法 JSON 400 /
// meta 非对象 400 / meta 缺省空草稿兜底 / 无参考图字段缺省 / 结果透传 / 润色失败回退。

import { BadRequestException, ServiceUnavailableException } from '@nestjs/common';
import {
  AiGenerateImageService,
  hardenPhotoRealism,
  PHOTO_REALISM_BASELINE_SUFFIX,
  RETOUCH_REALISM_SUFFIX,
} from './ai-generate-image.service';
import { AiConfigService } from './ai-config.service';
import { generateImage } from './image-client';
import { buildImagePrompt } from './image-prompt.builder';
import * as composerModule from './image-prompt.composer';
import type { PromptComposeInput } from './image-prompt.composer';
import { UploadFile } from '../templates/admin-templates.service';

// generateImage mock（网络层）；mapSize / buildImagePrompt 纯函数保留真实实现
jest.mock('./image-client', () => {
  const actual = jest.requireActual('./image-client');
  return { ...actual, generateImage: jest.fn() };
});

// textChat mock（网络层）：默认返回润色值，润色失败回退用例单独 mockRejectedValueOnce
jest.mock('./llm-client', () => ({
  textChat: jest.fn(async () => '润色后的提示词'),
}));

const generateImageMock = generateImage as jest.MockedFunction<typeof generateImage>;

const ACTIVE_CFG = {
  vision: {
    provider: 'doubao',
    baseUrl: 'https://ark.example.com/api/v3',
    apiKey: 'sk-test',
    model: 'doubao-vision',
  },
  text: {
    provider: 'doubao',
    baseUrl: 'https://ark.example.com/api/v3',
    apiKey: 'sk-test',
    model: 'doubao-vision',
  },
  image: {
    provider: 'doubao',
    baseUrl: 'https://ark.example.com/api/v3',
    apiKey: 'sk-test',
    model: 'doubao-seedream',
  },
  hasCustomTextModel: false,
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
  const { textChat } = jest.requireMock('./llm-client') as { textChat: jest.Mock };
  textChat.mockClear(); // 保留默认润色实现，仅清调用记录
});

describe('AiGenerateImageService', () => {
  it('成功路径：润色收到 cfg.text、生图收到 cfg.image（prompt/size/参考图透传）、结果透传', async () => {
    const { service } = buildService();
    generateImageMock.mockResolvedValueOnce({ base64: 'aGVsbG8=', mimeType: 'image/png' });
    const { textChat } = jest.requireMock('./llm-client') as { textChat: jest.Mock };

    const res = await service.generate(referenceFile(), JSON.stringify(DRAFT));

    // 润色走文本模态端点
    expect(textChat).toHaveBeenCalledTimes(1);
    expect(textChat.mock.calls[0][0]).toEqual(ACTIVE_CFG.text);
    // 生图走生图模态端点；prompt=润色值、size=mapSize(cfg.image.provider, '3:4')
    expect(generateImageMock).toHaveBeenCalledTimes(1);
    const [cfg, input] = generateImageMock.mock.calls[0];
    expect(cfg).toEqual(ACTIVE_CFG.image);
    expect(input.prompt).toBe(hardenPhotoRealism('润色后的提示词')); // 出口统一照片写实加固
    expect(input.size).toBe('864x1152'); // mapSize('doubao', '3:4')
    expect(input.referenceBase64).toBe(Buffer.from('ref-bytes').toString('base64'));
    expect(input.referenceMime).toBe('image/jpeg');
    // 结果透传：图片本体 + 出口加固后的提示词与实际使用的生图模型
    expect(res).toMatchObject({ base64: 'aGVsbG8=', mimeType: 'image/png' });
    expect(res.prompt).toBe(hardenPhotoRealism('润色后的提示词'));
    expect(res.model).toBe(ACTIVE_CFG.image.model);
  });

  it('润色失败 → generateImage 收到原始拼接 prompt', async () => {
    const { textChat } = jest.requireMock('./llm-client') as { textChat: jest.Mock };
    textChat.mockRejectedValueOnce(new Error('timeout'));
    const { service } = buildService();
    generateImageMock.mockResolvedValueOnce({ base64: 'aGVsbG8=', mimeType: 'image/png' });

    await service.generate(referenceFile(), JSON.stringify(DRAFT));

    expect(generateImageMock).toHaveBeenCalledTimes(1);
    const input = generateImageMock.mock.calls[0][1];
    expect(input.prompt).toBe(hardenPhotoRealism(buildImagePrompt(DRAFT))); // 润色失败静默回退拼接值（含出口加固）
  });

  it('出口加固：生图 prompt 包含照片媒介声明与反动漫负面清单', async () => {
    const { service } = buildService();
    generateImageMock.mockResolvedValueOnce({ base64: 'aGVsbG8=', mimeType: 'image/png' });

    await service.generate(undefined, JSON.stringify(DRAFT));

    const input = generateImageMock.mock.calls[0][1];
    expect(input.prompt.startsWith('一张真实相机直出的实拍照片：')).toBe(true);
    expect(input.prompt).toContain('皮肤纹理与布料纤维可辨');
    expect(input.prompt).toContain('禁止：动漫、二次元、漫画、插画');
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
    expect(input.prompt).toBe(hardenPhotoRealism('润色后的提示词')); // 空草稿兜底 prompt 同样过润色 + 出口加固
    expect(input.size).toBe('1024x1024'); // mapSize('doubao', undefined)
  });

  it('researchJson 透传：组织器素材注入网络趋势参考（含标题与摘要）', async () => {
    const { service } = buildService();
    generateImageMock.mockResolvedValueOnce({ base64: 'aGVsbG8=', mimeType: 'image/png' });
    const { textChat } = jest.requireMock('./llm-client') as { textChat: jest.Mock };
    const researchJson = JSON.stringify([{ source: 'sogou', title: '千金风穿搭', snippet: '低调贵气' }]);

    await service.generate(undefined, JSON.stringify(DRAFT), null, researchJson);

    expect(textChat).toHaveBeenCalledTimes(1);
    const input = textChat.mock.calls[0][1];
    expect(input.userText).toContain('【网络趋势参考】');
    expect(input.userText).toContain('千金风穿搭');
    expect(input.userText).toContain('低调贵气');
  });

  it('researchJson 非法 → 静默降级为空（素材无网络趋势参考，不阻断生图）', async () => {
    const { service } = buildService();
    generateImageMock.mockResolvedValueOnce({ base64: 'aGVsbG8=', mimeType: 'image/png' });
    const { textChat } = jest.requireMock('./llm-client') as { textChat: jest.Mock };

    await service.generate(undefined, JSON.stringify(DRAFT), null, '{not valid json');

    expect(textChat).toHaveBeenCalledTimes(1);
    expect(textChat.mock.calls[0][1].userText).not.toContain('【网络趋势参考】');
    expect(generateImageMock).toHaveBeenCalledTimes(1);
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

describe('hardenPhotoRealism 自拍设备负面清单', () => {
  it('自拍（selfie=true）：出口末尾追加拍摄设备负面清单', () => {
    const out = hardenPhotoRealism('提示词', { selfie: true });
    expect(out).toContain('不出现手机、相机、三脚架');
    expect(out.indexOf('不出现手机、相机、三脚架')).toBeGreaterThan(out.indexOf('提示词'));
  });

  it('非自拍（默认）：不追加该清单', () => {
    expect(hardenPhotoRealism('提示词')).not.toContain('不出现手机、相机、三脚架');
  });
});

describe('hardenPhotoRealism 精修档分档', () => {
  it('分档加固：三档结尾句不同；确定性不含「轻微噪点」「禁止影楼写真」「网红精修风」', () => {
    const none = hardenPhotoRealism('P', { retouchLevel: 'none' });
    const light = hardenPhotoRealism('P', { retouchLevel: 'light' });
    const polished = hardenPhotoRealism('P', { retouchLevel: 'polished' });

    expect(none).toContain(RETOUCH_REALISM_SUFFIX.none);
    expect(light).toContain(RETOUCH_REALISM_SUFFIX.light);
    expect(polished).toContain(RETOUCH_REALISM_SUFFIX.polished);
    for (const p of [none, light, polished]) {
      expect(p).not.toContain('轻微噪点');
      expect(p).not.toContain('禁止影楼写真');
      expect(p).not.toContain('网红精修风');
      expect(p).toContain('禁止：动漫、二次元、漫画、插画');
      expect(p).toContain(PHOTO_REALISM_BASELINE_SUFFIX);
    }
  });

  it('不传 opts：默认 none 档，且与旧调用兼容（返回包含原 prompt）', () => {
    const out = hardenPhotoRealism('原提示词');
    expect(out).toContain('原提示词');
    expect(out).toContain(RETOUCH_REALISM_SUFFIX.none);
  });

  it('generate()：从 draft.styleProfile 读取 retouchLevel 传给加固', async () => {
    const { service } = buildService();
    generateImageMock.mockResolvedValueOnce({ base64: 'eA==', mimeType: 'image/png' });
    await service.generate(
      undefined,
      JSON.stringify({ styleProfile: { archetype: 'fashion_editorial', retouchLevel: 'polished' } }),
    );
    const [, input] = generateImageMock.mock.calls[0];
    expect(String(input.prompt)).toContain(RETOUCH_REALISM_SUFFIX.polished);
  });
});

describe('hardenPhotoRealism 去噪', () => {
  it('不引入颗粒/噪点要求，且声明禁止噪点', () => {
    const out = hardenPhotoRealism('一段提示词', {});
    expect(out).not.toContain('自然噪点');
    expect(out).toContain('高清干净');
    expect(out).toContain('禁止颗粒与噪点');
  });
});

describe('research 两种形态解析', () => {
  it('对象形态 {items, brief} 时 brief 透传到组织器', async () => {
    const { service } = buildService();
    generateImageMock.mockResolvedValueOnce({ base64: 'aGVsbG8=', mimeType: 'image/png' });
    const composeSpy = jest.spyOn(composerModule, 'composeImagePrompt');

    await service.generate(undefined, JSON.stringify({ meta: { category: 'portrait' } }), null, JSON.stringify({
      items: [{ source: 'searxng', title: 't', snippet: 's', keywords: [] }],
      brief: { summary: '', themes: [], styles: [], colorLight: [], visualElements: [], seasons: [], poseIdeas: ['p'], sources: [] },
    }));

    expect(composeSpy.mock.calls[0][1]).toMatchObject({ brief: { poseIdeas: ['p'] } });
    expect(composeSpy.mock.calls[0][1]).toMatchObject({ research: [{ title: 't' }] });
    composeSpy.mockRestore();
  });

  it('数组形态（旧前端）兼容为 items 且 brief 为 null', async () => {
    const { service } = buildService();
    generateImageMock.mockResolvedValueOnce({ base64: 'aGVsbG8=', mimeType: 'image/png' });
    const composeSpy = jest.spyOn(composerModule, 'composeImagePrompt');

    await service.generate(undefined, JSON.stringify({ meta: { category: 'portrait' } }), null, JSON.stringify([{ source: 'x', title: 't', snippet: 's', keywords: [] }]));

    expect((composeSpy.mock.calls[0][1] as PromptComposeInput).brief).toBeNull();
    expect(composeSpy.mock.calls[0][1]).toMatchObject({ research: [{ title: 't' }] });
    composeSpy.mockRestore();
  });
});
