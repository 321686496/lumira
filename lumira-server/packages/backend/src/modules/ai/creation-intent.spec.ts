// 创作意图解析单测（设计文档：docs/superpowers/specs/2026-09-30-ai-creation-intent-design.md）
// 覆盖：normalize 夹取与 Step2 覆盖、fallback 口径、草稿回读、面板摘要、提示词注入块、
// parseCreationIntent 的 LLM 路径（成功 / 失败降级 / 无文本零调用）。

import {
  normalizeCreationIntent,
  fallbackCreationIntent,
  creationIntentOfDraft,
  describeCreationIntent,
  renderCreationIntentLines,
  parseCreationIntent,
} from './creation-intent';
import type { LlmEndpoint } from './llm-client';
import { textChatJson } from './llm-json';

jest.mock('./llm-json', () => ({
  textChatJson: jest.fn(),
}));

const textChatJsonMock = textChatJson as jest.MockedFunction<typeof textChatJson>;

const ENDPOINT = { provider: 'qwen', baseUrl: 'https://example.com/v1', apiKey: 'k', model: 'm' } as LlmEndpoint;
const RUNTIME = { retryCount: 0, timeoutMs: 600_000, maxTokens: 8192 };

beforeEach(() => {
  jest.clearAllMocks();
});

describe('normalizeCreationIntent', () => {
  it('九宫格逐格拆分：合法字段原样保留', () => {
    const intent = normalizeCreationIntent(
      { outputMode: 'split-per-cell', imageCount: 9, subjectPerImage: 1, sameSubjectAcross: true, reason: '按每格拆一张' },
      {},
    );
    expect(intent).toEqual({
      outputMode: 'split-per-cell',
      imageCount: 9,
      subjectPerImage: 1,
      sameSubjectAcross: true,
      reason: '按每格拆一张',
      source: 'llm',
    });
  });

  it('merge-group 张数恒为 1（即使模型给了更大张数）', () => {
    const intent = normalizeCreationIntent({ outputMode: 'merge-group', imageCount: 9, subjectPerImage: 9 }, {});
    expect(intent.imageCount).toBe(1);
    expect(intent.subjectPerImage).toBe(9);
  });

  it('张数/人数越界夹取到 1~9，非法枚举回退 single', () => {
    const intent = normalizeCreationIntent(
      { outputMode: 'unknown-mode', imageCount: 0, subjectPerImage: 99, sameSubjectAcross: false },
      {},
    );
    expect(intent.outputMode).toBe('single');
    expect(intent.imageCount).toBe(1);
    expect(intent.subjectPerImage).toBe(9);
    expect(intent.sameSubjectAcross).toBe(false);
  });

  it('Step2 显式姿势数/人数覆盖意图', () => {
    const intent = normalizeCreationIntent(
      { outputMode: 'split-per-cell', imageCount: 9, subjectPerImage: 1 },
      { poseCount: 3, subjectCount: 2 },
    );
    expect(intent.imageCount).toBe(3);
    expect(intent.subjectPerImage).toBe(2);
  });

  it('Step2 姿势数为 1 时产出形态收敛为 single；merge-group 不受 Step2 姿势数覆盖', () => {
    expect(normalizeCreationIntent({ outputMode: 'multi-pose', imageCount: 9 }, { poseCount: 1 }).outputMode).toBe('single');
    expect(normalizeCreationIntent({ outputMode: 'merge-group', imageCount: 1 }, { poseCount: 9 }).outputMode).toBe('merge-group');
  });
});

