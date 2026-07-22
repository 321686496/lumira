// lumira-server/packages/backend/src/shared/invite-code.generator.ts

import { customAlphabet } from 'nanoid';

// 排除易混淆字符：O, 0, I, 1
const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const LENGTH = 6;

const nanoid = customAlphabet(ALPHABET, LENGTH);

export function generateInviteCode(): string {
  return nanoid();
}
