/**
 * Vitest 测试环境 setup
 * Mock uni-app 全局 API 和模块
 */
import { vi } from 'vitest'

// Mock uni 全局对象
const mockUni = {
  navigateTo: vi.fn(({ url, success, fail }) => {
    if (success) success()
    return Promise.resolve()
  }),
  navigateBack: vi.fn(({ success } = {}) => {
    if (success) success()
    return Promise.resolve()
  }),
  switchTab: vi.fn(({ url, success }) => {
    if (success) success()
    return Promise.resolve()
  }),
  redirectTo: vi.fn(({ success }) => {
    if (success) success()
    return Promise.resolve()
  }),
  showToast: vi.fn(),
  showLoading: vi.fn(),
  hideLoading: vi.fn(),
  showModal: vi.fn(({ success }) => {
    if (success) success({ confirm: true })
  }),
  getStorageSync: vi.fn((key: string) => {
    const store = (globalThis as unknown as { __mockStorage: Map<string, unknown> }).__mockStorage
    return store?.get(key) ?? ''
  }),
  setStorageSync: vi.fn((key: string, value: unknown) => {
    const store = (globalThis as unknown as { __mockStorage: Map<string, unknown> }).__mockStorage
    if (store) store.set(key, value)
  }),
  removeStorageSync: vi.fn((key: string) => {
    const store = (globalThis as unknown as { __mockStorage: Map<string, unknown> }).__mockStorage
    store?.delete(key)
  }),
  request: vi.fn(),
  chooseImage: vi.fn(({ success }) => {
    if (success) success({ tempFilePaths: ['mock://image.jpg'] })
  }),
  chooseMessageFile: vi.fn(({ success }) => {
    if (success) success({ tempFiles: [{ path: 'mock://template.pptpl', name: 'template.pptpl' }] })
  }),
  saveImageToPhotosAlbum: vi.fn(({ success }) => {
    if (success) success()
  }),
  startAccelerometer: vi.fn(),
  stopAccelerometer: vi.fn(),
  onAccelerometerChange: vi.fn(),
  getSystemInfoSync: vi.fn(() => ({
    platform: 'devtools',
    pixelRatio: 2,
    windowWidth: 375,
    windowHeight: 812,
    statusBarHeight: 44,
    safeArea: { top: 44, bottom: 778, left: 0, right: 375 },
  })),
  requireNativePlugin: vi.fn((name: string) => {
    throw new Error(`Native plugin ${name} not available in test`)
  }),
  // 事件总线（uni-app 跨平台 API，测试环境需提供以支持条件编译分支）
  $emit: vi.fn(),
  $on: vi.fn(),
  $off: vi.fn(),
  $once: vi.fn(),
}

// 设置全局
;(globalThis as Record<string, unknown>).uni = mockUni

// Mock @dcloudio/uni-app 模块
vi.mock('@dcloudio/uni-app', () => ({
  onLoad: vi.fn((cb: (query: Record<string, string>) => void) => {
    // 存储 callback 供测试触发
    ;(globalThis as unknown as { __onLoadCallback: typeof cb }).__onLoadCallback = cb
  }),
  onShow: vi.fn((cb: () => void) => {
    ;(globalThis as unknown as { __onShowCallback: typeof cb }).__onShowCallback = cb
  }),
  onHide: vi.fn((cb: () => void) => {
    ;(globalThis as unknown as { __onHideCallback: typeof cb }).__onHideCallback = cb
  }),
  onLaunch: vi.fn(),
  onReady: vi.fn(),
  onUnload: vi.fn(),
  onReachBottom: vi.fn(),
  onPullDownRefresh: vi.fn(),
}))

// Mock @dcloudio/uni-app 组件
vi.mock('@dcloudio/uni-app', async () => {
  const actual = await vi.importActual('@dcloudio/uni-app').catch(() => ({}))
  return actual
})

// 初始化 mock storage
;(globalThis as unknown as { __mockStorage: Map<string, unknown> }).__mockStorage = new Map()
