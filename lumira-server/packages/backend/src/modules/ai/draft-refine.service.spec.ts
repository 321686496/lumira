// lumira-server/packages/backend/src/modules/ai/draft-refine.service.spec.ts
// 草稿细化单测：按评审未达标维度逐项整改的系统提示词（含真实底线与风格档案约束）。

import { DraftRefineService } from './draft-refine.service';
import { textChatJson } from './llm-json';
import type { LlmEndpoint } from './llm-client';
import type { AiConfigService } from './ai-config.service';
import type { StyleProfile } from './style-profile.presets';

jest.mock('./llm-json', () => ({
  visionChatJson: jest.fn(),
  textChatJson: jest.fn(),
  LlmJsonError: class LlmJsonError extends Error {},
}));
const textChatJsonMock = textChatJson as jest.MockedFunction<typeof textChatJson>;

const RUNTIME = { retryCount: 0, timeoutMs: 300_000, maxTokens: 8192 };

const TEXT: LlmEndpoint = { provider: 'qwen', baseUrl: 'x', apiKey: 'sk', model: 'qwen-plus' };

const PROFILE: StyleProfile = {
  category: 'portrait',
  archetype: 'fashion_editorial',
  aestheticTarget: '杂志时尚大片',
  subjectStyling: '驼色大衣',
  expressionMood: '冷峻直视',
  poseLanguage: '线条有张力',
  lightingSignature: '硬光高光比',
  compositionBias: '对角线',
  paletteHint: '低饱和高级灰',
  retouchLevel: 'polished',
  extraNotes: '',
};

function buildService() {
  const aiConfigService = { getActiveConfig: async () => ({ text: TEXT, runtime: RUNTIME }) } as unknown as AiConfigService;
  return new DraftRefineService(aiConfigService);
}

describe('DraftRefineService.refine', () => {
  beforeEach(() => textChatJsonMock.mockReset());

  it('按未达标维度逐项整改：提示词含逐项整改要求与 styleProfile 段落', async () => {
    textChatJsonMock.mockResolvedValueOnce({ draft: { meta: { name: '改进稿' } } });
    const svc = buildService();

    const out = await svc.refine({
      draft: { meta: { name: '原稿' } },
      suggests: ['pose[0].description 缺表情与左手落点，补：嘴角放松上提、左手扶帽檐'],
      desc: {
        global: { subject: '年轻女性', mood: '清冷', scene: '', season: '', timeOfDay: '', palette: { dominant: [], tone: '', brightness: '' }, light: {}, composition: {}, reproducibility: {} },
        people: [],
        scene: { location: '', depthLayers: { near: [], middle: [], far: [] }, props: [], furniture: [], texture: '', cleanliness: '' },
        cameraLike: {},
      } as never,
      poseSheet: { shared: {}, perPose: [] } as never,
      research: [],
      styleProfile: PROFILE,
      judgeModel: TEXT,
    });

    expect(out).toMatchObject({ meta: { name: '改进稿' } });
    const systemPrompt = String(textChatJsonMock.mock.calls[0][1].systemPrompt);
    expect(systemPrompt).toContain('逐项整改');
    expect(systemPrompt).toContain('不得破坏真实底线');
    expect(systemPrompt).toContain('styleProfile');
    expect(systemPrompt).toContain('本次风格档案（必须遵守）');
  });
});