import { computed } from 'vue'
import { useSceneManager } from './useSceneManager'
import { useTemplate } from './useTemplate'
import type { PhotoTemplate, Target } from '@/types/template'

export interface TemplateRecommendation {
  template: PhotoTemplate
  reason: string
  score: number
  source: 'recent_used' | 'scene_match' | 'category_match' | 'system_pick'
}

export interface UserPreference {
  totalPhotos: number
  topCategory: Target | null
  topCategoryPercentage: number
}

export function useRecommendation() {
  const { photos, allScenes } = useSceneManager()
  const { getAllTemplates, recentTemplates } = useTemplate()

  /** 近 30 天模板使用频次 */
  const templateUsageCount = computed<Record<string, number>>(() => {
    const counts: Record<string, number> = {}
    const now = Date.now()
    const thirtyDaysAgo = now - 30 * 24 * 60 * 60 * 1000
    photos.value.forEach(p => {
      if (p.templateId && p.createdAt > thirtyDaysAgo) {
        counts[p.templateId] = (counts[p.templateId] || 0) + 1
      }
    })
    return counts
  })

  /** 用户最常用分类（基于全部照片） */
  const topCategory = computed<Target | null>(() => {
    const counts: Partial<Record<Target, number>> = {}
    const all = getAllTemplates()
    photos.value.forEach(p => {
      if (p.templateId) {
        const tpl = all.find(t => t.meta.id === p.templateId)
        if (tpl?.meta.category) {
          counts[tpl.meta.category] = (counts[tpl.meta.category] || 0) + 1
        }
      }
    })
    let top: Target | null = null
    let max = 0
    Object.entries(counts).forEach(([cat, n]) => {
      if (n && n > max) { max = n; top = cat as Target }
    })
    return top
  })

  /** 用户最常拍的场景 */
  const topScene = computed(() => {
    const counts: Record<string, number> = {}
    photos.value.forEach(p => {
      if (p.sceneId) {
        counts[p.sceneId] = (counts[p.sceneId] || 0) + 1
      }
    })
    let topId: string | null = null
    let max = 0
    Object.entries(counts).forEach(([id, n]) => {
      if (n > max) { max = n; topId = id }
    })
    if (!topId) return null
    return allScenes.value.find(s => s.id === topId) || null
  })

  /** 时间段系统精选模板 ID */
  const systemPick = computed<string>(() => {
    const hour = new Date().getHours()
    if (hour >= 6 && hour < 10) return 'golden_landscape'
    if (hour >= 10 && hour < 16) return 'food_flat_lay'
    if (hour >= 16 && hour < 19) return 'sunset_silhouette'
    if (hour >= 19) return 'night_cityscape'
    return 'soft_portrait'
  })

  /** 获取推荐模板列表 */
  function getRecommendedTemplates(limit = 6): TemplateRecommendation[] {
    const all = getAllTemplates()
    const recs: TemplateRecommendation[] = []

    // 1. 近期使用最多的模板（权重 35 + 使用次数×2）
    Object.entries(templateUsageCount.value)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .forEach(([id, count]) => {
        const tpl = all.find(t => t.meta.id === id)
        if (tpl) {
          recs.push({
            template: tpl,
            reason: `你最近经常使用此模板（${count} 次）`,
            score: 35 + count * 2,
            source: 'recent_used'
          })
        }
      })

    // 2. recentTemplates 兜底（最近使用过但未在频次 Top 3 中）
    recentTemplates.value.slice(0, 3).forEach((tpl, idx) => {
      if (!recs.find(r => r.template.meta.id === tpl.meta.id)) {
        recs.push({
          template: tpl,
          reason: '最近使用过',
          score: 30 - idx * 5,
          source: 'recent_used'
        })
      }
    })

    // 3. 当前用户最常拍场景的推荐标签匹配（权重 25 + 重合数×3）
    const scene = topScene.value
    if (scene) {
      const sceneTagIds = scene.recommendedTagIds || []
      all.forEach(tpl => {
        if (recs.find(r => r.template.meta.id === tpl.meta.id)) return
        const overlap = (tpl.meta.tagIds || []).filter(id => sceneTagIds.includes(id)).length
        if (overlap > 0) {
          recs.push({
            template: tpl,
            reason: `与「${scene.name}」场景匹配`,
            score: 25 + overlap * 3,
            source: 'scene_match'
          })
        }
      })
    }

    // 4. 同分类未使用模板（权重 20）
    if (topCategory.value) {
      const unused = all.filter(t =>
        t.meta.category === topCategory.value &&
        !recs.find(r => r.template.meta.id === t.meta.id)
      )
      unused.slice(0, 2).forEach(tpl => {
        recs.push({
          template: tpl,
          reason: `同分类推荐（你常用 ${topCategory.value}）`,
          score: 20,
          source: 'category_match'
        })
      })
    }

    // 5. 系统精选（权重 20，按时间段）
    const sysPickTpl = all.find(t => t.meta.id === systemPick.value)
    if (sysPickTpl && !recs.find(r => r.template.meta.id === sysPickTpl.meta.id)) {
      recs.push({
        template: sysPickTpl,
        reason: '根据当前时间段推荐',
        score: 20,
        source: 'system_pick'
      })
    }

    // 按分数降序取 Top N
    recs.sort((a, b) => b.score - a.score)
    return recs.slice(0, limit)
  }

  /** 获取未被推荐的其他模板 */
  function getOtherTemplates(excludeIds: string[]): PhotoTemplate[] {
    const all = getAllTemplates()
    return all.filter(t => !excludeIds.includes(t.meta.id))
  }

  /** 用户偏好统计 */
  const userPreference = computed<UserPreference>(() => {
    const total = photos.value.length
    const topCat = topCategory.value
    const topCatCount = photos.value.filter(p => {
      const tpl = getAllTemplates().find(t => t.meta.id === p.templateId)
      return tpl?.meta.category === topCat
    }).length
    const percentage = total > 0 ? Math.round((topCatCount / total) * 100) : 0
    return {
      totalPhotos: total,
      topCategory: topCat,
      topCategoryPercentage: percentage
    }
  })

  return {
    getRecommendedTemplates,
    getOtherTemplates,
    userPreference
  }
}
