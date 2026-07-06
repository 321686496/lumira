/**
 * 拍摄状态仓库
 * 对应前端文档 5.4 capture store
 */
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { CameraParams, AlignmentStatus } from '@/types/camera'
import type { OverlaySettings } from '@/types/overlay'
import type { SceneGuide } from '@/types/template'
import { DEFAULT_CAMERA_PARAMS } from '@/types/camera'

interface CaptureState {
  isActive: boolean
  activeTemplateId: string | null
  overlaySettings: OverlaySettings
  cameraParameters: CameraParams
  sceneGuide: SceneGuide | null
  alignmentStatus: AlignmentStatus
}

export const useCaptureStore = defineStore('capture', () => {
  // === State ===
  const isActive = ref(false)
  const activeTemplateId = ref<string | null>(null)
  const overlaySettings = ref<OverlaySettings>({
    showComposition: true,
    showPose: true,
    opacity: 0.5,
  })
  const cameraParameters = ref<CameraParams>({ ...DEFAULT_CAMERA_PARAMS })
  const sceneGuide = ref<SceneGuide | null>(null)
  const alignmentStatus = ref<AlignmentStatus>({
    isLevel: true,
    subjectAligned: true,
    message: '',
  })

  // === Getters ===
  const hasActiveTemplate = computed(() => activeTemplateId.value !== null)
  const isLevel = computed(() => alignmentStatus.value.isLevel)

  // === Actions ===
  function setActive(active: boolean): void {
    isActive.value = active
  }

  function setActiveTemplate(templateId: string | null): void {
    activeTemplateId.value = templateId
  }

  function updateOverlaySettings(settings: Partial<OverlaySettings>): void {
    overlaySettings.value = { ...overlaySettings.value, ...settings }
  }

  function setOverlayOpacity(opacity: number): void {
    overlaySettings.value = { ...overlaySettings.value, opacity }
  }

  function updateCameraParameters(params: Partial<CameraParams>): void {
    cameraParameters.value = { ...cameraParameters.value, ...params }
  }

  function resetCameraParameters(): void {
    cameraParameters.value = { ...DEFAULT_CAMERA_PARAMS }
  }

  function setSceneGuide(guide: SceneGuide | null): void {
    sceneGuide.value = guide
  }

  function setAlignmentStatus(status: AlignmentStatus): void {
    alignmentStatus.value = status
  }

  function resetState(): void {
    isActive.value = false
    activeTemplateId.value = null
    overlaySettings.value = {
      showComposition: true,
      showPose: true,
      opacity: 0.5,
    }
    cameraParameters.value = { ...DEFAULT_CAMERA_PARAMS }
    sceneGuide.value = null
    alignmentStatus.value = {
      isLevel: true,
      subjectAligned: true,
      message: '',
    }
  }

  return {
    // state
    isActive,
    activeTemplateId,
    overlaySettings,
    cameraParameters,
    sceneGuide,
    alignmentStatus,
    // getters
    hasActiveTemplate,
    isLevel,
    // actions
    setActive,
    setActiveTemplate,
    updateOverlaySettings,
    setOverlayOpacity,
    updateCameraParameters,
    resetCameraParameters,
    setSceneGuide,
    setAlignmentStatus,
    resetState,
  }
})

export type { CaptureState }
