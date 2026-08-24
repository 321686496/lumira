import { BadRequestException, Injectable } from '@nestjs/common';
import { and, eq, desc } from 'drizzle-orm';
import { isNull } from 'drizzle-orm/sql/expressions/conditions';
import { DatabaseService } from '../../database/database.service';
import { devices, accountOtp } from '../../database/schema';
import { sha256Hex, generateSecret, generateOtp } from './hash';
import { MailService } from './mail.service';

const RECOVERY_SECRET_TTL_DAYS = 30;
const OTP_TTL_SECONDS = 60 * 10;      // 10 分钟
const OTP_SEND_COOLDOWN = 60;          // 同邮箱每 60s
const OTP_MAX_ATTEMPTS = 5;

@Injectable()
export class AccountService {
  constructor(
    private readonly dbService: DatabaseService,
    private readonly mailService: MailService,
  ) {}

  /** 查询当前设备的绑定邮箱（用于「账号保护」页展示已绑定状态） */
  async getStatus(deviceId: string) {
    const db = this.dbService.getDb();
    const row = await db.query.devices.findFirst({
      where: eq(devices.deviceId, deviceId),
    });
    if (!row) throw new BadRequestException('设备不存在，请先注册');
    return { email: row.email ?? null };
  }

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

  /** 取该邮箱+purpose 的最新一条 OTP（按 id 倒序），再判未消费/未过期 */
  private async latestOtp(email: string, purpose: string) {
    const rows = await this.dbService.getDb().select().from(accountOtp)
      .where(and(eq(accountOtp.email, email), eq(accountOtp.purpose, purpose)))
      .orderBy(desc(accountOtp.id)).limit(1);
    return rows[0];
  }

  async sendEmailCode(email: string, purpose: 'bind' | 'recover') {
    if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      throw new BadRequestException('邮箱格式不正确');
    }
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);
    const latest = await this.latestOtp(email, purpose);
    if (latest && latest.consumedAt === null && latest.createdAt + OTP_SEND_COOLDOWN > now) {
      throw new BadRequestException('发送过于频繁，请稍后再试');
    }
    const code = generateOtp();
    await db.insert(accountOtp).values({
      email,
      deviceId: null,
      purpose,
      codeHash: sha256Hex(code),
      expiresAt: now + OTP_TTL_SECONDS,
      consumedAt: null,
      attempts: 0,
      createdAt: now,
    });
    await this.mailService.sendCode(email, code);
    return { sent: true as const };
  }

  async bindEmail(deviceId: string, email: string, code: string) {
    const db = this.dbService.getDb();
    const otp = await this.latestOtp(email, 'bind');
    const err = this.validateOtp(otp, email, code);
    if (err) throw new BadRequestException(err);
    // 绑定前确认设备存在，不存在抛 400
    const device = (
      await db.select().from(devices).where(eq(devices.deviceId, deviceId))
    )[0];
    if (!device) throw new BadRequestException('设备不存在，请先注册');
    // 一次性消费（带 consumedAt 防空值防竞态）
    await db.update(accountOtp).set({ consumedAt: Math.floor(Date.now() / 1000) })
      .where(and(eq(accountOtp.id, otp!.id), isNull(accountOtp.consumedAt)));
    const now = Math.floor(Date.now() / 1000);
    await db.update(devices).set({ email, emailVerifiedAt: now })
      .where(eq(devices.deviceId, deviceId));
    return { success: true as const };
  }

  private validateOtp(otp: { id: number; email: string; codeHash: string; expiresAt: number; consumedAt: number | null; attempts: number } | undefined, email: string, code: string): string | null {
    const now = Math.floor(Date.now() / 1000);
    if (!otp) return '验证码不存在，请先获取';
    if (otp.email !== email) return '验证码与邮箱不匹配';
    if (otp.consumedAt !== null) return '验证码已使用';
    if (otp.expiresAt < now) return '验证码已过期';
    if (otp.attempts >= OTP_MAX_ATTEMPTS) return '验证码错误次数过多，请重新获取';
    if (otp.codeHash !== sha256Hex(code)) {
      // 记一次错误尝试（fire-and-forget，不阻塞返回）
      void this.dbService.getDb().update(accountOtp)
        .set({ attempts: otp.attempts + 1 })
        .where(eq(accountOtp.id, otp.id));
      return '验证码错误';
    }
    return null;
  }

  async recoverByEmail(email: string, code: string) {
    const db = this.dbService.getDb();
    const otp = await this.latestOtp(email, 'recover');
    const err = this.validateOtp(otp, email, code);
    if (err) throw new BadRequestException(err);
    // 先校验设备存在再消费（未绑定则不消费 OTP）
    const device = (
      await db.select().from(devices).where(eq(devices.email, email))
    )[0];
    if (!device) throw new BadRequestException('该邮箱尚未绑定账号');
    // 一次性消费（带 consumedAt 防空值防竞态）
    await db.update(accountOtp).set({ consumedAt: Math.floor(Date.now() / 1000) })
      .where(and(eq(accountOtp.id, otp!.id), isNull(accountOtp.consumedAt)));
    await db.update(devices).set({ sessionEpoch: (device.sessionEpoch ?? 0) + 1 })
      .where(eq(devices.deviceId, device.deviceId));
    return { deviceId: device.deviceId };
  }
}