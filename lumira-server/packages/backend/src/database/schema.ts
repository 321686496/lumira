// lumira-server/packages/backend/src/database/schema.ts

import { sqliteTable, text, integer } from 'drizzle-orm/sqlite-core';

export const devices = sqliteTable('devices', {
  deviceId: text('device_id').primaryKey(),
  alias: text('alias'),
  firstSeenAt: integer('first_seen_at').notNull(),
  lastSeenAt: integer('last_seen_at').notNull(),
  ipRegion: text('ip_region'),
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
  rewardTier: integer('reward_tier').notNull().references(() => rewardTiers.tier),
  maxUsesPerCode: integer('max_uses_per_code').notNull().default(1),
  totalGenerated: integer('total_generated').notNull(),
  totalUsed: integer('total_used').notNull().default(0),
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
