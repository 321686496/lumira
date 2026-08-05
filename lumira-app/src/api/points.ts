/**
 * 积分体系 API
 *
 * 涵盖积分余额、流水、模板拥有与兑换、签到、兑换码、邀请有礼。
 * 所有接口需 Bearer JWT（由 utils/request 自动注入）。
 */

import { get, post } from '@/utils/request'

// ===== 类型定义 =====

export interface PointsBalance {
  deviceId: string
  balance: number
  totalEarned: number
  totalSpent: number
}

export interface PointsTransaction {
  id: string
  deviceId: string
  delta: number
  type: string
  refId: string
  createdAt: string
}

export interface PointsTransactionsResp {
  transactions: PointsTransaction[]
  total: number
}

export interface OwnedTemplateRecord {
  id: string
  templateId: string
  source: string
  sourceDetail: string
  unlockedAt: string
}

export interface OwnedTemplatesResp {
  templateIds: string[]
  records: OwnedTemplateRecord[]
}

export interface TemplatePrice {
  templateId: string
  priceCredits: number
  isActive: boolean
}

export interface TemplatePricesResp {
  prices: TemplatePrice[]
}

export interface ExchangeResp {
  success: boolean
  templateId: string
  spentCredits: number
  balance: number
}

export interface SignInResp {
  success: boolean
  dayIndex: number
  pointsEarned: number
  balance: number
}

export interface SignInStatusResp {
  signedToday: boolean
  consecutiveDays: number
  lastSignInDate: string
}

export interface RedeemResp {
  batchId: string
  campaignName: string
  rewardPoints: number
  balance: number
}

export interface InviteGenerateResp {
  inviteCode: string
}

export interface InviteActivateResp {
  inviterDeviceId: string
  rewardPoints: number
  balance: number
  totalInvites: number
}

export interface InviteStatsResp {
  totalInvites: number
  rewardPointsPerInvite: number
  totalEarnedFromInvite: number
  currentBalance: number
}

// ===== API 方法 =====

/** 1. 获取积分余额 */
export function getPointsBalance(): Promise<PointsBalance> {
  return get<PointsBalance>('/points/balance')
}

/** 2. 获取积分流水 */
export function getPointsTransactions(limit = 50, offset = 0): Promise<PointsTransactionsResp> {
  return get<PointsTransactionsResp>('/points/transactions', {
    query: { limit, offset },
  })
}

/** 3. 获取已拥有模板列表 */
export function getOwnedTemplates(): Promise<OwnedTemplatesResp> {
  return get<OwnedTemplatesResp>('/templates/owned')
}

/** 4. 获取模板积分价格 */
export function getTemplatePrices(): Promise<TemplatePricesResp> {
  return get<TemplatePricesResp>('/templates/prices')
}

/** 5. 积分兑换模板 */
export function exchangeTemplate(templateId: string): Promise<ExchangeResp> {
  return post<ExchangeResp>('/templates/exchange', { data: { templateId } })
}

/** 6. 每日签到 */
export function signIn(): Promise<SignInResp> {
  return post<SignInResp>('/sign-in')
}

/** 7. 获取签到状态 */
export function getSignInStatus(): Promise<SignInStatusResp> {
  return get<SignInStatusResp>('/sign-in/status')
}

/** 8. 兑换码兑换积分 */
export function redeemCode(code: string): Promise<RedeemResp> {
  return post<RedeemResp>('/redeem', { data: { code } })
}

/** 9. 生成邀请码 */
export function generateInviteCode(): Promise<InviteGenerateResp> {
  return post<InviteGenerateResp>('/invite/generate')
}

/** 10. 激活邀请码（绑定好友邀请） */
export function activateInviteCode(
  inviteCode: string,
  channel?: string
): Promise<InviteActivateResp> {
  return post<InviteActivateResp>('/invite/activate', {
    data: channel ? { inviteCode, channel } : { inviteCode },
  })
}

/** 11. 获取邀请统计 */
export function getInviteStats(): Promise<InviteStatsResp> {
  return get<InviteStatsResp>('/invite/stats')
}

// ===== 工具方法 =====

/** 流水类型中文映射 */
export function transactionTypeLabel(type: string): string {
  const map: Record<string, string> = {
    sign_in: '每日签到',
    redeem: '兑换码',
    exchange: '兑换模板',
    invite_reward: '邀请奖励',
    invite_activated: '绑定邀请码',
    admin_grant: '官方赠送',
    refund: '退款',
  }
  return map[type] || type
}

/** 格式化时间为 YYYY-MM-DD HH:mm */
export function formatTransactionTime(iso: string): string {
  if (!iso) return ''
  const d = new Date(iso)
  if (isNaN(d.getTime())) return iso
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  const hh = String(d.getHours()).padStart(2, '0')
  const mm = String(d.getMinutes()).padStart(2, '0')
  return `${y}-${m}-${day} ${hh}:${mm}`
}
