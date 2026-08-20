export type NotificationTargetScope = 'all' | 'devices' | 'criteria';

export interface NotificationCriteria {
  /** 空数组=不限；支持 '*' 整体通配 */
  platform?: string[];
  deviceModel?: string[];
  osVersion?: string[];
  appVersion?: string[];
  email?: string[];
  /** 预留：按地区 / deviceId 列表 */
  region?: string[];
  userIdList?: string[];
}

export interface NotificationItem {
  id: string;
  title: string;
  body: string;
  iconKey: string;
  category: string;
  startAt?: number | null;
  endAt?: number | null;
}

export interface NotificationListResponse {
  notifications: NotificationItem[];
}