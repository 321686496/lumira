// lumira-server/packages/backend/src/modules/banners/operation-banner.rules.ts
/** 运营位展示条件白名单（与 App OperationCondition 枚举一一对应） */
export const OPERATION_BANNER_CONDITIONS = [
  'nonNewUserNotInvited',
  'pointsReady',
  'hasLockedTemplate',
] as const;

/** 运营位路由白名单（运营位只指向真实存在的功能页，防脏配置导致 App 跳转失败） */
export const OPERATION_BANNER_ROUTES = [
  '/invite',
  '/points/wallet',
  '/templates/unlock',
  '/templates/detail',
] as const;
