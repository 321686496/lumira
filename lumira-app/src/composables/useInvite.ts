/**
 * 邀请有礼组合式函数
 *
 * 管理邀请码、邀请记录、奖励阶梯，持久化到 localStorage。
 */

import { ref, computed } from 'vue'

const INVITE_KEY = 'lumira_invite_data'

interface InviteRecord {
  id: string
  name: string
  date: string
  status: 'confirmed' | 'pending'
  avatar: string
}

interface InviteState {
  /** 用户自己的邀请码 */
  myCode: string
  /** 已绑定的邀请码（别人的） */
  boundCode: string | null
  /** 邀请记录 */
  records: InviteRecord[]
}

/** 奖励阶梯定义 */
const REWARD_TIERS = [
  { count: 1, name: '日系胶片模板', icon: 'ph-film-strip' },
  { count: 3, name: '法式复古包', icon: 'ph-flag' },
  { count: 5, name: '氛围感包', icon: 'ph-stars' },
  { count: 10, name: '分享达人成就', icon: 'ph-medal' },
  { count: 15, name: '全部精选模板', icon: 'ph-crown' },
  { count: 20, name: '裂变之神', icon: 'ph-lightning' },
]

/** 生成随机邀请码 */
function generateCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
  let code = ''
  for (let i = 0; i < 6; i++) {
    code += chars[Math.floor(Math.random() * chars.length)]
  }
  return code
}

/** 加载状态 */
function loadState(): InviteState {
  try {
    const raw = uni.getStorageSync(INVITE_KEY)
    if (!raw) {
      const fresh: InviteState = {
        myCode: generateCode(),
        boundCode: null,
        records: [],
      }
      uni.setStorageSync(INVITE_KEY, fresh)
      return fresh
    }
    return typeof raw === 'string' ? JSON.parse(raw) : raw
  } catch {
    return { myCode: generateCode(), boundCode: null, records: [] }
  }
}

function saveState(state: InviteState): void {
  try {
    uni.setStorageSync(INVITE_KEY, state)
  } catch {
    // 忽略
  }
}

const state = ref<InviteState>(loadState())

export function useInvite() {
  const myCode = computed(() => state.value.myCode)
  const boundCode = computed(() => state.value.boundCode)
  const records = computed(() => state.value.records)

  /** 已确认的邀请人数 */
  const confirmedCount = computed(() =>
    state.value.records.filter(r => r.status === 'confirmed').length
  )

  /** 总邀请人数 */
  const totalCount = computed(() => state.value.records.length)

  /** 当前进度百分比（基于已确认邀请数） */
  const progressPercent = computed(() => {
    const max = REWARD_TIERS[REWARD_TIERS.length - 1].count
    return Math.min(100, Math.round((confirmedCount.value / max) * 100))
  })

  /** 奖励阶梯（带完成状态） */
  const rewards = computed(() =>
    REWARD_TIERS.map(tier => ({
      ...tier,
      done: confirmedCount.value >= tier.count,
      locked: confirmedCount.value < tier.count - 2,
      status: confirmedCount.value >= tier.count
        ? '已达成'
        : confirmedCount.value >= tier.count - 1
          ? '进行中'
          : '',
    }))
  )

  /** 下一个奖励 */
  const nextReward = computed(() => {
    return REWARD_TIERS.find(t => confirmedCount.value < t.count) || null
  })

  /** 绑定邀请码 */
  function bindCode(code: string): { success: boolean; message: string } {
    if (!code.trim()) {
      return { success: false, message: '请输入邀请码' }
    }
    if (code.trim().toUpperCase() === state.value.myCode) {
      return { success: false, message: '不能绑定自己的邀请码' }
    }
    if (state.value.boundCode) {
      return { success: false, message: '已绑定过邀请码' }
    }
    state.value = {
      ...state.value,
      boundCode: code.trim().toUpperCase(),
    }
    saveState(state.value)
    return { success: true, message: '绑定成功' }
  }

  /** 模拟添加邀请记录（实际应由后端推送） */
  function addRecord(name: string): void {
    const record: InviteRecord = {
      id: `invite_${Date.now()}`,
      name,
      date: new Date().toISOString().slice(0, 10),
      status: 'pending',
      avatar: 'ph-user',
    }
    state.value = {
      ...state.value,
      records: [record, ...state.value.records],
    }
    saveState(state.value)
  }

  return {
    myCode,
    boundCode,
    records,
    confirmedCount,
    totalCount,
    progressPercent,
    rewards,
    nextReward,
    bindCode,
    addRecord,
  }
}
