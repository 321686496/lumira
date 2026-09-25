// lumira-server/packages/backend/src/modules/ai/trend-research/research-digest.service.spec.ts
// 研究资料二次整理服务：结构化产出、进程内缓存命中、失败/无有效内容降级为 null。

import { ResearchDigestService, clearResearchBriefCache } from './research-digest.service';
import type { AiConfigService } from '../ai-config.service';
import type { ResearchItem } from './research-item';

jest.mock('../llm-client', () => ({ textChat: jest.fn() }));

const { textChat } = jest.requireMock('../llm-client') as { textChat: jest.Mock };

function aiConfig(throwing = false): AiConfigService {
  return {
    getActiveConfig: async () => {
      if (throwing) throw new Error('AI 未配置');
      return { text: { provider: 'test', baseUrl: 'http://x', apiKey: 'k', model: 'm' } };
    },
  } as unknown as AiConfigService;
}

function items(): ResearchItem[] {
  return [
    { source: 'qwen', title: '秋日人像趋势', snippet: '银杏林暖调低饱和', keywords: [], url: 'https://a.com' },
    { source: 'searxng', title: 'example.com', snippet: '', keywords: [] },
  ];
}

beforeEach(() => {
  clearResearchBriefCache();
  textChat.mockReset();
});

describe('ResearchDigestService', () => {
  it('把检索条目交给文本模型整理成结构化结论（提示词含创作意图与条目）', async () => {
    textChat.mockResolvedValue(
      JSON.stringify({ summary: '秋日暖调为主流', themes: ['秋季人像'], styles: [], colorLight: [], visualElements: ['银杏林'], seasons: [], poseIdeas: [], sources: [] }),
    );
    const svc = new ResearchDigestService(aiConfig());

    const brief = await svc.summarize('秋日人像模板', items());
    expect(brief?.summary).toBe('秋日暖调为主流');
    expect(brief?.themes).toEqual(['秋季人像']);

    const { systemPrompt, userText } = textChat.mock.calls[0][1] as { systemPrompt: string; userText: string };
    expect(systemPrompt).toContain('剔除');
    expect(userText).toContain('创作意图：秋日人像模板');
    expect(userText).toContain('秋日人像趋势');
    expect(userText).toContain('https://a.com'); // 带链接便于核验
  });

  it('同主题同条目二次调用命中进程内缓存，不重复调用模型', async () => {
    textChat.mockResolvedValue(JSON.stringify({ summary: '结论', themes: ['秋季人像'] }));
    const svc = new ResearchDigestService(aiConfig());

    await svc.summarize('秋日人像模板', items());
    await svc.summarize('秋日人像模板', items());

    expect(textChat).toHaveBeenCalledTimes(1);
  });

  it('模型调用失败（未配置/超时）→ null，由调用方回退规则摘要', async () => {
    textChat.mockRejectedValue(new Error('timeout'));
    const svc = new ResearchDigestService(aiConfig());

    await expect(svc.summarize('x', items())).resolves.toBeNull();

    // getActiveConfig 抛错同样降级
    const svc2 = new ResearchDigestService(aiConfig(true));
    await expect(svc2.summarize('x', items())).resolves.toBeNull();
  });

  it('模型输出无有效内容（只留下了无效条目）→ null', async () => {
    textChat.mockResolvedValue(JSON.stringify({ summary: '', themes: [], styles: [], colorLight: [], visualElements: [], seasons: [], poseIdeas: [], sources: [{ title: 'example.com' }] }));
    const svc = new ResearchDigestService(aiConfig());

    await expect(svc.summarize('x', items())).resolves.toBeNull();
  });

  it('无条目 → 直接返回 null，不调用模型', async () => {
    const svc = new ResearchDigestService(aiConfig());
    await expect(svc.summarize('x', [])).resolves.toBeNull();
    expect(textChat).not.toHaveBeenCalled();
  });
});