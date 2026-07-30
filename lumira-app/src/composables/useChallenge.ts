/**
 * 每日挑战组合式函数
 *
 * 基于当前日期生成每日挑战，跟踪完成状态，持久化到 localStorage。
 * 挑战内容从内置模板和场景预设中选取，确保每日不同且有连续性。
 */

import { ref, computed } from 'vue'
import { BUILTIN_TEMPLATES } from '@/data/templates'
import { SCENE_PRESETS } from '@/data/scenePresets'
import type { PhotoTemplate, ScenePreset, Target } from '@/types/template'

const CHALLENGE_KEY = 'lumira_daily_challenge'

interface ChallengeState {
  /** 日期标记 YYYY-MM-DD */
  date: string
  /** 主挑战 */
  mainChallenge: DailyChallenge
  /** 附加挑战 */
  subChallenges: DailyChallenge[]
  /** 明日预览 */
  tomorrowPreview: { title: string; desc: string }
  /** 完成的挑战 id 列表 */
  completed: string[]
  /** 历史连续打卡日期 */
  streakDates: string[]
}

export interface DailyChallenge {
  id: string
  title: string
  desc: string
  xp: number
  type: 'main' | 'sub_a' | 'sub_b'
  /** 关联模板 id（如果有） */
  templateId?: string
  /** 关联场景 id（如果有） */
  sceneId?: string
  /** 是否有碎片奖励 */
  hasFragment?: boolean
  /** 完成条件描述 */
  condition: string
}

/** 基于日期生成确定性随机种子 */
function dateSeed(date: string): number {
  let hash = 0
  for (let i = 0; i < date.length; i++) {
    hash = ((hash << 5) - hash) + date.charCodeAt(i)
    hash |= 0
  }
  return Math.abs(hash)
}

