# Task 7: AccountController + DTO + Module + 注册 + e2e

**Files:**
- Create: `lumira-server/packages/backend/src/modules/account/dto/recover-by-qr.dto.ts`
- Create: `lumira-server/packages/backend/src/modules/account/dto/send-code.dto.ts`
- Create: `lumira-server/packages/backend/src/modules/account/dto/email-code.dto.ts`
- Create: `lumira-server/packages/backend/src/modules/account/account.controller.ts`
- Create: `lumira-server/packages/backend/src/modules/account/account.module.ts`
- Modify: `lumira-server/packages/backend/src/app.module.ts`
- Create: `lumira-server/packages/backend/test/account.e2e-spec.ts`

**Interfaces:**
- Consumes: `AccountService`（Task 5/6，含 rotateRecoverySecret/recoverByQr/sendEmailCode/bindEmail/recoverByEmail）、`DeviceAuthGuard`（Task 3）。
- Produces: 五个端点 `POST /api/v1/account/*`。

> 项目已有全局 `GlobalValidationPipe`（src/common/pipes/global-validation.pipe.ts 为 `new ValidationPipe({ whitelist:true, forbidNonWhitelisted:true, transform:true })`，已注册为 APP_PIPE）。因此 `@Body() dto: XxxDto` 会被自动校验，无需在 controller 内手动 plainToInstance+validate（feedback 手动校验是因为它是 multipart，字段不在 @Body 绑定内）。直接用 @Body() DTO 即可。

## Step 1: DTO 文件

`src/modules/account/dto/recover-by-qr.dto.ts`:
```ts
import { IsString, MinLength, MaxLength } from 'class-validator';
export class RecoverByQrDto {
  @IsString()
  @MinLength(8)
  @MaxLength(128)
  secret!: string;
}
```

`src/modules/account/dto/send-code.dto.ts`:
```ts
import { IsEmail, IsIn } from 'class-validator';
export class SendCodeDto {
  @IsEmail()
  email!: string;
  @IsIn(['bind', 'recover'])
  purpose!: 'bind' | 'recover';
}
```

`src/modules/account/dto/email-code.dto.ts`:
```ts
import { IsEmail, IsString, Matches } from 'class-validator';
export class EmailCodeDto {
  @IsEmail()
  email!: string;
  @IsString()
  @Matches(/^\d{6}$/)
  code!: string;
}
```

## Step 2: AccountController

`src/modules/account/account.controller.ts`:
```ts
import { Body, Controller, Post, Req, UseGuards } from '@nestjs/common';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { AccountService } from './account.service';
import { RecoverByQrDto } from './dto/recover-by-qr.dto';
import { SendCodeDto } from './dto/send-code.dto';
import { EmailCodeDto } from './dto/email-code.dto';

@Controller('account')
export class AccountController {
  constructor(private readonly accountService: AccountService) {}

  @Post('recovery-qr')
  @UseGuards(DeviceAuthGuard)
  recoveryQr(@Req() req: any) {
    return this.accountService.rotateRecoverySecret(req.deviceId);
  }

  @Post('recover-by-qr')
  recoverByQr(@Body() dto: RecoverByQrDto) {
    return this.accountService.recoverByQr(dto.secret);
  }

  @Post('email/send-code')
  sendCode(@Body() dto: SendCodeDto) {
    return this.accountService.sendEmailCode(dto.email, dto.purpose);
  }

  @Post('email/bind')
  @UseGuards(DeviceAuthGuard)
  bind(@Req() req: any, @Body() dto: EmailCodeDto) {
    return this.accountService.bindEmail(req.deviceId, dto.email, dto.code);
  }

  @Post('email/recover')
  recoverByEmail(@Body() dto: EmailCodeDto) {
    return this.accountService.recoverByEmail(dto.email, dto.code);
  }
}
```

## Step 2b: AccountModule

`src/modules/account/account.module.ts`:
```ts
import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { DeviceModule } from '../device/device.module';
import { AccountController } from './account.controller';
import { AccountService } from './account.service';
import { MailService } from './mail.service';

@Module({
  imports: [DatabaseModule, DeviceModule],
  controllers: [AccountController],
  providers: [AccountService, MailService],
  exports: [AccountService],
})
export class AccountModule {}
```
> 确认 MailService 需要被 DeviceModule 或其他模块过渡期 provider 覆盖？不需要——MailService 是本模块内 provider。DeviceModule 引入仅因 DeviceAuthGuard 需要 JwtService/这是既有惯例（若 DeviceModule 导出 JwtModule 供 guard 用，保留；否则按既有 feedback.module 的 imports 模式处理）。

