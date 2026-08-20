// lumira-server/packages/backend/src/database/schema.ts

import { mysqlTable, text, int, bigint, longtext, uniqueIndex, varchar, index } from 'drizzle-orm/mysql-core';

export const devices = mysqlTable('devices', {
  deviceId: text('device_id').primaryKey(),
  alias: text('alias'),
  platform: text('platform'),
  osVersion: text('os_version'),
  deviceModel: text('device_model'),
  appVersion: text('app_version'),
  firstSeenAt: int('first_seen_at').notNull(),
  lastSeenAt: int('last_seen_at').notNull(),
  ipRegion: text('ip_region'),
  recoverySecretHash: text('recovery_secret_hash'),
  recoverySecretCreatedAt: int('recovery_secret_created_at'),
  email: varchar('email', { length: 255 }),
  emailVerifiedAt: int('email_verified_at'),
  sessionEpoch: int('session_epoch').notNull().default(0),
}, (table) => ({
  emailIdx: uniqueIndex('uq_devices_email').on(table.email),
}));

export const userProfiles = mysqlTable('user_profiles', {
  deviceId: text('device_id').primaryKey().references(() => devices.deviceId),
  username: text('username').notNull(),
  avatarSeed: text('avatar_seed').notNull(),
  gender: text('gender'),
  favoriteCategoriesJson: text('favorite_categories_json'),
  painPointsJson: text('pain_points_json'),
  skillLevel: text('skill_level'),
  expectationsJson: text('expectations_json'),
  commonScenesJson: text('common_scenes_json'),
  shootFrequency: text('shoot_frequency'),
  avatarUrl: text('avatar_url'),
  updatedAt: int('updated_at').notNull(),
});

export const inviteRecords = mysqlTable('invite_records', {
  id: int('id').primaryKey().autoincrement(),
  inviterDeviceId: text('inviter_device_id').notNull().references(() => devices.deviceId),
  inviteeDeviceId: text('invitee_device_id').notNull().unique().references(() => devices.deviceId),
  inviteCode: text('invite_code').notNull(),
  channel: text('channel').notNull().default('direct'),
  activatedAt: int('activated_at').notNull(),
  inviterIp: text('inviter_ip'),
  inviteeIp: text('invitee_ip'),
});

export const rewardTiers = mysqlTable('reward_tiers', {
  tier: int('tier').primaryKey(),
  requiredInvites: int('required_invites').notNull(),
  rewardsJson: text('rewards_json').notNull().default('[]'),
  isActive: int('is_active').notNull().default(1),
});

export const rewardUnlocks = mysqlTable('reward_unlocks', {
  id: int('id').primaryKey().autoincrement(),
  deviceId: text('device_id').notNull().references(() => devices.deviceId),
  tier: int('tier').notNull().references(() => rewardTiers.tier),
  source: text('source').notNull(),
  sourceDetail: text('source_detail'),
  status: text('status').notNull().default('unlocked'),
  unlockedAt: int('unlocked_at').notNull(),
  claimedAt: int('claimed_at'),
});

export const redemptionCodeBatches = mysqlTable('redemption_code_batches', {
  batchId: int('batch_id').primaryKey().autoincrement(),
  campaignName: text('campaign_name').notNull(),
  maxUsesPerCode: int('max_uses_per_code').notNull().default(1),
  totalGenerated: int('total_generated').notNull(),
  totalUsed: int('total_used').notNull().default(0),
  rewardPoints: int('reward_points').notNull().default(0),
  rewardTemplates: text('reward_templates').notNull().default('[]'),
  validFrom: int('valid_from'),
  validUntil: int('valid_until'),
  isActive: int('is_active').notNull().default(1),
  createdAt: int('created_at').notNull(),
});

export const redemptionCodes = mysqlTable('redemption_codes', {
  code: text('code').primaryKey(),
  batchId: int('batch_id').notNull().references(() => redemptionCodeBatches.batchId),
  usedCount: int('used_count').notNull().default(0),
  maxUses: int('max_uses').notNull().default(1),
});

export const redemptionRecords = mysqlTable('redemption_records', {
  id: int('id').primaryKey().autoincrement(),
  code: text('code').notNull().references(() => redemptionCodes.code),
  deviceId: text('device_id').notNull().references(() => devices.deviceId),
  redeemedAt: int('redeemed_at').notNull(),
  ipAddress: text('ip_address'),
});

