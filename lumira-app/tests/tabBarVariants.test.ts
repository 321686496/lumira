/**
 * TabBar 变体组件测试
 * 验证 3 个变体共享相同的 props/emits 契约
 */
import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import TabBarFloating from '@/components/tabbar/TabBarFloating.vue'

describe('TabBarFloating 组件', () => {
  it('应渲染容器', () => {
    const wrapper = mount(TabBarFloating, { props: { current: 'home' } })
    expect(wrapper.find('.tab-bar-floating').exists()).toBe(true)
  })

  it('应渲染 2 个侧边 Tab + 1 个快门', () => {
    const wrapper = mount(TabBarFloating, { props: { current: 'home' } })
    expect(wrapper.findAll('.tab-side')).toHaveLength(2)
    expect(wrapper.find('.shutter-btn').exists()).toBe(true)
  })

  it('点击首页 Tab 应触发 on-switch: home', async () => {
    const wrapper = mount(TabBarFloating, { props: { current: 'profile' } })
    await wrapper.findAll('.tab-side')[0].trigger('click')
    expect(wrapper.emitted('on-switch')![0]).toEqual(['home'])
  })

  it('点击快门应触发 on-switch: capture', async () => {
    const wrapper = mount(TabBarFloating, { props: { current: 'home' } })
    await wrapper.find('.tab-center').trigger('click')
    expect(wrapper.emitted('on-switch')![0]).toEqual(['capture'])
  })

  it('点击我的 Tab 应触发 on-switch: profile', async () => {
    const wrapper = mount(TabBarFloating, { props: { current: 'home' } })
    await wrapper.findAll('.tab-side')[1].trigger('click')
    expect(wrapper.emitted('on-switch')![0]).toEqual(['profile'])
  })

  it('点击当前已选中 Tab 不应触发 on-switch', async () => {
    const wrapper = mount(TabBarFloating, { props: { current: 'home' } })
    await wrapper.findAll('.tab-side')[0].trigger('click')
    expect(wrapper.emitted('on-switch')).toBeFalsy()
  })

  it('点击快门即使已选中也应触发（center 总是触发）', async () => {
    const wrapper = mount(TabBarFloating, { props: { current: 'capture' } })
    await wrapper.find('.tab-center').trigger('click')
    expect(wrapper.emitted('on-switch')).toBeTruthy()
  })

  it('默认 theme 应为 light', () => {
    const wrapper = mount(TabBarFloating, { props: { current: 'home' } })
    expect(wrapper.props('theme')).toBe('light')
    expect(wrapper.find('.tab-bar-floating').classes()).toContain('theme-light')
  })

  it('theme=dark 时应有 theme-dark 类', () => {
    const wrapper = mount(TabBarFloating, { props: { current: 'home', theme: 'dark' } })
    expect(wrapper.find('.tab-bar-floating').classes()).toContain('theme-dark')
  })
})