## Step 3: 注册到 app.module

在 `src/app.module.ts`：import `AccountModule`，并在 `imports` 数组末尾加入 `AccountModule`。在 app.module.ts 其余部分不要改动。

## Step 4: 应用审查补强（针对 Task 6 的 3 项小修复）

在 `account.service.ts` 应用以下 3 项加固（不影响既有正确性，e2e 会覆盖）：
1. **一次性消费防竞态**：bindEmail 与 recoverByEmail 的消费 UPDATE 增加 `and(eq(accountOtp.consumedAt, null))`（先 import `isNull` 或直接用 `and(eq(::consumedAt, null))`，用 drizzle 的 `isNull`）。`where(and(eq(accountOtp.id, otp.id), isNull(accountOtp.consumedAt)))`。
2. **recoverByEmail 先校验设备存在再消费**：先 `select devices where email` 判断 device 存在，若不存在抛 `'该邮箱尚未绑定账号'`（不要再消费 OTP），通过后才消费 OTP + 递增 epoch。
3. **bindEmail 校验设备行**：绑定前确认 deviceId 存在（如 select 或检查 update 影响行数），不存在抛 400（`'设备不存在，请先注册'`）。

## Step 5: e2e 全流程

创建 `test/account.e2e-spec.ts`（setup 仿 device.e2e-spec）：

```ts
import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import { resetTestDatabase } from './test-db';
import request from 'supertest';
import { DatabaseService } from '../src/database/database.service';
import { accountOtp, devices as devicesTable } from '../src/database/schema';
import { eq } from 'drizzle-orm';
import { sha256Hex } from '../src/modules/account/hash';

describe('Account (e2e)', () => {
  let app: NestFastifyApplication;
  let dbService: DatabaseService;
  const deviceId = '550e8400-e29b-41d4-a716-446655441111';
  let token: string;

  beforeAll(async () => {
    process.env.DB_HOST = process.env.DB_HOST || '127.0.0.1';
    process.env.DB_PORT = process.env.DB_PORT || '3306';
    process.env.DB_USER = process.env.DB_USER || 'root';
    process.env.DB_PASSWORD = process.env.DB_PASSWORD || 'root';
    process.env.DB_NAME = process.env.DB_NAME || 'lumira_test';
    process.env.JWT_SECRET = 'test-secret';
    await resetTestDatabase();
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication<NestFastifyApplication>(new FastifyAdapter());
    app.setGlobalPrefix('api/v1');
    await app.init();
    await app.getHttpAdapter().getInstance().ready();
    dbService = moduleRef.get<DatabaseService>(DatabaseService);
    token = (await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId })).body.token as string;
  }, 30000);
  afterAll(async () => { await app.close(); });

  it('recovery-qr 生成并轮换密钥', async () => {
    const r1 = await request(app.getHttpServer())
      .post('/api/v1/account/recovery-qr')
      .set('Authorization', `Bearer ${token}`)
      .expect(201);
    expect(r1.body.secret).toHaveLength(43);
    expect(r1.body.qrPayload).toContain('lumira://account-recover');
    const r2 = await request(app.getHttpServer())
      .post('/api/v1/account/recovery-qr')
      .set('Authorization', `Bearer ${token}`)
      .expect(201);
    expect(r2.body.secret).not.toBe(r1.body.secret); // 轮换
  });

  it('recover-by-qr 用密钥取回 deviceId 并作废旧 token', async () => {
    const qr = await request(app.getHttpServer())
      .post('/api/v1/account/recovery-qr')
      .set('Authorization', `Bearer ${token}`)
      .then(r => r.body);
    const rec = await request(app.getHttpServer())
      .post('/api/v1/account/recover-by-qr')
      .send({ secret: qr.secret })
      .expect(201);
    expect(rec.body.deviceId).toBe(deviceId);
    // 旧 token 因 session_epoch 递增而失效
    await request(app.getHttpServer())
      .post('/api/v1/account/recovery-qr')
      .set('Authorization', `Bearer ${token}`)
      .expect(401);
  });

  it('recover-by-qr 非法密钥返回 400', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/account/recover-by-qr')
      .send({ secret: 'wrong-secret-value' })
      .expect(400);
  });

  it('email send-code 与限频', async () => {
    const email = 'user@example.com';
    await request(app.getHttpServer())
      .post('/api/v1/account/email/send-code')
      .send({ email, purpose: 'bind' })
      .expect(201);
    const r = await request(app.getHttpServer())
      .post('/api/v1/account/email/send-code')
      .send({ email, purpose: 'bind' });
    expect([429, 400]).toContain(r.status);
  });

  it('email bind / recover 成功闭环（直接插已知 OTP）', async () => {
    const email = 'bind@example.com';
    const code = '123456';
    const now = Math.floor(Date.now() / 1000);
    // bind：先 send-code 也可，但拿不到明文；改为直接插入已知 codeHash 的 OTP
    await request(app.getHttpServer())
      .post('/api/v1/account/email/send-code')
      .send({ email, purpose: 'bind' })
      .expect(201);
    // 直接在 DB 插入该邮箱已知码的 OTP（覆盖 send-code 生成的行，用最新一条）
    const inserted = await dbService.getDb().insert(accountOtp).values({
      email, deviceId: null, purpose: 'bind',
      codeHash: sha256Hex(code),
      expiresAt: now + 600, consumedAt: null, attempts: 0, createdAt: now,
    });
    // 绑定
    const bind = await request(app.getHttpServer())
      .post('/api/v1/account/email/bind')
      .set('Authorization', `Bearer ${token}`)
      .send({ email, code })
      .expect(201);
    expect(bind.body.success).toBe(true);

    // recover：换一个「新设备」场景——用 email recover 前先 send-code recover
    await request(app.getHttpServer())
      .post('/api/v1/account/email/send-code')
      .send({ email, purpose: 'recover' })
      .expect(201);
    await dbService.getDb().insert(accountOtp).values({
      email, deviceId: null, purpose: 'recover',
      codeHash: sha256Hex(code),
      expiresAt: now + 600, consumedAt: null, attempts: 0, createdAt: now,
    });
    const rec = await request(app.getHttpServer())
      .post('/api/v1/account/email/recover')
      .send({ email, code })
      .expect(201);
    expect(rec.body.deviceId).toBe(deviceId);
    // 旧 token 已因 epoch 递增失效
    await request(app.getHttpServer())
      .post('/api/v1/account/email/bind')
      .set('Authorization', `Bearer ${token}`)
      .send({ email, code })
      .expect(401);
  });

  it('未绑定邮箱的 recover 返回 400', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/account/email/recover')
      .send({ email: 'nobody@example.com', code: '123456' })
      .expect(400);
  });
});
```

