/**
 * 叠图渲染组合式逻辑
 */
import { ref, computed } from 'vue'
import type { OverlayLayer, OverlaySettings } from '@/types/overlay'
import type { CompositionOverlay, PoseReference } from '@/types/template'
import { useCaptureStore } from '@/stores/capture'

export function useOverlay() {
  const store = useCaptureStore()

  const overlayLayer = ref<OverlayLayer>({
    composition: undefined,
    pose: undefined,
    opacity: store.overlaySettings.opacity,
    visible: true,
  })

  const isVisible = computed(() => overlayLayer.value.visible)
  const opacity = computed(() => overlayLayer.value.opacity)
  const settings = computed(() => store.overlaySettings)

  function setComposition(composition: CompositionOverlay | undefined): void {
    overlayLayer.value.composition = composition
      ? {
          type: composition.overlayType,
          lines: [],
          subjectFrame: composition.subjectFrame,
          color: '#C9A96E',
        }
      : undefined
  }

  function setPose(pose: PoseReference | undefined): void {
    overlayLayer.value.pose = pose
      ? {
          imageUrl: pose.referenceImage || pose.silhouetteUrl || '',
          position: pose.position || { x: 0.5, y: 0.5 },
          scale: pose.scale || 1,
          rotation: pose.rotation || 0,
        }
      : undefined
  }

  function setOpacity(value: number): void {
    const clamped = Math.max(0, Math.min(1, value))
    overlayLayer.value.opacity = clamped
    store.setOverlayOpacity(clamped)
  }

  function toggleVisible(): void {
    overlayLayer.value.visible = !overlayLayer.value.visible
  }

  function updateSettings(newSettings: Partial<OverlaySettings>): void {
    store.updateOverlaySettings(newSettings)
    if (newSettings.opacity !== undefined) {
      overlayLayer.value.opacity = newSettings.opacity
    }
  }

  function reset(): void {
    overlayLayer.value = {
      composition: undefined,
      pose: undefined,
      opacity: 0.5,
      visible: true,
    }
  }

  return {
    overlayLayer,
    isVisible,
    opacity,
    settings,
    setComposition,
    setPose,
    setOpacity,
    toggleVisible,
    updateSettings,
    reset,
  }
}
