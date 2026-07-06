/**
 * 相册管理组合式逻辑
 */
import { ref, computed } from 'vue'
import { useGalleryStore } from '@/stores/gallery'
import type { LocalPhoto } from '@/types/photo'

export function useGallery() {
  const store = useGalleryStore()
  const loading = computed(() => store.loading)
  const photos = computed(() => store.photos)
  const photoCount = computed(() => store.photoCount)
  const hasPhotos = computed(() => store.hasPhotos)
  const currentPhoto = computed(() => store.currentPhoto)

  async function loadPhotos(): Promise<void> {
    await store.loadPhotos()
  }

  async function addPhoto(photo: Omit<LocalPhoto, 'id' | 'createdAt'>): Promise<string> {
    return store.addPhoto(photo)
  }

  async function deletePhoto(id: string): Promise<void> {
    await store.deletePhoto(id)
  }

  function selectPhoto(id: string): void {
    store.setCurrentPhoto(id)
  }

  function getPhotoById(id: string): LocalPhoto | undefined {
    return store.photos.find((p) => p.id === id)
  }

  return {
    loading,
    photos,
    photoCount,
    hasPhotos,
    currentPhoto,
    loadPhotos,
    addPhoto,
    deletePhoto,
    selectPhoto,
    getPhotoById,
  }
}