describe('fallbackCreationIntent', () => {
  it('无任何显式设置：不强制数量（单张，source=fallback）', () => {
    const intent = fallbackCreationIntent({});
    expect(intent).toEqual({
      outputMode: 'single',
      imageCount: 1,
      subjectPerImage: 1,
      sameSubjectAcross: true,
      reason: '创作要求未指定产出形态，AI 建议单张（可在创作要求改写）',
      source: 'fallback',
    });
  });

  it('Step2 显式姿势数 >1 时按显式张数给出 multi-pose', () => {
    const intent = fallbackCreationIntent({ poseCount: 4, subjectCount: 2 });
    expect(intent.outputMode).toBe('multi-pose');
    expect(intent.imageCount).toBe(4);
    expect(intent.subjectPerImage).toBe(2);
    expect(intent.source).toBe('fallback');
  });
});

describe('creationIntentOfDraft', () => {
  it('读回草稿顶层 creationIntent 并规范化', () => {
    const intent = creationIntentOfDraft({
      creationIntent: { outputMode: 'merge-group', imageCount: 5, subjectPerImage: 9, sameSubjectAcross: false, reason: '合成合影' },
    });
    expect(intent?.outputMode).toBe('merge-group');
    expect(intent?.imageCount).toBe(1);
    expect(intent?.subjectPerImage).toBe(9);
    expect(intent?.sameSubjectAcross).toBe(false);
    expect(intent?.source).toBe('llm');
  });

  it('缺失 / 形状非法 / 枚举非法 → null', () => {
    expect(creationIntentOfDraft({})).toBeNull();
    expect(creationIntentOfDraft({ creationIntent: 'x' })).toBeNull();
    expect(creationIntentOfDraft({ creationIntent: { outputMode: 'nope' } })).toBeNull();
  });
});

describe('面板摘要与提示词注入块', () => {
  it('describeCreationIntent 一行摘要含形态/张数/人数/关系与来源', () => {
    const line = describeCreationIntent(
      normalizeCreationIntent({ outputMode: 'split-per-cell', imageCount: 9, subjectPerImage: 1 }, {}),
    );
    expect(line).toBe('逐格拆分 · 9 张 · 每张 1 人 · 跨图同一人物（按创作要求）');
  });

  it('renderCreationIntentLines 为 merge-group 注入「不要输出九宫格」约束', () => {
    const lines = renderCreationIntentLines(
      normalizeCreationIntent({ outputMode: 'merge-group', imageCount: 1, subjectPerImage: 9, sameSubjectAcross: false }, {}),
    );
    expect(lines[0]).toContain('创作意图');
    expect(lines.join('\n')).toContain('合并要求');
    expect(lines.join('\n')).toContain('不要输出九宫格');
  });
});

describe('parseCreationIntent', () => {
  it('无任何文本 → 直接 fallback，零 LLM 调用', async () => {
    const intent = await parseCreationIntent(ENDPOINT, RUNTIME, {});
    expect(intent.source).toBe('fallback');
    expect(textChatJsonMock).not.toHaveBeenCalled();
  });

  it('有创作要求 → 走 LLM 解析（单次尝试、超时上限 120s）', async () => {
    textChatJsonMock.mockResolvedValue({
      outputMode: 'split-per-cell',
      imageCount: 9,
      subjectPerImage: 1,
      sameSubjectAcross: true,
      reason: '按每格拆一张',
    });
    const intent = await parseCreationIntent(ENDPOINT, RUNTIME, { creationReq: '按九宫格每格拆成一张姿势图' });
    expect(intent.source).toBe('llm');
    expect(intent.outputMode).toBe('split-per-cell');
    expect(intent.imageCount).toBe(9);
    const opts = textChatJsonMock.mock.calls[0][2] as { retryCount?: number; timeoutMs?: number };
    expect(opts.retryCount).toBe(0);
    expect(opts.timeoutMs).toBe(120_000);
  });

  it('LLM 抛错 → 降级 fallback，不阻断识别', async () => {
    textChatJsonMock.mockRejectedValue(new Error('timeout'));
    const intent = await parseCreationIntent(ENDPOINT, RUNTIME, { creationReq: '随便创作' });
    expect(intent.source).toBe('fallback');
    expect(intent.outputMode).toBe('single');
  });
});