// lumira-server/packages/backend/src/modules/ai/render-approx.service.spec.ts
// RenderApproxService：sharp 近似复刻 App PostProcess 的服务端渲染管线（P4 实拍闭环）。
import sharp from 'sharp';
import {
  RenderApproxService,
  RenderApproxOptions,
} from './render-approx.service';

/** 生成固定尺寸的实心贴图 PNG，便于稳定比较字节差异 */
async function makeSolid(w: number, h: number, rgb: [number, number, number]): Promise<Buffer> {
  return sharp(Buffer.from([...rgb, 255]), {
    raw: { width: 1, height: 1, channels: 4 },
  })
    .resize(w, h)
    .png()
    .toBuffer();
}

describe('RenderApproxService', () => {
  let service: RenderApproxService;

  beforeEach(() => {
    service = new RenderApproxService();
  });

  describe('apply 基本行为', () => {
    it('带后处理 opts 的 png buffer → 返回不同 buffer，且尺寸一致', async () => {
      const input = await makeSolid(64, 80, [120, 100, 140]);
      const opts: RenderApproxOptions = {
        postProcess: {
          color: { brightness: 12, contrast: 18, saturation: 10, temperature: 8, tint: -4 },
          vignette: 30,
          grain: 20,
          smoothStrength: 10,
          sharpen: 0,
          lut: 'vintage',
        },
      };

      const out = await service.apply(input, opts);
      expect(Buffer.isBuffer(out)).toBe(true);
      expect(out.equals(input)).toBe(false);

      const metaOut = await sharp(out).metadata();
      const metaIn = await sharp(input).metadata();
      expect(metaOut.width).toBe(metaIn.width);
      expect(metaOut.height).toBe(metaIn.height);
    });

    it('不传任何 postProcess → 返回不同编码但可用的图片（不抛）', async () => {
      const input = await makeSolid(16, 16, [10, 20, 30]);
      const out = await service.apply(input, { postProcess: {} });
      expect(Buffer.isBuffer(out)).toBe(true);
      const meta = await sharp(out).metadata();
      expect(meta.width).toBe(16);
      expect(meta.height).toBe(16);
    });
  });

  describe('fillLight 叠加', () => {
    it('fillLight 开启时输出与关闭时不同（字节差异 > 0）', async () => {
      const input = await makeSolid(32, 32, [200, 190, 180]);
      const base: RenderApproxOptions = {
        postProcess: { color: { brightness: 0, contrast: 0, saturation: 0 } },
      };
      const off = await service.apply(input, { ...base, fillLight: { enabled: false, color: 'warm', intensity: 0.6 } });
      const on = await service.apply(input, {
        ...base,
        fillLight: { enabled: true, color: 'warm', intensity: 0.6 },
      });

      // 字节层面必然存在差异（不依赖肉眼可比性）
      expect(off.equals(input)).toBe(true); // disabled 时 pipeline 与原图一致
      expect(on.equals(off)).toBe(false);
    });

    it('支持十六进制暖色 + intensity，intensity 为 0 时不变', async () => {
      const input = await makeSolid(24, 24, [150, 120, 110]);
      const base: RenderApproxOptions = { postProcess: { color: {} } };

      const intense = await service.apply(input, {
        ...base,
        fillLight: { enabled: true, color: '#FFAA66', intensity: 0.8 },
      });
      const none = await service.apply(input, {
        ...base,
        fillLight: { enabled: true, color: '#FFAA66', intensity: 0 },
      });
      expect(intense.equals(input)).toBe(false);
      expect(none.equals(input)).toBe(true);
    });

    it('fillLight 缺省/未知色 → 兜底不抛，静默回退 warm', async () => {
      const input = await makeSolid(16, 16, [100, 100, 100]);
      await expect(
        service.apply(input, {
          postProcess: {},
          fillLight: { enabled: true, color: 'totally_unknown', intensity: 0.5 },
        }),
      ).resolves.toBeInstanceOf(Buffer);
    });
  });

  describe('异常 param 兜底', () => {
    it('postProcess 含非数值/越界字段时不 throw，输出仍为图片', async () => {
      const input = await makeSolid(24, 24, [60, 80, 100]);
      const out = await service.apply(input, {
        postProcess: {
          color: {
            brightness: 'abc' as unknown as number,
            contrast: Number.POSITIVE_INFINITY,
            saturation: 9999,
          },
          lut: 'no_such_lut',
        } as unknown as Record<string, unknown>,
      });
      expect(Buffer.isBuffer(out)).toBe(true);
      const meta = await sharp(out).metadata();
      expect(meta.width).toBe(24);
      expect(meta.height).toBe(24);
    });

    it('opts 缺失字段（postProcess 为 null）→ 不抛', async () => {
      const input = await makeSolid(8, 8, [1, 2, 3]);
      await expect(
        service.apply(input, { postProcess: null } as unknown as RenderApproxOptions),
      ).resolves.toBeInstanceOf(Buffer);
    });
  });
});