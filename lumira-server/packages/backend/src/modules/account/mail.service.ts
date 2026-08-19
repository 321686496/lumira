import { Injectable } from '@nestjs/common';
import * as nodemailer from 'nodemailer';
import type { Transporter } from 'nodemailer';

@Injectable()
export class MailService {
  private transporter: Transporter | null = null;
  private readonly from: string;

  constructor() {
    this.from = process.env.SMTP_FROM || 'Lumira <no-reply@lumira.iwtle.top>';
    const host = process.env.SMTP_HOST;
    if (host) {
      this.transporter = nodemailer.createTransport({
        host,
        port: parseInt(process.env.SMTP_PORT || '587', 10),
        secure: process.env.SMTP_SECURE === 'true',
        auth: process.env.SMTP_USER
          ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS || '' }
          : undefined,
      });
    }
  }

  get enabled(): boolean {
    return this.transporter !== null;
  }

  /** 发送 6 位验证码。未配置 SMTP_HOST 时进入 dev 模式，仅打码日志，仍视为成功。 */
  async sendCode(email: string, code: string): Promise<void> {
    if (!this.transporter) {
      console.log(`[mail:dev] 验证码 ${code} 将发送到 ${email}`);
      return;
    }
    await this.transporter.sendMail({
      from: this.from,
      to: email,
      subject: '【如画 Lumira】验证码',
      text: `你的验证码是 ${code}，10 分钟内有效。若非本人操作请忽略本邮件。`,
    });
  }
}