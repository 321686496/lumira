// lumira-server/packages/backend/src/database/schema.ts

import { sqliteTable, text, integer, uniqueIndex } from 'drizzle-orm/sqlite-core';

export const devices = sqliteTable('devices', {
  deviceId: text('device_id').primaryKey(),
  alias: text('alias'),
  firstSeenAt: integer('first_seen_at').notNull(),
  lastSeenAt: integer('last_seen_at').notNull(),
  ipRegion: text('ip_region'),
});

export const userProfiles = sqliteTable('user_profiles', {
  deviceId: text('device_id').primaryKey().references(() => devices.deviceId),
  username: text('username').notNull(),
  avatarSeed: text('avatar_seed').notNull(),
  updatedAt: integer('updated_at').notNull(),
});

export const inviteRecords = sqliteTable('invite_records', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  inviterDeviceId: text('inviter_device_id').notNull().references(() => devices.deviceId),
  inviteeDeviceId: text('invitee_device_id').notNull().unique().references(() => devices.deviceId),
  inviteCode: text('invite_code').notNull(),
  channel: text('channel').notNull().default('direct'),
  activatedAt: integer('activated_at').notNull(),
  inviterIp: text('inviter_ip'),
  inviteeIp: text('invitee_ip'),
});

export const rewardTiers = sqliteTable('reward_tiers', {
  tier: integer('tier').primaryKey(),
  requiredInvites: integer('required_invites').notNull(),
  rewardsJson: text('rewards_json').notNull().default('[]'),
  isActive: integer('is_active').notNull().default(1),
});

export const rewardUnlocks = sqliteTable('reward_unlocks', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  deviceId: text('device_id').notNull().references(() => devices.deviceId),
  tier: integer('tier').notNull().references(() => rewardTiers.tier),
  source: text('source').notNull(),
  sourceDetail: text('source_detail'),
  status: text('status').notNull().default('unlocked'),
  unlockedAt: integer('unlocked_at').notNull(),
  claimedAt: integer('claimed_at'),
});

export const redemptionCodeBatches = sqliteTable('redemption_code_batches', {
  batchId: integer('batch_id').primaryKey({ autoIncrement: true }),
  campaignName: text('campaign_name').notNull(),
  maxUsesPerCode: integer('max_uses_per_code').notNull().default(1),
  totalGenerated: integer('total_generated').notNull(),
  totalUsed: integer('total_used').notNull().default(0),
  rewardPoints: integer('reward_points').notNull().default(0),
  rewardTemplates: text('reward_templates').notNull().default('[]'),
  validFrom: integer('valid_from'),
  validUntil: integer('valid_until'),
  isActive: integer('is_active').notNull().default(1),
  createdAt: integer('created_at').notNull(),
});

export const redemptionCodes = sqliteTable('redemption_codes', {
  code: text('code').primaryKey(),
  batchId: integer('batch_id').notNull().references(() => redemptionCodeBatches.batchId),
  usedCount: integer('used_count').notNull().default(0),
  maxUses: integer('max_uses').notNull().default(1),
});

export const redemptionRecords = sqliteTable('redemption_records', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  code: text('code').notNull().references(() => redemptionCodes.code),
  deviceId: text('device_id').notNull().references(() => devices.deviceId),
  redeemedAt: integer('redeemed_at').notNull(),
  ipAddress: text('ip_address'),
});

export const questionnaireRecords = sqliteTable('questionnaire_records', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  deviceId: text('device_id').notNull(),
  answersJson: text('answers_json').notNull(),
  submittedAt: integer('submitted_at').notNull(),
  clientIp: text('client_ip'),
});

export const userPoints = sqliteTable('user_points', {
  deviceId: text('device_id').primaryKey().references(() => devices.deviceId),
  balance: integer('balance').notNull().default(0),
  totalEarned: integer('total_earned').notNull().default(0),
  totalSpent: integer('total_spent').notNull().default(0),
  updatedAt: integer('updated_at').notNull(),
});

export const pointTransactions = sqliteTable('point_transactions', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  deviceId: text('device_id').notNull().references(() => devices.deviceId),
  delta: integer('delta').notNull(),
  type: text('type').notNull(),
  refId: text('ref_id'),
  createdAt: integer('created_at').notNull(),
});