export const questionnaireRecords = mysqlTable('questionnaire_records', {
  id: int('id').primaryKey().autoincrement(),
  deviceId: text('device_id').notNull(),
  answersJson: longtext('answers_json').notNull(),
  submittedAt: int('submitted_at').notNull(),
  clientIp: text('client_ip'),
});

export const userPoints = mysqlTable('user_points', {
  deviceId: text('device_id').primaryKey().references(() => devices.deviceId),
  balance: int('balance').notNull().default(0),
  totalEarned: int('total_earned').notNull().default(0),
  totalSpent: int('total_spent').notNull().default(0),
  updatedAt: int('updated_at').notNull(),
});

export const pointTransactions = mysqlTable('point_transactions', {
  id: int('id').primaryKey().autoincrement(),
  deviceId: text('device_id').notNull().references(() => devices.deviceId),
  delta: int('delta').notNull(),
  type: text('type').notNull(),
  refId: text('ref_id'),
  createdAt: int('created_at').notNull(),
});

export const ownedTemplates = mysqlTable('owned_templates', {
  id: int('id').primaryKey().autoincrement(),
  deviceId: text('device_id').notNull().references(() => devices.deviceId),
  templateId: text('template_id').notNull(),
  source: text('source').notNull(),
  sourceDetail: text('source_detail'),
  unlockedAt: int('unlocked_at').notNull(),
});

export const templatePrices = mysqlTable('template_prices', {
  templateId: text('template_id').primaryKey(),
  priceCredits: int('price_credits').notNull(),
  isActive: int('is_active').notNull().default(1),
  updatedAt: int('updated_at').notNull(),
});

export const dailySignInRecords = mysqlTable('daily_sign_in_records', {
  id: int('id').primaryKey().autoincrement(),
  deviceId: text('device_id').notNull().references(() => devices.deviceId),
  signInDate: int('sign_in_date').notNull(),
  dayIndex: int('day_index').notNull(),
  pointsEarned: int('points_earned').notNull(),
  createdAt: int('created_at').notNull(),
});

// 通用积分事件发放记录（每日首拍/完成挑战等新途径，幂等去重）
// UNIQUE(device_id, type, ref_id) 保证同一设备同一事件只发一次积分
export const pointEarnEvents = mysqlTable('point_earn_events', {
  id: int('id').primaryKey().autoincrement(),
  deviceId: text('device_id').notNull().references(() => devices.deviceId),
  type: text('type').notNull(),
  refId: text('ref_id').notNull(),
  points: int('points').notNull(),
  createdAt: int('created_at').notNull(),
}, (table) => ({
  uniqueEvent: uniqueIndex('uq_point_earn_event').on(table.deviceId, table.type, table.refId),
}));

// ===== 后台动态模板上传（spec 2026-08-05 第 2.1 节）=====

// 分类管理：三级树形（type/style/method），key + parent_key 联合唯一
export const templateCategories = mysqlTable('template_categories', {
  id: int('id').primaryKey().autoincrement(),
  key: text('key').notNull(),
  name: text('name').notNull(),
  iconUrl: text('icon_url').notNull(),
  parentKey: text('parent_key'),
  level: int('level').notNull().default(1),
  sortOrder: int('sort_order').notNull().default(0),
  isSystem: int('is_system').notNull().default(0),
  isActive: int('is_active').notNull().default(1),
  createdAt: int('created_at').notNull(),
  updatedAt: int('updated_at').notNull(),
}, (table) => ({
  keyParentIdx: uniqueIndex('uq_category_key_parent').on(table.key, table.parentKey),
}));

// 后端动态模板内容（结构化存储，5 段内容 JSON 列）
export const templates = mysqlTable('templates', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  author: text('author').notNull().default('Lumira'),
  version: text('version').notNull().default('1.0.0'),
  category: text('category').notNull(),
  price: int('price').notNull().default(0),
  coverUrl: text('cover_url').notNull(),
  description: text('description').notNull().default(''),
  referenceSource: text('reference_source').notNull().default(''),
  tagsJson: text('tags_json').notNull().default('[]'),
  tagIdsJson: text('tag_ids_json').notNull().default('[]'),
  classificationJson: text('classification_json').notNull().default('{}'),
  sortOrder: int('sort_order').notNull().default(0),
  isActive: int('is_active').notNull().default(1),
  compositionJson: longtext('composition_json').notNull().default('{}'),
  poseJson: longtext('pose_json').notNull().default('{}'),
  cameraJson: longtext('camera_json').notNull().default('{}'),
  sceneGuideJson: longtext('scene_guide_json').notNull().default('{}'),
  postProcessJson: longtext('post_process_json').notNull().default('{}'),
  // 季节/天气/时段元数据（spec 2026-08-20）：{ seasons:[], weathers:[], timeTones:[] }
  ambienceJson: longtext('ambience_json').notNull().default('{}'),
  // 短简介（≤10字，banner/模板卡片展示用）
  shortDesc: text('short_desc').notNull().default(''),
  createdAt: int('created_at').notNull(),
  updatedAt: int('updated_at').notNull(),
});

