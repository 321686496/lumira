/**
 * 成长体系组合式函数
 *
 * 基于实际拍摄照片计算用户等级、XP、成就、成长轨迹与拍摄日历。
 * 所有数据从 useSceneManager 的 photos 派生，无需额外存储。
 */

import { computed } from 'vue'
import { useSceneManager } from './useSceneManager'
import { useTemplate } from './useTemplate'

/** 等级阈值表 */
const LEVEL_THRESHOLDS = [
  { level: 1, name: '初学者', xp: 0 },
  { level: 2, name: '入门学徒', xp: 100 },
  { level: 3, name: '进阶学徒', xp: 300 },
  { level: 4, name: '熟练学徒', xp: 600 },
  { level: 5, name: '摄影新手', xp: 1000 },
  { level: 6, name: '摄影爱好者', xp: 1500 },
  { level: 7, name: '摄影达人', xp: 2200 },
  { level: 8, name: '构图能手', xp: 3000 },
  { level: 9, name: '光影大师', xp: 4000 },
  { level: 10, name: '摄影专家', xp: 5500 },
  { level: 11, name: '摄影艺术家', xp: 7500 },
  { level: 12, name: '视觉创作者', xp: 10000 },
]

/** 每张照片获得的基础 XP */
const XP_PER_PHOTO = 15
/** 使用模板额外 XP */
const XP_PER_TEMPLATE_USE = 10
/** 使用场景额外 XP */
const XP_PER_SCENE_USE = 5

export interface Achievement {
  id: string
  icon: string
  name: string
  desc: string
  locked: boolean
  progress: number
  target: number
}

export interface TrajectoryItem {
  title: string
  date: string
  timestamp: number
}

export interface GrowthData {
  level: number
  levelName: string
  currentXp: number
  nextLevelXp: number
  progressPercent: number
  remainingXp: number
}