export const ownedTemplates = sqliteTable('owned_templates', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  deviceId: text('device_id').notNull().references(() => devices.deviceId),
  templateId: text('template_id').notNull(),
  source: text('source').notNull(),
  sourceDetail: text('source_detail'),
  unlockedAt: integer('unlocked_at').notNull(),
});

export const templatePrices = sqliteTable('template_prices', {
  templateId: text('template_id').primaryKey(),
  priceCredits: integer('price_credits').notNull(),
  isActive: integer('is_active').notNull().default(1),
  updatedAt: integer('updated_at').notNull(),
});

export const dailySignInRecords = sqliteTable('daily_sign_in_records', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  deviceId: text('device_id').notNull().references(() => devices.deviceId),
  signInDate: integer('sign_in_date').notNull(),
  dayIndex: integer('day_index').notNull(),
  pointsEarned: integer('points_earned').notNull(),
  createdAt: integer('created_at').notNull(),
});

// 通用积分事件发放记录（每日首拍/完成挑战等新途径，幂等去重）
// UNIQUE(device_id, type, ref_id) 保证同一设备同一事件只发一次积分
export const pointEarnEvents = sqliteTable('point_earn_events', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  deviceId: text('device_id').notNull().references(() => devices.deviceId),
  type: text('type').notNull(),
  refId: text('ref_id').notNull(),
  points: integer('points').notNull(),
  createdAt: integer('created_at').notNull(),
}, (table) => ({
  uniqueEvent: uniqueIndex('uq_point_earn_event').on(table.deviceId, table.type, table.refId),
}));

// ===== 后台动态模板上传（spec 2026-08-05 第 2.1 节）=====

// 分类管理：三级树形（type/style/method），key + parent_key 联合唯一
// 系统分类 isSystem=1（key 锁定不可改不可删）；一级 parentKey=null，level=1
export const templateCategories = sqliteTable('template_categories', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  key: text('key').notNull(),                  // 'portrait' / 'japanese' / 'normal' / 自定义 key
  name: text('name').notNull(),                // 显示名 '人像' / '日系' / '他拍'
  iconUrl: text('icon_url').notNull(),         // 图标 URL，空字符串表示用 Flutter 内置映射（仅一级有）
  parentKey: text('parent_key'),               // 父分类 key；一级为 NULL
  level: integer('level').notNull().default(1), // 1=type / 2=style / 3=method
  sortOrder: integer('sort_order').notNull().default(0),
  isSystem: integer('is_system').notNull().default(0),  // 1=系统保留, key 锁定不可改不可删
  isActive: integer('is_active').notNull().default(1),  // 0=隐藏不展示
  createdAt: integer('created_at').notNull(),
  updatedAt: integer('updated_at').notNull(),
}, (table) => ({
  // SQLite 中 NULL 不参与唯一约束，故一级分类的 key 在本索引中天然唯一
  keyParentIdx: uniqueIndex('uq_category_key_parent').on(table.key, table.parentKey),
}));

// 后端动态模板内容（结构化存储，5 段内容 JSON 列）
export const templates = sqliteTable('templates', {
  // —— meta 拆列（便于 SQL 筛选/排序/分页）——
  id: text('id').primaryKey(),                 // 'srv_' + nanoid(12)
  name: text('name').notNull(),
  author: text('author').notNull().default('Lumira'),
  version: text('version').notNull().default('1.0.0'),
  category: text('category').notNull(),        // 引用 template_categories.key
  price: integer('price').notNull().default(0),
  coverUrl: text('cover_url').notNull(),
  description: text('description').notNull().default(''),
  referenceSource: text('reference_source').notNull().default(''),
  tagsJson: text('tags_json').notNull().default('[]'),
  tagIdsJson: text('tag_ids_json').notNull().default('[]'),
  classificationJson: text('classification_json').notNull().default('{}'),
  sortOrder: integer('sort_order').notNull().default(0),
  isActive: integer('is_active').notNull().default(1),  // 0=下架
  // —— 5 段内容 JSON 列 ——
  compositionJson: text('composition_json').notNull().default('{}'),
  poseJson: text('pose_json').notNull().default('{}'),
  cameraJson: text('camera_json').notNull().default('{}'),
  sceneGuideJson: text('scene_guide_json').notNull().default('{}'),
  postProcessJson: text('post_process_json').notNull().default('{}'),
  createdAt: integer('created_at').notNull(),
  updatedAt: integer('updated_at').notNull(),
});