/** 格式化日期为 YYYY-MM-DD */
function formatDate(d: Date): string {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

/** 基于种子选取 */
function pickBySeed<T>(arr: T[], seed: number, offset: number): T {
  const idx = (seed + offset) % arr.length
  return arr[idx]
}

/** 生成指定日期的挑战 */
function generateChallenges(dateStr: string): Omit<ChallengeState, 'completed' | 'streakDates'> {
  const seed = dateSeed(dateStr)
  const templates = BUILTIN_TEMPLATES.filter(t => t.meta.price === 0)
  const scenes = SCENE_PRESETS

  const mainTemplate = pickBySeed(templates, seed, 0)
  const subTemplateA = pickBySeed(templates, seed, 1)
  const subSceneB = pickBySeed(scenes, seed, 2)
  const tomorrowTemplate = pickBySeed(templates, seed, 3)

  const mainChallenge: DailyChallenge = {
    id: `main_${dateStr}`,
    title: `用「${mainTemplate.meta.name}」模板拍一张照片`,
    desc: mainTemplate.meta.description || `使用${mainTemplate.meta.name}模板完成拍摄`,
    xp: 30,
    type: 'main',
    templateId: mainTemplate.meta.id,
    condition: '拍摄 1 张照片',
  }

  const subA: DailyChallenge = {
    id: `sub_a_${dateStr}`,
    title: `尝试 ${2 + (seed % 3)} 个不同模板各拍一张`,
    desc: '探索不同风格的拍摄模板',
    xp: 15,
    type: 'sub_a',
    condition: `拍摄 ${2 + (seed % 3)} 张不同模板的照片`,
  }

  const subB: DailyChallenge = {
    id: `sub_b_${dateStr}`,
    title: `在「${subSceneB.name}」场景拍一张照片`,
    desc: subSceneB.vibe || subSceneB.description,
    xp: 20,
    type: 'sub_b',
    sceneId: subSceneB.id,
    hasFragment: true,
    condition: '拍摄 1 张照片并完成调色导出',
  }

  const tomorrowPreview = {
    title: `用「${tomorrowTemplate.meta.name}」模板创作`,
    desc: `附加挑战：在${pickBySeed(scenes, seed, 4).name}场景拍摄`,
  }

  return {
    date: dateStr,
    mainChallenge,
    subChallenges: [subA, subB],
    tomorrowPreview,
  }
}

/** 从 localStorage 加载状态 */
function loadState(): ChallengeState | null {
  try {
    const raw = uni.getStorageSync(CHALLENGE_KEY)
    if (!raw) return null
    return typeof raw === 'string' ? JSON.parse(raw) : raw
  } catch {
    return null
  }
}

/** 保存状态到 localStorage */
function saveState(state: ChallengeState): void {
  try {
    uni.setStorageSync(CHALLENGE_KEY, state)
  } catch {
    // 忽略
  }
}

const today = formatDate(new Date())
const yesterday = formatDate(new Date(Date.now() - 86400000))

/** 模块级单例状态 */
const loadedState = loadState()
const state = ref<ChallengeState>(
  loadedState && loadedState.date === today
    ? loadedState
    : (() => {
        // 新的一天：继承昨天的 streakDates
        const prevStreakDates = loadedState?.streakDates || []
        const fresh = generateChallenges(today)
        const newState: ChallengeState = {
          ...fresh,
          completed: [],
          streakDates: prevStreakDates,
        }
        saveState(newState)
        return newState
      })()
)

export function useChallenge() {
  const mainChallenge = computed(() => state.value.mainChallenge)
  const subChallenges = computed(() => state.value.subChallenges)
  const tomorrowPreview = computed(() => state.value.tomorrowPreview)
  const completedIds = computed(() => state.value.completed)

  /** 主挑战是否已完成 */
  const mainCompleted = computed(() => state.value.completed.includes(state.value.mainChallenge.id))

  /** 附加挑战完成状态 */
  const subStatuses = computed(() =>
    state.value.subChallenges.map(c => ({
      challenge: c,
      done: state.value.completed.includes(c.id),
    }))
  )

  /** 全部挑战数 */
  const totalChallenges = computed(() => 1 + state.value.subChallenges.length)

  /** 已完成挑战数 */
  const completedCount = computed(() => state.value.completed.length)

  /** 连续打卡天数 */
  const streak = computed(() => {
    const dates = state.value.streakDates
    if (dates.length === 0) return 0
    // 检查今天是否在列表中
    const todayStr = today
    if (!dates.includes(todayStr)) return 0
    // 从今天往回数
    let count = 0
    let check = new Date()
    for (let i = 0; i < dates.length + 1; i++) {
      const ds = formatDate(check)
      if (dates.includes(ds)) {
        count++
        check = new Date(check.getTime() - 86400000)
      } else {
        break
      }
    }
    return count
  })

  /** 本周（周一→周日）打卡状态，用于首页连续打卡卡 */
  const weeklyStatus = computed<{ label: string; done: boolean; today: boolean }[]>(() => {
    const dates = state.value.streakDates
    const labels = ['一', '二', '三', '四', '五', '六', '日']
    // 计算本周一到本周日
    const now = new Date()
    const dayOfWeek = now.getDay() === 0 ? 7 : now.getDay() // 周日 -> 7
    const monday = new Date(now)
    monday.setDate(now.getDate() - (dayOfWeek - 1))
    monday.setHours(0, 0, 0, 0)

    const todayStr = today
    return labels.map((label, i) => {
      const d = new Date(monday)
      d.setDate(monday.getDate() + i)
      const ds = formatDate(d)
      return {
        label,
        done: dates.includes(ds),
        today: ds === todayStr,
      }
    })
  })

  /** 标记挑战完成 */
  function completeChallenge(challengeId: string): void {
    if (state.value.completed.includes(challengeId)) return
    state.value = {
      ...state.value,
      completed: [...state.value.completed, challengeId],
    }
    // 如果是主挑战完成，记录打卡日期
    if (challengeId === state.value.mainChallenge.id) {
      const todayStr = today
      if (!state.value.streakDates.includes(todayStr)) {
        state.value = {
          ...state.value,
          streakDates: [...state.value.streakDates, todayStr].slice(-365),
        }
      }
    }
    saveState(state.value)
  }

  /** 检查并自动完成挑战（基于照片数据） */
  function autoCheckChallenge(photoCount: number, usedTemplateIds: string[], usedSceneIds: string[]): void {
    const newCompleted: string[] = []
    // 主挑战：拍了至少 1 张照片
    if (!state.value.completed.includes(state.value.mainChallenge.id) && photoCount >= 1) {
      newCompleted.push(state.value.mainChallenge.id)
    }
    // 附加挑战 A：使用 N 个不同模板
    const subA = state.value.subChallenges[0]
    if (subA && !state.value.completed.includes(subA.id)) {
      const match = subA.title.match(/(\d+)\s*个不同模板/)
      const target = match ? parseInt(match[1]) : 2
      if (usedTemplateIds.length >= target) {
        newCompleted.push(subA.id)
      }
    }
    // 附加挑战 B：在特定场景拍照
    const subB = state.value.subChallenges[1]
    if (subB && !state.value.completed.includes(subB.id) && subB.sceneId) {
      if (usedSceneIds.includes(subB.sceneId)) {
        newCompleted.push(subB.id)
      }
    }
    if (newCompleted.length > 0) {
      newCompleted.forEach(id => completeChallenge(id))
    }
  }

  return {
    mainChallenge,
    subChallenges,
    tomorrowPreview,
    completedIds,
    mainCompleted,
    subStatuses,
    totalChallenges,
    completedCount,
    streak,
    weeklyStatus,
    completeChallenge,
    autoCheckChallenge,
    today,
  }
}
