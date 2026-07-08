/**
 * FloatingTabBar 组件测试
 * 对应测试文档：
 * - LM-NAV-NAV-001/002/003: Tab 切换
 * - LM-NAV-UI-004: 选中态动效
 * - LM-NAV-UI-005: 点击反馈
 * - LM-NAV-UI-006: 深色态切换
 * - LM-NAV-UI-007: 悬浮定位
 */
import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import FloatingTabBar from '@/components/FloatingTabBar.vue'

describe('FloatingTabBar 组件', () => {
  it('应渲染 Tab 项', () => {
    const wrapper = mount(FloatingTabBar, {
      props: { current: 'home' },
    })
    // 左右两个侧边 Tab + 中间快门
    const sideItems = wrapper.findAll('.tab-side')
    expect(sideItems).toHaveLength(2)
    const shutter = wrapper.find('.shutter-btn')
    expect(shutter.exists()).toBe(true)
  })

  // === LM-NAV-NAV-001/002/003: Tab 切换 ===
  it('点击首页 Tab 应触发 on-switch: home', async () => {
    const wrapper = mount(FloatingTabBar, {
      props: { current: 'profile' },
    })
    const sideItems = wrapper.findAll('.tab-side')
    await sideItems[0].trigger('click')
    expect(wrapper.emitted('on-switch')).toBeTruthy()
    expect(wrapper.emitted('on-switch')![0]).toEqual(['home'])
  })

  it('点击中间快门应触发 on-switch: capture', async () => {
    const wrapper = mount(FloatingTabBar, {
      props: { current: 'home' },
    })
    const center = wrapper.find('.tab-center')
    await center.trigger('click')
    expect(wrapper.emitted('on-switch')![0]).toEqual(['capture'])
  })

  it('点击我的 Tab 应触发 on-switch: profile', async () => {
    const wrapper = mount(FloatingTabBar, {
      props: { current: 'home' },
    })
    const sideItems = wrapper.findAll('.tab-side')
    await sideItems[1].trigger('click')
    expect(wrapper.emitted('on-switch')![0]).toEqual(['profile'])
  })

  // === LM-NAV-UI-004: 选中态 ===
  it('当前 Tab 应有 active 类', () => {
    const wrapper = mount(FloatingTabBar, {
      props: { current: 'home' },
    })
    const sideItems = wrapper.findAll('.tab-side')
    expect(sideItems[0].classes()).toContain('active')
    expect(sideItems[1].classes()).not.toContain('active')
  })

  it('切换 current prop 后选中态应迁移', async () => {
    const wrapper = mount(FloatingTabBar, {
      props: { current: 'home' },
    })
    await wrapper.setProps({ current: 'profile' })
    const sideItems = wrapper.findAll('.tab-side')
    expect(sideItems[0].classes()).not.toContain('active')
    expect(sideItems[1].classes()).toContain('active')
  })

  // 点击当前已选中 Tab 不应重复触发
  it('点击当前已选中 Tab 不应触发 on-switch', async () => {
    const wrapper = mount(FloatingTabBar, {
      props: { current: 'home' },
    })
    const sideItems = wrapper.findAll('.tab-side')
    await sideItems[0].trigger('click')
    expect(wrapper.emitted('on-switch')).toBeFalsy()
  })

  // === 中间快门按钮 ===
  it('中间项应渲染快门按钮', () => {
    const wrapper = mount(FloatingTabBar, {
      props: { current: 'home' },
    })
    const shutter = wrapper.find('.shutter-btn')
    expect(shutter.exists()).toBe(true)
  })

  it('中间项选中时应有 active 类', async () => {
    const wrapper = mount(FloatingTabBar, {
      props: { current: 'capture' },
    })
    const shutter = wrapper.find('.shutter-btn')
    expect(shutter.classes()).toContain('active')
  })

  // === LM-NAV-UI-006: 深色态 ===
  it('theme=dark 时应有 theme-dark 类', () => {
    const wrapper = mount(FloatingTabBar, {
      props: { current: 'home', theme: 'dark' },
    })
    const container = wrapper.find('.floating-tab-bar')
    expect(container.classes()).toContain('theme-dark')
  })

  it('theme=light 时应有 theme-light 类', () => {
    const wrapper = mount(FloatingTabBar, {
      props: { current: 'home', theme: 'light' },
    })
    const container = wrapper.find('.floating-tab-bar')
    expect(container.classes()).toContain('theme-light')
  })

  it('默认 theme 应为 light', () => {
    const wrapper = mount(FloatingTabBar, {
      props: { current: 'home' },
    })
    const container = wrapper.find('.floating-tab-bar')
    expect(container.classes()).toContain('theme-light')
  })

  // === LM-NAV-UI-005: 点击反馈 ===
  it('Tab 项应可点击', async () => {
    const wrapper = mount(FloatingTabBar, {
      props: { current: 'home' },
    })
    const sideItems = wrapper.findAll('.tab-side')
    await sideItems[1].trigger('click')
    expect(wrapper.emitted('on-switch')).toBeTruthy()
  })

  // === LM-NAV-UI-007: 悬浮定位 ===
  it('容器应存在', () => {
    const wrapper = mount(FloatingTabBar, {
      props: { current: 'home' },
    })
    const container = wrapper.find('.floating-tab-bar')
    expect(container.exists()).toBe(true)
  })

  // === 选中态显示文字 ===
  it('选中的普通 Tab 应显示文字标签', () => {
    const wrapper = mount(FloatingTabBar, {
      props: { current: 'home' },
    })
    const labels = wrapper.findAll('.tab-label')
    expect(labels.length).toBe(1)
  })

  // === 快门外环 ===
  it('快门按钮应有外环', () => {
    const wrapper = mount(FloatingTabBar, {
      props: { current: 'home' },
    })
    const ring = wrapper.find('.shutter-ring')
    expect(ring.exists()).toBe(true)
  })
})

describe('FloatingTabBar Props 验证', () => {
  it('应接受 current prop', () => {
    const wrapper = mount(FloatingTabBar, {
      props: { current: 'profile' },
    })
    expect(wrapper.props('current')).toBe('profile')
  })

  it('应接受 theme prop', () => {
    const wrapper = mount(FloatingTabBar, {
      props: { current: 'home', theme: 'dark' },
    })
    expect(wrapper.props('theme')).toBe('dark')
  })

  it('theme 默认值应为 light', () => {
    const wrapper = mount(FloatingTabBar, {
      props: { current: 'home' },
    })
    expect(wrapper.props('theme')).toBe('light')
  })
})
