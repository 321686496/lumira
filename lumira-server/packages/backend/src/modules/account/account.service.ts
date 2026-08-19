import { BadRequestException, Injectable } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { devices } from '../../database/schema';
import { sha256Hex, generateSecret } from './hash';

const RECOVERY_SECRET_TTL_DAYS = 30;

@Injectable()
export class AccountService {
  constructor(private readonly dbService: DatabaseService) {}

  async rotateRecoverySecret(deviceId: string) {
    const db = this.dbService.getDb();
    const secret = generateSecret();
    const now = Math.floor(Date.now() / 1000);
    const exists = await db.query.devices.findFirst({
      where: eq(devices.deviceId, deviceId),
    });
    if (!exists) throw new BadRequestException('设备不存在，请先注册');

    await db.update(devices).set({
      recoverySecretHash: sha256Hex(secret),
      recoverySecretCreatedAt: now,
    }).where(eq(devices.deviceId, deviceId));

    const qrPayload = `lumira://account-recover?v=1&secret=${secret}`;
    const expiresAt = now + RECOVERY_SECRET_TTL_DAYS * 24 * 3600;
    return { secret, qrPayload, expiresAt };
  }

  async recoverByQr(secret: string) {
    if (!secret) throw new BadRequestException('缺少恢复密钥');
    const db = this.dbService.getDb();
    const hash = sha256Hex(secret);
    const row = (
      await db.select().from(devices).where(eq(devices.recoverySecretHash, hash))
    )[0];
    if (!row) throw new BadRequestException('恢复密钥无效');

    const now = Math.floor(Date.now() / 1000);
    if ((row.recoverySecretCreatedAt ?? 0) + RECOVERY_SECRET_TTL_DAYS * 24 * 3600 < now) {
      throw new BadRequestException('恢复密钥已过期，请重新生成');
    }

    // 一次性消费 + 会话版本递增（旧 token 全部失效）
    const nextEpoch = (row.sessionEpoch ?? 0) + 1;
    await db.update(devices).set({
      recoverySecretHash: null,
      recoverySecretCreatedAt: null,
      sessionEpoch: nextEpoch,
    }).where(eq(devices.deviceId, row.deviceId));

    return { deviceId: row.deviceId };
  }
}