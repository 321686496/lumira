import { computed } from 'vue'
import { useSceneManager } from './useSceneManager'
import { useTemplate } from './useTemplate'
import type { ScenePresetId, CustomSceneId } from '@/types/template'

export interface ShootingTip {
  text: string
  sub?: string
  sceneName: string
  source: 'recent_scene' | 'recent_template' | 'time_match' | 'fallback'
  priority: number
}

const FALLBACK_TIPS: ShootingTip[] = [
  { text: '侧逆光人像：让模特侧向镜头，让自然光从侧面打在脸上，显瘦又自然。', sub: '— 适合午后窗边或户外树下', sceneName: '通用', source: 'fallback', priority: 5 },
  { text: '黄金时刻：日出后或日落前 1 小时，光线柔和暖黄，适合拍摄人像与风光。', sub: '— 注意提前踩点', sceneName: '通用', source: 'fallback', priority: 5 },
  { text: '三分构图：将主体放在画面九宫格交叉点上，让画面更平衡有张力。', sub: '— 适合所有场景', sceneName: '通用', source: 'fallback', priority: 5 },
  { text: '前景遮挡：用花草、树叶、玻璃等作为前景，增加画面层次感。', sub: '— 适合静物与人像', sceneName: '通用', source: 'fallback', priority: 5 }
]

export function useShootingTip() {
  const { photos, allScenes } = useSceneManager()
  const { getAllTemplates, recentTemplates } = useTemplate()

  /** 近 30 天场景使用频次 */
  const sceneUsage = computed<Record<string, number>>(() => {
    const counts: Record<string, number> = {}
    const now = Date.now()
    const thirtyDaysAgo = now - 30 * 24 * 60 * 60 * 1000
    photos.value.forEach(p => {
      if (p.sceneId && p.createdAt > thirtyDaysAgo) {
        counts[p.sceneId] = (counts[p.sceneId] || 0) + 1
      }
    })
    return counts
  })

  /** 用户近 30 天最常拍场景 */
  const topScene = computed<{ scene: typeof allScenes.value[number]; count: number } | null>(() => {
    const entries = Object.entries(sceneUsage.value)
    if (entries.length === 0) return null
    entries.sort((a, b) => b[1] - a[1])
    const [id, count] = entries[0]
    const scene = allScenes.value.find(s => s.id === id)
    return scene ? { scene, count } : null
  })

  /** 获取当前贴士 */
  function getShootingTip(): ShootingTip {
    const candidates: ShootingTip[] = []

    // 1. 近期最常用场景的 tips
    if (topScene.value && topScene.value.scene.tips?.length > 0) {
      const tips = topScene.value.scene.tips
      const tip = tips[Math.floor(Math.random() * tips.length)]
      candidates.push({
        text: tip,
        sub: `— 基于你最近常拍「${topScene.value.scene.name}」`,
        sceneName: topScene.value.scene.name,
        source: 'recent_scene',
        priority: 35
      })
    }

    // 2. 近期最常用模板关联场景的 tips
    const recentTpl = recentTemplates.value[0]
    if (recentTpl) {
      // 通过模板的 sceneGuide.presetId 关联场景预设
      const presetId = recentTpl.sceneGuide?.presetId
      if (presetId) {
        const preset = allScenes.value.find(s => s.id === presetId)
        if (preset?.tips?.length) {
          const tip = preset.tips[Math.floor(Math.random() * preset.tips.length)]
          candidates.push({
            text: tip,
            sub: `— 基于你最近使用「${recentTpl.meta.name}」模板`,
            sceneName: preset.name,
            source: 'recent_template',
            priority: 25
          })
        }
      }
    }

    // 3. 时间段贴士
    const hour = new Date().getHours()
    if (hour >= 6 && hour < 10) {
      candidates.push({
        text: '清晨黄金时刻：光线柔和暖黄，适合拍人像与风光。',
        sub: '— 当前时段推荐',
        sceneName: '通用',
        source: 'time_match',
        priority: 15
      })
    } else if (hour >= 16 && hour < 19) {
      candidates.push({
        text: '黄昏黄金时刻：日落前 1 小时光线最美，提前踩点。',
        sub: '— 当前时段推荐',
        sceneName: '通用',
        source: 'time_match',
        priority: 15
      })
    } else if (hour >= 19) {
      candidates.push({
        text: '夜景拍摄：使用三脚架或稳定支撑，降低 ISO，延长曝光时间。',
        sub: '— 当前时段推荐',
        sceneName: '通用',
        source: 'time_match',
        priority: 15
      })
    }

    // 4. 兜底（无任何匹配时）
    if (candidates.length === 0) {
      candidates.push(FALLBACK_TIPS[Math.floor(Math.random() * FALLBACK_TIPS.length)])
    }

    // 按 priority 降序 + 随机扰动（同 priority 之间随机）
    candidates.sort((a, b) => (b.priority - a.priority) + (Math.random() - 0.5) * 10)
    return candidates[0]
  }

  /** 获取所有候选贴士（供"换一批"使用） */
  function getAllCandidateTips(): ShootingTip[] {
    const tips: ShootingTip[] = []
    if (topScene.value && topScene.value.scene.tips?.length > 0) {
      topScene.value.scene.tips.forEach(t => tips.push({
        text: t,
        sub: `— 基于你最近常拍「${topScene.value!.scene.name}」`,
        sceneName: topScene.value!.scene.name,
        source: 'recent_scene',
        priority: 35
      }))
    }
    FALLBACK_TIPS.forEach(t => tips.push({ ...t }))
    return tips
  }

  /** 切换到下一个贴士（不重复当前） */
  function getNextShootingTip(current: ShootingTip): ShootingTip {
    const all = getAllCandidateTips()
    const others = all.filter(t => t.text !== current.text)
    return others.length > 0 ? others[Math.floor(Math.random() * others.length)] : current
  }

  return {
    getShootingTip,
    getNextShootingTip
  }
}