export function useGrowth() {
  const { photos, allScenes, getPhotoCountByScene } = useSceneManager()
  const { getAllTemplates, getCustomTemplateCount } = useTemplate()

  /** 计算总 XP */
  const totalXp = computed(() => {
    let xp = 0
    photos.value.forEach(p => {
      xp += XP_PER_PHOTO
      if (p.templateId) xp += XP_PER_TEMPLATE_USE
      if (p.sceneId) xp += XP_PER_SCENE_USE
    })
    return xp
  })

  /** 当前等级数据 */
  const growthData = computed<GrowthData>(() => {
    const xp = totalXp.value
    let currentLevel = LEVEL_THRESHOLDS[0]
    let nextLevel = LEVEL_THRESHOLDS[1]

    for (let i = 0; i < LEVEL_THRESHOLDS.length; i++) {
      if (xp >= LEVEL_THRESHOLDS[i].xp) {
        currentLevel = LEVEL_THRESHOLDS[i]
        nextLevel = LEVEL_THRESHOLDS[i + 1] || LEVEL_THRESHOLDS[i]
      } else {
        break
      }
    }

    const progressPercent = nextLevel === currentLevel
      ? 100
      : Math.round(((xp - currentLevel.xp) / (nextLevel.xp - currentLevel.xp)) * 100)
    const remainingXp = nextLevel.xp - xp

    return {
      level: currentLevel.level,
      levelName: currentLevel.name,
      currentXp: xp,
      nextLevelXp: nextLevel.xp,
      progressPercent: Math.min(100, Math.max(0, progressPercent)),
      remainingXp: Math.max(0, remainingXp),
    }
  })

  /** 成就列表（基于真实数据计算） */
  const achievements = computed<Achievement[]>(() => {
    const photoCount = photos.value.length
    const templateCount = getAllTemplates().length + getCustomTemplateCount()
    const sceneCount = allScenes.value.length
    const usedScenes = new Set(photos.value.map(p => p.sceneId).filter(Boolean)).size
    const usedTemplates = new Set(photos.value.map(p => p.templateId).filter(Boolean)).size
    const streak = currentStreak.value

    return [
      {
        id: 'first_photo',
        icon: 'ph-sunrise',
        name: '初露锋芒',
        desc: '拍摄第一张照片',
        locked: photoCount < 1,
        progress: Math.min(photoCount, 1),
        target: 1,
      },
      {
        id: 'shutter_master',
        icon: 'ph-camera',
        name: '快门达人',
        desc: '拍摄 10 张照片',
        locked: photoCount < 10,
        progress: Math.min(photoCount, 10),
        target: 10,
      },
      {
        id: 'template_collector',
        icon: 'ph-stack',
        name: '模板收藏家',
        desc: '使用 5 个不同模板',
        locked: usedTemplates < 5,
        progress: Math.min(usedTemplates, 5),
        target: 5,
      },
      {
        id: 'scene_explorer',
        icon: 'ph-compass',
        name: '场景探索者',
        desc: '在 5 个不同场景拍摄',
        locked: usedScenes < 5,
        progress: Math.min(usedScenes, 5),
        target: 5,
      },
      {
        id: 'streak_7',
        icon: 'ph-fire',
        name: '坚持一周',
        desc: '连续 7 天拍摄',
        locked: streak < 7,
        progress: Math.min(streak, 7),
        target: 7,
      },
      {
        id: 'century',
        icon: 'ph-trophy',
        name: '百张成就',
        desc: '拍摄 100 张照片',
        locked: photoCount < 100,
        progress: Math.min(photoCount, 100),
        target: 100,
      },
    ]
  })

  /** 已解锁成就数 */
  const unlockedAchievementCount = computed(() => {
    return achievements.value.filter(a => !a.locked).length
  })

  /** 成长轨迹（基于照片里程碑） */
  const trajectory = computed<TrajectoryItem[]>(() => {
    const sortedPhotos = [...photos.value].sort((a, b) => a.createdAt - b.createdAt)
    if (sortedPhotos.length === 0) return []

    const milestones: TrajectoryItem[] = []
    const first = sortedPhotos[0]
    milestones.push({
      title: '首张照片',
      date: formatDate(first.createdAt),
      timestamp: first.createdAt,
    })

    if (sortedPhotos.length >= 10) {
      const tenth = sortedPhotos[9]
      milestones.push({
        title: '10 张照片',
        date: formatDate(tenth.createdAt),
        timestamp: tenth.createdAt,
      })
    }

    // 等级提升节点
    const xp = totalXp.value
    for (const lv of LEVEL_THRESHOLDS) {
      if (xp >= lv.xp && lv.level >= 5) {
        // 找到达到该等级时的照片
        let accXp = 0
        for (const p of sortedPhotos) {
          accXp += XP_PER_PHOTO
          if (p.templateId) accXp += XP_PER_TEMPLATE_USE
          if (p.sceneId) accXp += XP_PER_SCENE_USE
          if (accXp >= lv.xp) {
            milestones.push({
              title: `升至 Lv.${lv.level} ${lv.name}`,
              date: formatDate(p.createdAt),
              timestamp: p.createdAt,
            })
            break
          }
        }
      }
    }

    if (sortedPhotos.length >= 50) {
      const fiftieth = sortedPhotos[49]
      milestones.push({
        title: '50 张照片',
        date: formatDate(fiftieth.createdAt),
        timestamp: fiftieth.createdAt,
      })
    }

    if (sortedPhotos.length >= 100) {
      const hundredth = sortedPhotos[99]
      milestones.push({
        title: '100 张照片',
        date: formatDate(hundredth.createdAt),
        timestamp: hundredth.createdAt,
      })
    }

    // 去重 + 按时间排序
    const seen = new Set<string>()
    const unique = milestones.filter(m => {
      if (seen.has(m.title)) return false
      seen.add(m.title)
      return true
    })
    unique.sort((a, b) => a.timestamp - b.timestamp)
    return unique
  })

  /** 拍摄日历热力图（最近 42 天） */
  const heatmap = computed<number[]>(() => {
    const days: number[] = []
    const now = new Date()
    for (let i = 41; i >= 0; i--) {
      const date = new Date(now)
      date.setDate(date.getDate() - i)
      date.setHours(0, 0, 0, 0)
      const nextDate = new Date(date)
      nextDate.setDate(nextDate.getDate() + 1)
      const count = photos.value.filter(p => {
        return p.createdAt >= date.getTime() && p.createdAt < nextDate.getTime()
      }).length
      if (count === 0) days.push(0)
      else if (count <= 1) days.push(1)
      else if (count <= 3) days.push(2)
      else if (count <= 5) days.push(3)
      else days.push(4)
    }
    return days
  })

  /** 本月拍摄数 */
  const monthPhotoCount = computed(() => {
    const now = new Date()
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).getTime()
    return photos.value.filter(p => p.createdAt >= monthStart).length
  })

  /** 当前连续打卡天数 */
  const currentStreak = computed(() => {
    if (photos.value.length === 0) return 0
    const sortedDates = photos.value
      .map(p => {
        const d = new Date(p.createdAt)
        d.setHours(0, 0, 0, 0)
        return d.getTime()
      })
      .sort((a, b) => b - a)

    const uniqueDates = [...new Set(sortedDates)]
    const today = new Date()
    today.setHours(0, 0, 0, 0)

    // 如果今天没拍，从昨天开始算
    let checkDate = today
    if (uniqueDates[0] !== today.getTime()) {
      const yesterday = new Date(today)
      yesterday.setDate(yesterday.getDate() - 1)
      if (uniqueDates[0] !== yesterday.getTime()) return 0
      checkDate = yesterday
    }

    let streak = 0
    for (const d of uniqueDates) {
      if (d === checkDate.getTime()) {
        streak++
        checkDate = new Date(checkDate)
        checkDate.setDate(checkDate.getDate() - 1)
      } else if (d < checkDate.getTime()) {
        break
      }
    }
    return streak
  })

  /** 统计：拍摄作品数 */
  const totalPhotos = computed(() => photos.value.length)

  /** 统计：使用模板数（不同模板数） */
  const usedTemplateCount = computed(() => {
    return new Set(photos.value.map(p => p.templateId).filter(Boolean)).size
  })

  /** 统计：收藏数（场景收藏数） */
  const favoriteCount = computed(() => {
    return allScenes.value.filter(s => getPhotoCountByScene(s.id) > 0).length
  })

  return {
    growthData,
    achievements,
    unlockedAchievementCount,
    trajectory,
    heatmap,
    monthPhotoCount,
    currentStreak,
    totalPhotos,
    usedTemplateCount,
    favoriteCount,
    totalXp,
  }
}

/** 格式化日期为 YYYY-MM-DD */
function formatDate(timestamp: number): string {
  const d = new Date(timestamp)
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}
