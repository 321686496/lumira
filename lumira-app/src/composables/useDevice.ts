/**
 * 设备信息/传感器组合式逻辑
 */
import { ref, onMounted, onUnmounted } from 'vue'

export function useDevice() {
  const deviceLevel = ref(0)
  const deviceOrientation = ref<'portrait' | 'landscape'>('portrait')
  const isLevel = ref(false)

  let intervalId: ReturnType<typeof setInterval> | null = null

  function startLevelDetection(): void {
    // Mock：定时更新水平检测
    // 真实环境使用 uni.startAccelerometer / uni.onAccelerometerChange
    intervalId = setInterval(() => {
      deviceLevel.value = (Math.random() - 0.5) * 2
      isLevel.value = Math.abs(deviceLevel.value) < 0.5
    }, 200)
  }

  function stopLevelDetection(): void {
    if (intervalId) {
      clearInterval(intervalId)
      intervalId = null
    }
  }

  function getDeviceId(): Promise<string> {
    return Promise.resolve(`device_${Date.now().toString(36)}`)
  }

  function getSystemInfo(): Promise<{ platform: string; pixelRatio: number; windowWidth: number; windowHeight: number }> {
    return Promise.resolve({
      platform: 'mock',
      pixelRatio: 2,
      windowWidth: 375,
      windowHeight: 812,
    })
  }

  onMounted(() => {
    // 可选：自动开始检测
  })

  onUnmounted(() => {
    stopLevelDetection()
  })

  return {
    deviceLevel,
    deviceOrientation,
    isLevel,
    startLevelDetection,
    stopLevelDetection,
    getDeviceId,
    getSystemInfo,
  }
}