// ===== 意见反馈（spec 2026-08-18-feedback-design）=====
export const feedbacks = mysqlTable('feedbacks', {
  id: text('id').primaryKey(),
  deviceId: text('device_id').notNull(),
  type: text('type').notNull(),
  content: text('content').notNull(),
  contact: text('contact'),
  status: text('status').notNull().default('pending'),
  screenshotsJson: text('screenshots_json').notNull().default('[]'),
  clientIp: text('client_ip'),
  createdAt: int('created_at').notNull(),
});

// ===== 账号恢复（spec 2026-08-19-account-recovery-design）=====
export const accountOtp = mysqlTable('account_otp', {
  id: int('id').primaryKey().autoincrement(),
  email: varchar('email', { length: 255 }).notNull(),
  deviceId: text('device_id'),
  purpose: varchar('purpose', { length: 16 }).notNull(),
  codeHash: varchar('code_hash', { length: 64 }).notNull(),
  expiresAt: int('expires_at').notNull(),
  consumedAt: int('consumed_at'),
  attempts: int('attempts').notNull().default(0),
  createdAt: int('created_at').notNull(),
}, (table) => ({
  emailPurposeIdx: index('idx_account_otp_email_purpose').on(table.email, table.purpose),
}));

// ===== 使用次数统计（spec 2026-08-20-usage-stats-recommend-design）=====
export const usageEvents = mysqlTable('usage_events', {
  id: int('id').primaryKey().autoincrement(),
  deviceId: text('device_id').notNull().references(() => devices.deviceId),
  clientEventId: text('client_event_id').notNull(),
  itemType: text('item_type').notNull(),
  itemId: text('item_id').notNull(),
  itemSource: text('item_source').notNull(),
  eventType: text('event_type').notNull(),
  occurredAt: bigint('occurred_at', { mode: 'number' }).notNull(),
}, (table) => ({
  clientEventIdx: uniqueIndex('uq_usage_client_event').on(table.clientEventId),
}));

export const systemScenes = mysqlTable('system_scenes', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  category: text('category').notNull(),
  style: text('style').notNull().default(''),
  icon: text('icon').notNull().default(''),
  vibe: text('vibe').notNull().default(''),
  description: text('description').notNull().default(''),
  filterJson: longtext('filter_json').notNull().default('{}'),
  tipsJson: text('tips_json').notNull().default('[]'),
  exampleImagesJson: text('example_images_json').notNull().default('[]'),
  whereToShoot: text('where_to_shoot').notNull().default(''),
  bestTime: text('best_time').notNull().default(''),
  relatedCategory: text('related_category').notNull().default(''),
  recommendedTagIdsJson: text('recommended_tag_ids_json').notNull().default('[]'),
  sortOrder: int('sort_order').notNull().default(0),
  isActive: int('is_active').notNull().default(1),
  createdAt: int('created_at').notNull(),
  updatedAt: int('updated_at').notNull(),
}, (table) => ({
  activeIdx: index('idx_system_scenes_active').on(table.isActive),
}));

// ===== 内置模板注册表（App 同步，后台展示内置模板名称）=====
export const builtinTemplates = mysqlTable('builtin_templates', {
  id: varchar('id', { length: 128 }).primaryKey(),
  name: text('name').notNull(),
  updatedAt: bigint('updated_at', { mode: 'number' }).notNull(),
});

// ===== 内置场景注册表（App 同步，后台展示内置场景名称）=====
export const builtinScenes = mysqlTable('builtin_scenes', {
  id: varchar('id', { length: 128 }).primaryKey(),
  name: text('name').notNull(),
  updatedAt: bigint('updated_at', { mode: 'number' }).notNull(),
});