> 注意事项：
> - `latestOtp` 按 id 倒序取最新一条，插入的已知 OTP id 最大，会被 validateOtp 取到。若担心 send-code 已生成的行与插入行重叠，可在插入前将原行 consumedAt 设非空（或用单独邮箱测试）。
> - recover 成功后旧 token 失效，因此绑定/恢复相关的后续请求需用新 token（re-register 拿新 token）或放在断言失效之后。
> - `recovery-qr`/`email/bind` 需要 DeviceAuthGuard；recover-by-qr/send-code/recover 是开放端点。
> - 若 `insert` 返回值类型有碍，可忽略返回值（不 `await` 强绑定，直接 `await db...insert(...)`）。

## Step 6: 跑后端全量内部单测 + e2e

```bash
cd lumira-server/packages/backend
pnpm test
# e2e 需要测试 MySQL（默认可用环境变量覆盖）
$env:DB_NAME='lumira_test'; $env:DB_PORT='3308'
pnpm test:e2e -- account.e2e-spec
```
Expected: 内部单测 4/4 + e2e 全绿。

## Step 7: 提交 + 推送

```bash
git add lumira-server/packages/backend/src/modules/account lumira-server/packages/backend/src/app.module.ts lumira-server/packages/backend/test/account.e2e-spec.ts
git commit -m "feat(account): add account module endpoints with e2e coverage"
git push origin master; git push github master
```
> 按 AGENTS.md，后端改动必须同时 push 到 origin(gitee) 与 github 两个 remote。

## 全局约束提醒

- 恢复密钥/验证码只存哈希（已实现，勿改动）。
- 迁移幂等、环境变量由 test-db.ts 处理。
- 工作目录：`d:\app\projects\photo_post`。