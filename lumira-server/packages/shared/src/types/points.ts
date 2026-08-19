// 积分体系类型契约

// 积分流水类型
export type PointTransactionType =
  | 'invite'           // 邀请奖励
  | 'sign_in'          // 每日签到
  | 'share'            // 分享奖励
  | 'redeem_code'      // 兑换码兑换积分
  | 'exchange_template' // 积分兑换模板（负数）
  | 'ad'               // 看广告（预留）
  | 'admin_grant'      // 后台发放
  | 'shoot_daily'      // 每日首次拍摄
  | 'challenge'        // 完成挑战
  | 'level_reward';    // 达到指定等级发积分（一级一次）

// 积分流水记录
export interface PointTransaction {
  id: number;
  deviceId: string;
  delta: number; // 正=获取，负=消耗
  type: PointTransactionType;
  refId: string | null;
  createdAt: number;
}

// 余额响应
export interface PointsBalanceResponse {
  deviceId: string;
  balance: number;
  totalEarned: number;
  totalSpent: number;
}

// 流水列表响应
export interface PointsTransactionsResponse {
  transactions: PointTransaction[];
  total: number;
}

// 已拥有模板来源
export type OwnedTemplateSource = 'redemption' | 'points' | 'invite' | 'admin_grant';

// 已拥有模板记录
export interface OwnedTemplateRecord {
  id: number;
  templateId: string;
  source: OwnedTemplateSource;
  sourceDetail: string | null;
  unlockedAt: number;
}

// 已拥有模板列表响应
export interface OwnedTemplatesResponse {
  templateIds: string[]; // 简化：仅返回 id 数组供客户端门禁判断
  records: OwnedTemplateRecord[];
}

// 模板积分定价
export interface TemplatePrice {
  templateId: string;
  priceCredits: number;
  isActive: boolean;
}

// 模板定价列表响应
export interface TemplatePricesResponse {
  prices: TemplatePrice[];
}

// 积分兑换模板请求
export interface ExchangeTemplateRequest {
  templateId: string;
  priceCredits?: number; // 内置模板（id 无 srv_ 前缀）必填，客户端上报积分价格（≥1）
}

// 积分兑换模板响应
export interface ExchangeTemplateResponse {
  success: boolean;
  templateId: string;
  spentCredits: number;
  balance: number;
}

// 每日签到响应
export interface SignInResponse {
  success: boolean;
  dayIndex: number;       // 连签第几天
  pointsEarned: number;   // 本次获得积分
  balance: number;        // 当前余额
}

// 签到状态响应
export interface SignInStatusResponse {
  signedToday: boolean;
  consecutiveDays: number; // 当前连签天数
  lastSignInDate: number | null;
}
