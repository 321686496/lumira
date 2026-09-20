// lumira-server/packages/backend/src/modules/ai/param-validate.service.spec.ts
// T5 参数-App 效果校准器（Task 7，TDD）：暗景补光、legStretch 归位、数值 clamp

import { ParamValidateService } from './param-validate.service';

function build() {
  return new ParamValidateService();
}

describe('ParamValidateService.validate', () => {
  it('暗部场景且未补光 → 修正后含 composition.postProcess.fillLight.enabled===true', () => {
    const svc = build();
    const draft = {
      composition: { postProcess: {} },
      sceneGuide: { lightDirection: '夜景霓虹', background: '夜晚街道' },
      camera: {},
    };

    const res = svc.validate(draft as Record<string, unknown>);

    const post = (res.corrected.composition as Record<string, unknown>).postProcess as Record<string, unknown>;
    const fillLight = post.fillLight as Record<string, unknown>;
    expect(fillLight.enabled).toBe(true);
    expect(fillLight.intensity).toBeGreaterThan(0);
    expect(res.adjustments.length).toBeGreaterThan(0);
  });

  it('明亮白天场景不强制补光（fillLight 保持未设置）', () => {
    const svc = build();
    const draft = {
      composition: { postProcess: {} },
      sceneGuide: { background: '正午户外阳光' },
      camera: {},
    };

    const res = svc.validate(draft as Record<string, unknown>);
    const post = (res.corrected.composition as Record<string, unknown>).postProcess as Record<string, unknown>;
    expect((post.fillLight as Record<string, unknown> | undefined)?.enabled).toBeUndefined();
  });

  it('全身姿势的 legStretch 保留；半身以下（特写）过大 legStretch → 归位 0', () => {
    const svc = build();
    const fullBody = {
      composition: { postProcess: { legStretch: 0.4 } },
      pose: [{ description: '全身站立' }],
    };
    const res1 = svc.validate(fullBody as Record<string, unknown>);
    const post1 = (res1.corrected.composition as Record<string, unknown>).postProcess as Record<string, unknown>;
    expect(post1.legStretch).toBe(0.4);

    const bust = { composition: { postProcess: { legStretch: 0.9 } }, pose: [{ description: '面部特写' }] };
    const res2 = svc.validate(bust as Record<string, unknown>);
    const post2 = (res2.corrected.composition as Record<string, unknown>).postProcess as Record<string, unknown>;
    expect(post2.legStretch).toBe(0);
  });

  it('越界数值 clamp 回合法区间（brightness 200 → 100）', () => {
    const svc = build();
    const draft = {
      composition: { postProcess: { color: { brightness: 200, contrast: -500 } } },
    };
    const res = svc.validate(draft as Record<string, unknown>);
    const color = ((res.corrected.composition as Record<string, unknown>).postProcess as Record<string, unknown>).color as Record<string, number>;
    expect(color.brightness).toBe(100);
    expect(color.contrast).toBe(-100);
    expect(res.adjustments.join('\n')).toContain('brightness');
  });
});