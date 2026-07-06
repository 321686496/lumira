/**
 * 相册状态仓库
 * 对应前端文档 5.4 gallery store
 */
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { LocalPhoto, EditAction } from '@/types/photo'
import { storageService } from '@/services/storage'
import { generateId } from '@/utils/math'

export const useGalleryStore = defineStore('gallery', () => {
  // === State ===
  const photos = ref<LocalPhoto[]>([])
  const currentPhotoId = ref<string | null>(null)
  const editingHistory = ref<EditAction[]>([])
  const loading = ref(false)

  // === Getters ===
  const currentPhoto = computed(() =>
    photos.value.find((p) => p.id === currentPhotoId.value) ?? null,
  )
  const photoCount = computed(() => photos.value.length)
  const hasPhotos = computed(() => photos.value.length > 0)

  // === Actions ===
  async function loadPhotos(): Promise<void> {
    loading.value = true
    try {
      photos.value = await storageService.getAllPhotos()
    } finally {
      loading.value = false
    }
  }

  async function addPhoto(photo: Omit<LocalPhoto, 'id' | 'createdAt'>): Promise<string> {
    const id = generateId('photo')
    const newPhoto: LocalPhoto = {
      ...photo,
      id,
      createdAt: Date.now(),
    }
    await storageService.insertPhoto(newPhoto)
    photos.value.unshift(newPhoto)
    return id
  }

  async function updatePhoto(photo: LocalPhoto): Promise<void> {
    await storageService.updatePhoto(photo)
    const index = photos.value.findIndex((p) => p.id === photo.id)
    if (index >= 0) {
      photos.value[index] = photo
    }
  }

  async function deletePhoto(id: string): Promise<void> {
    await storageService.deletePhoto(id)
    photos.value = photos.value.filter((p) => p.id !== id)
    if (currentPhotoId.value === id) {
      currentPhotoId.value = null
    }
  }

  function setCurrentPhoto(id: string | null): void {
    currentPhotoId.value = id
  }

  function pushEditAction(action: EditAction): void {
    editingHistory.value.push(action)
  }

  function popEditAction(): EditAction | undefined {
    return editingHistory.value.pop()
  }

  function clearEditingHistory(): void {
    editingHistory.value = []
  }

  function resetState(): void {
    photos.value = []
    currentPhotoId.value = null
    editingHistory.value = []
    loading.value = false
  }

  return {
    // state
    photos,
    currentPhotoId,
    editingHistory,
    loading,
    // getters
    currentPhoto,
    photoCount,
    hasPhotos,
    // actions
    loadPhotos,
    addPhoto,
    updatePhoto,
    deletePhoto,
    setCurrentPhoto,
    pushEditAction,
    popEditAction,
    clearEditingHistory,
    resetState,
  }
})
