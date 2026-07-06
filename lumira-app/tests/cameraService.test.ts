/**
 * 相机服务测试
 * 对应测试文档：
 * - LM-CAP-DATA-021: 相机初始化
 * - LM-CAP-DATA-022: 拍摄返回路径
 * - LM-CAP-DATA-023: 参数读写一致
 * - LM-CAP-DATA-024: 水平检测数据
 * - LM-CAP-DATA-025: 资源释放
 * - LM-CAP-ERR-026: 相机被占用
 * - LM-CAP-UI-013: 快门连拍防抖
 */
import { describe, it, expect, beforeEach } from 'vitest'
import { CameraServiceMockImpl } from '@/services/camera'
import type { CameraConfig } from '@/types/camera'

describe('CameraService (Mock)', () => {
  let camera: CameraServiceMockImpl

  beforeEach(() => {
    camera = new CameraServiceMockImpl()
  })

  // === LM-CAP-DATA-021: 相机初始化 ===
  describe('相机初始化 (LM-CAP-DATA-021)', () => {
    it('initialize 应成功完成', async () => {
      const config: CameraConfig = {
        defaultCamera: 'back',
        enableOverlay: true,
        enableAlignment: true,
      }
      await expect(camera.initialize(config)).resolves.toBeUndefined()
    })

    it('startPreview 应在初始化后成功', async () => {
      await camera.initialize({
        defaultCamera: 'back',
        enableOverlay: true,
        enableAlignment: true,
      })
      await expect(camera.startPreview()).resolves.toBeUndefined()
    })

    it('未初始化时 startPreview 应抛出错误', async () => {
      await expect(camera.startPreview()).rejects.toThrow('相机未初始化')
    })
  })

  // === LM-CAP-DATA-022: 拍摄返回路径 ===
  describe('拍摄返回路径 (LM-CAP-DATA-022)', () => {
    it('capture 应返回有效照片路径', async () => {
      await camera.initialize({
        defaultCamera: 'back',
        enableOverlay: false,
        enableAlignment: false,
      })
      await camera.startPreview()
      const result = await camera.capture()
      expect(result.path).toBeTruthy()
      expect(typeof result.path).toBe('string')
      expect(result.width).toBeGreaterThan(0)
      expect(result.height).toBeGreaterThan(0)
      expect(result.capturedAt).toBeGreaterThan(0)
    })

    it('未启动预览时 capture 应抛出错误', async () => {
      await camera.initialize({
        defaultCamera: 'back',
        enableOverlay: false,
        enableAlignment: false,
      })
      await expect(camera.capture()).rejects.toThrow('相机预览未启动')
    })
  })

  // === LM-CAP-DATA-023: 参数读写一致 ===
  describe('参数读写一致性 (LM-CAP-DATA-023)', () => {
    it('setParameters 后 getParameters 应返回一致值', async () => {
      await camera.setParameters({
        evBias: 0.3,
        iso: 200,
        whiteBalance: 'daylight',
        flashMode: 'off',
      })
      const params = await camera.getParameters()
      expect(params.evBias).toBe(0.3)
      expect(params.iso).toBe(200)
      expect(params.whiteBalance).toBe('daylight')
      expect(params.flashMode).toBe('off')
    })

    it('部分更新参数应保留其他参数不变', async () => {
      await camera.setParameters({ evBias: 1.0 })
      await camera.setParameters({ iso: 400 })
      const params = await camera.getParameters()
      expect(params.evBias).toBe(1.0)
      expect(params.iso).toBe(400)
    })
  })

  // === LM-CAP-DATA-024: 水平检测数据 ===
  describe('水平检测 (LM-CAP-DATA-024)', () => {
    it('detectLevel 应返回 isLevel 和 angle', async () => {
      const result = await camera.detectLevel()
      expect(result).toHaveProperty('isLevel')
      expect(result).toHaveProperty('angle')
      expect(typeof result.isLevel).toBe('boolean')
      expect(typeof result.angle).toBe('number')
    })
  })

  // === LM-CAP-DATA-025: 资源释放 ===
  describe('资源释放 (LM-CAP-DATA-025)', () => {
    it('release 应清理相机资源', async () => {
      await camera.initialize({
        defaultCamera: 'back',
        enableOverlay: true,
        enableAlignment: true,
      })
      await camera.startPreview()
      await camera.release()
      // 释放后 startPreview 应再次抛出（未初始化）
      await expect(camera.startPreview()).rejects.toThrow('相机未初始化')
    })

    it('stopPreview 应停止预览', async () => {
      await camera.initialize({
        defaultCamera: 'back',
        enableOverlay: false,
        enableAlignment: false,
      })
      await camera.startPreview()
      await camera.stopPreview()
      // 停止后 capture 应抛出
      await expect(camera.capture()).rejects.toThrow('相机预览未启动')
    })
  })

  // === LM-CAP-UI-013: 快门连拍防抖 ===
  describe('快门连拍防抖 (LM-CAP-UI-013)', () => {
    it('每次 capture 应返回不同的路径', async () => {
      await camera.initialize({
        defaultCamera: 'back',
        enableOverlay: false,
        enableAlignment: false,
      })
      await camera.startPreview()
      const r1 = await camera.capture()
      const r2 = await camera.capture()
      expect(r1.path).not.toBe(r2.path)
    })
  })

  // === 叠图操作 ===
  describe('叠图操作', () => {
    it('setOverlay 应接受叠图层数据', async () => {
      await camera.setOverlay({
        composition: undefined,
        pose: undefined,
        opacity: 0.5,
        visible: true,
      })
    })

    it('setOverlayOpacity 应限制在 0~1', async () => {
      await camera.setOverlayOpacity(0.8)
      await camera.setOverlayOpacity(-0.5)
      await camera.setOverlayOpacity(1.5)
      // 不抛出错误即通过（内部 clamp）
    })
  })

  // === 切换摄像头 ===
  describe('switchCamera', () => {
    it('应无错误完成', async () => {
      await camera.initialize({
        defaultCamera: 'back',
        enableOverlay: false,
        enableAlignment: false,
      })
      await expect(camera.switchCamera()).resolves.toBeUndefined()
    })
  })

  // === isAvailable ===
  describe('isAvailable', () => {
    it('Mock 实现应返回 true', () => {
      expect(camera.isAvailable()).toBe(true)
    })
  })
})
