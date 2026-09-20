// lumira-server/packages/backend/src/modules/ai/pose-ref-sheet.service.spec.ts
// T3 姿势参考面片服务（Task 6，TDD）：mock textChat(jsonMode) → PoseRefSheet；shared 锚点 + perPose 长度/差异项校验

import { PoseRefSheetService } from './pose-ref-sheet.service';
import { textChat } from './llm-client';
import type { LlmEndpoint } from './llm-client';
import type { ImageDescription } from './image-describe.service';
import type { AiConfigService } from './ai-config.service';

jest.mock('./llm-client', () => ({ textChat: jest.fn() }));

const textChatMock = textChat as jest.MockedFunction<typeof textChat>;

const TEXT: LlmEndpoint = { provider: 'qwen', baseUrl: 'https://x.example/v1', apiKey: 'sk', model: 'qwen-plus' };

function buildService() {
  const aiConfigService = { getActiveConfig: async () => ({ text: TEXT }) } as unknown as AiConfigService;
  return new PoseRefSheetService(aiConfigService);
}

const DESC: ImageDescription = {
  global: { subject: '年轻女性', mood: '清冷', season: '秋', timeOfDay: 'day', palette: { dominant: [], tone: '暖', brightness: '' }, light: {}, composition: { leadLines: '', framing: '', symmetry: '', subjectFrame: {}, cropRatio: '3:4', negativeSpace: '', depthOfField: '' }, reproducibility: { level: 'high', reason: '', enableFillLight: true, lightHint: '' } },
  people: [], scene: { location: '', depthLayers: { near: [], middle: [], far: [] }, props: [], furniture: [], texture: '', cleanliness: '' },
  cameraLike: { lightSuggestion: '', wbSuggestion: '', evSuggestion: '', focusDepth: '' },
};

function legalSheet(): string {
  return JSON.stringify({
    shared: { outfit: '针织衫', scene: '飘窗', light: '侧逆窗光', aspectRatio: '3:4', mood: '清冷慵懒', palette: '#d2b48c' },
    perPose: [
      { name: '侧身回眸', subjectPose: { torso: '侧4/3' }, camera: { angle: '平视' }, frame: { subjectFrame: {} }, lightOnPose: {}, differentiationNote: '回眸看镜头，身体更侧' },
      { name: '俯身微笑', subjectPose: { torso: '俯身' }, camera: { angle: '俯拍' }, frame: { subjectFrame: {} }, lightOnPose: {}, differentiationNote: '重心前移，表情更甜' },
    ],
  });
}

describe('PoseRefSheetService.generate', () => {
  beforeEach(() => textChatMock.mockReset());

  it('合法 JSON → 解析成 PoseRefSheet：shared 五锚点齐全、perPose 长度==poseCount、diffNote 非空', async () => {
    textChatMock.mockResolvedValueOnce(legalSheet());
    const svc = buildService();

    const sheet = await svc.generate(DESC, 2);

    for (const k of ['outfit', 'scene', 'light', 'aspectRatio', 'mood', 'palette']) {
      expect(sheet.shared).toHaveProperty(k);
    }
    expect(sheet.perPose).toHaveLength(2);
    expect(sheet.perPose[0].differentiationNote.trim().length).toBeGreaterThan(0);
    // textChat 走 text 端点 + jsonMode
    const [cfg, input] = textChatMock.mock.calls[0];
    expect(cfg).toEqual(TEXT);
    expect(input.jsonMode).toBe(true);
    expect(input.userText).toContain('姿势');
  });

  it('perPose 超出 poseCount → 截断为 poseCount（跨姿势一致性护栏）', async () => {
    textChatMock.mockResolvedValueOnce(legalSheet());
    const svc = buildService();
    const sheet = await svc.generate(DESC, 1);
    expect(sheet.perPose).toHaveLength(1);
  });

  it('非法 JSON → 抛可读错误（含「无法解析」）', async () => {
    textChatMock.mockResolvedValueOnce('没有姿势');
    const svc = buildService();
    await expect(svc.generate(DESC, 2)).rejects.toThrow('无法解析');
  });
});