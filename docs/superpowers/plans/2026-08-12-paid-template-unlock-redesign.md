# 付费模板解锁机制改造实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将付费模板解锁收敛为"积分购买 + 兑换码兑换"两种真实方式，移除看广告/拍摄/¥3.00 假解锁，内置模板支持积分购买并记录到后端。

**Architecture:** 后端 `POST /templates/exchange` 按 templateId 前缀区分定价来源——`srv_` 前缀（远程模板）以后端 `template_prices` 表为准（防篡改），非 `srv_` 前缀（内置模板）以客户端上报 `priceCredits` 为准并 UPSERT 定价记录；Flutter 端解锁页精简为 3 个入口（积分购买 / 兑换码 / 分享跳邀请页），价格文案由 ¥ 改为积分。

**Tech Stack:** NestJS + Drizzle ORM + SQLite（后端）、Flutter 3.7.12 / Dart 2.19.6（客户端）、packages/shared TypeScript 契约。

## Global Constraints

- Dart 2.19.6 / Flutter 3.7.12：不支持 Dart 3 records 语法、不依赖新 API。
- 后端代码改动（`lumira-server/packages/backend/**` 与 `packages/shared/**`）每次完成后**必须 commit 并同时 push 到两个远程**：`origin`（gitee）与 `github`（github）。
- 后端验证命令：`pnpm --filter @lumira/backend typecheck`；e2e：`pnpm --filter @lumira/backend test:e2e`。
- Flutter 验证命令：`flutter analyze`（在 `lumira_app_flutter/` 目录）。
- 内置模板价格以客户端上报为准（用户改 Flutter 端 `price` 即生效），远程模板仍由后端 Admin 定价。
- 不新增表/迁移；购买记录沿用 `owned_templates` + `point_transactions`。
- 解锁页最终只有 3 个入口：积分购买、输入兑换码、分享给好友（跳转邀请有礼页 `/profile/invite`）。

---

### Task 1: 后端共享契约扩展（ExchangeTemplateRequest / DTO 增加 priceCredits）

**Files:**
- Modify: `lumira-server/packages/shared/src/types/points.ts:70-72`
- Modify: `lumira-server/packages/backend/src/modules/templates/dto/exchange-template.dto.ts`

**Interfaces:**
- Produces: `ExchangeTemplateRequest.priceCredits?: number`（shared 类型）；`ExchangeTemplateDto.priceCredits?: number`（class-validator DTO，`@IsOptional() @IsInt() @Min(1)`）

- [ ] **Step 1: 修改 shared 类型**

`lumira-server/packages/shared/src/types/points.ts` 第 69-72 行：

```ts
// 积分兑换模板请求
export interface ExchangeTemplateRequest {
  templateId: string;
  priceCredits?: number; // 内置模板（id 无 srv_ 前缀）必填，客户端上报积分价格（≥1）
}
```

- [ ] **Step 2: 修改后端 DTO**

`lumira-server/packages/backend/src/modules/templates/dto/exchange-template.dto.ts` 整文件：

```ts
// lumira-server/packages/backend/src/modules/templates/dto/exchange-template.dto.ts

import { IsString, MinLength, MaxLength, IsOptional, IsInt, Min } from 'class-validator';

export class ExchangeTemplateDto {
  @IsString()
  @MinLength(1)
  @MaxLength(128)
  templateId!: string;

  // 内置模板（id 无 srv_ 前缀）积分价格，客户端上报，≥1
  @IsOptional()
  @IsInt()
  @Min(1)
  priceCredits?: number;
}
```

- [ ] **Step 3: 验证类型检查**

Run（在 `lumira-server/` 下）: `pnpm --filter @lumira/backend typecheck`
Expected: PASS（无新增错误）

- [ ] **Step 4: Commit + push 双远程**

```bash
git add lumira-server/packages/shared/src/types/points.ts lumira-server/packages/backend/src/modules/templates/dto/exchange-template.dto.ts
git commit -m "feat(shared/backend): exchange 请求支持 priceCredits 内置模板积分价"
git push origin master
git push github master
```

---

### Task 2: 后端 exchange 按模板类型区分定价 + e2e 测试

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/templates/templates.service.ts:57-106`
- Modify: `lumira-server/packages/backend/src/modules/templates/templates.controller.ts:42-48`
- Create: `lumira-server/packages/backend/test/templates.e2e-spec.ts`

**Interfaces:**
- Consumes: `ExchangeTemplateDto.priceCredits?: number`（Task 1）
- Produces: `TemplatesService.exchange(deviceId: string, templateId: string, priceCredits?: number)` → `{ success, templateId, spentCredits, balance }`

- [ ] **Step 1: 写失败测试**

创建 `lumira-server/packages/backend/test/templates.e2e-spec.ts`：

```ts
// lumira-server/packages/backend/test/templates.e2e-spec.ts
import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import { DatabaseService } from '../src/database/database.service';
import { userPoints, templatePrices } from '../src/database/schema';
import request from 'supertest';

describe('TemplatesController (e2e) — exchange', () => {
  let app: NestFastifyApplication;
  let dbService: DatabaseService;
  let token: string;

  const deviceId = '44444444-4444-4444-8444-444444444444';

  beforeAll(async () => {
    process.env.DB_PATH = ':memory:';
    process.env.JWT_SECRET = 'test-secret';

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication<NestFastifyApplication>(new FastifyAdapter());
    app.setGlobalPrefix('api/v1');
    await app.init();
    await app.getHttpAdapter().getInstance().ready();

    dbService = moduleRef.get<DatabaseService>(DatabaseService);

    // 注册设备
    const res = await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId });
    token = res.body.token;

    // 充值 100 积分
    const now = Math.floor(Date.now() / 1000);
    await dbService.getDb().insert(userPoints).values({
      deviceId,
      balance: 100,
      totalEarned: 100,
      totalSpent: 0,
      updatedAt: now,
    }).run();
  });

  afterAll(async () => {
    await app.close();
  });

  it('内置模板积分兑换成功，按客户端上报价扣费并记录定价', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/templates/exchange')
      .set('Authorization', `Bearer ${token}`)
      .send({ templateId: 'film_vintage', priceCredits: 20 })
      .expect(201);

    expect(res.body.success).toBe(true);
    expect(res.body.spentCredits).toBe(20);
    expect(res.body.balance).toBe(80);

    // 定价已记录到 template_prices
    const db = dbService.getDb();
    const price = await db.query.templatePrices.findFirst({
      where: (t, { eq }) => eq(t.templateId, 'film_vintage'),
    });
    expect(price?.priceCredits).toBe(20);

    // owned 记录存在
    const owned = await request(app.getHttpServer())
      .get('/api/v1/templates/owned')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(owned.body.templateIds).toContain('film_vintage');
  });

  it('内置模板重复兑换返回 409', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/templates/exchange')
      .set('Authorization', `Bearer ${token}`)
      .send({ templateId: 'film_vintage', priceCredits: 20 })
      .expect(409);
  });

  it('内置模板缺少 priceCredits 返回 400', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/templates/exchange')
      .set('Authorization', `Bearer ${token}`)
      .send({ templateId: 'macro_flower' })
      .expect(400);
  });

  it('内置模板 priceCredits 为 0 返回 400', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/templates/exchange')
      .set('Authorization', `Bearer ${token}`)
      .send({ templateId: 'macro_flower', priceCredits: 0 })
      .expect(400);
  });

  it('积分余额不足返回 400', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/templates/exchange')
      .set('Authorization', `Bearer ${token}`)
      .send({ templateId: 'neon_portrait', priceCredits: 9999 })
      .expect(400);
  });

  it('srv_ 远程模板无定价记录返回 404', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/templates/exchange')
      .set('Authorization', `Bearer ${token}`)
      .send({ templateId: 'srv_notexist', priceCredits: 20 })
      .expect(404);
  });

  it('srv_ 远程模板按后端定价扣费，忽略客户端上报价', async () => {
    const now = Math.floor(Date.now() / 1000);
    await dbService.getDb().insert(templatePrices).values({
      templateId: 'srv_priced',
      priceCredits: 30,
      isActive: 1,
      updatedAt: now,
    }).run();

    const res = await request(app.getHttpServer())
      .post('/api/v1/templates/exchange')
      .set('Authorization', `Bearer ${token}`)
      .send({ templateId: 'srv_priced', priceCredits: 1 })
      .expect(201);

    expect(res.body.spentCredits).toBe(30);
    expect(res.body.balance).toBe(50); // 80 - 30
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `pnpm --filter @lumira/backend test:e2e -- templates.e2e-spec`
Expected: 测试因 "Template not available for exchange"（404）等原因 FAIL（priceCredits 未生效）

- [ ] **Step 3: 改造 exchange service**

`lumira-server/packages/backend/src/modules/templates/templates.service.ts` 将 `exchange` 方法（57-106 行）整体替换为：

```ts
  /** 积分兑换模板 */
  async exchange(deviceId: string, templateId: string, priceCredits?: number) {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    // 1. 定价：srv_ 前缀（后端远程模板）以 template_prices 记录为准（防篡改）；
    //    非 srv_ 前缀（本地内置模板）以客户端上报 priceCredits 为准，并 UPSERT 记录定价
    let price: number;
    if (templateId.startsWith('srv_')) {
      const record = await db.query.templatePrices.findFirst({
        where: and(
          eq(templatePrices.templateId, templateId),
          eq(templatePrices.isActive, 1),
        ),
      });
      if (!record) {
        throw new NotFoundException('Template not available for exchange');
      }
      price = record.priceCredits;
    } else {
      if (priceCredits === undefined || !Number.isInteger(priceCredits) || priceCredits < 1) {
        throw new BadRequestException(
          'priceCredits must be a positive integer for builtin template',
        );
      }
      price = priceCredits;
      await db.insert(templatePrices)
        .values({ templateId, priceCredits: price, isActive: 1, updatedAt: now })
        .onConflictDoUpdate({
          target: templatePrices.templateId,
          set: { priceCredits: price, isActive: 1, updatedAt: now },
        }).run();
    }

    // 2. 检查是否已拥有（幂等：已拥有则直接返回成功）
    const existing = await db.query.ownedTemplates.findFirst({
      where: and(
        eq(ownedTemplates.deviceId, deviceId),
        eq(ownedTemplates.templateId, templateId),
      ),
    });
    if (existing) {
      throw new ConflictException('Template already owned');
    }

    // 3. 扣积分（余额不足会抛 BadRequestException）
    const newBalance = await this.pointsService.spendPoints(
      deviceId,
      price,
      'exchange_template',
      templateId,
    );

    // 4. 写入拥有记录
    await db.insert(ownedTemplates).values({
      deviceId,
      templateId,
      source: 'points',
      sourceDetail: `credits:${price}`,
      unlockedAt: now,
    }).run();

    return {
      success: true,
      templateId,
      spentCredits: price,
      balance: newBalance,
    };
  }
```

- [ ] **Step 4: 修改 controller 传参**

`lumira-server/packages/backend/src/modules/templates/templates.controller.ts` 第 42-48 行：

```ts
  @Post('exchange')
  async exchange(
    @DeviceId() deviceId: string,
    @Body() dto: ExchangeTemplateDto,
  ) {
    return this.templatesService.exchange(deviceId, dto.templateId, dto.priceCredits);
  }
```

- [ ] **Step 5: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend test:e2e -- templates.e2e-spec`
Expected: 全部 7 个用例 PASS

- [ ] **Step 6: typecheck + commit + push 双远程**

Run: `pnpm --filter @lumira/backend typecheck`
Expected: PASS

```bash
git add lumira-server/packages/backend/src/modules/templates/templates.service.ts lumira-server/packages/backend/src/modules/templates/templates.controller.ts lumira-server/packages/backend/test/templates.e2e-spec.ts
git commit -m "feat(backend): exchange 支持内置模板积分兑换并按类型区分定价来源"
git push origin master
git push github master
```

---

### Task 3: Flutter owned_templates_repository 支持 priceCredits

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/data/owned_templates_repository.dart:107-142`

**Interfaces:**
- Consumes: `TemplateExchangeResult`（`lib/features/points/data/points_models.dart`，无需改动）
- Produces: `exchange(String templateId, {int? priceCredits})` — Task 5 解锁页调用

- [ ] **Step 1: 修改抽象方法与实现**

`owned_templates_repository.dart`：

第 107-111 行（抽象方法）：
```dart
abstract class OwnedTemplatesRepository {
  Future<OwnedTemplates> listOwned();
  Future<TemplatePrices> listPrices();
  Future<TemplateExchangeResult> exchange(String templateId, {int? priceCredits});
}
```

第 134-142 行（实现）：
```dart
  @override
  Future<TemplateExchangeResult> exchange(String templateId, {int? priceCredits}) {
    return _api.post(
      '/templates/exchange',
      body: {
        'templateId': templateId,
        if (priceCredits != null) 'priceCredits': priceCredits,
      },
      fromJson: (j) =>
          TemplateExchangeResult.fromJson(j as Map<String, dynamic>),
    );
  }
```

- [ ] **Step 2: 验证**

Run（在 `lumira_app_flutter/` 下）: `flutter analyze`
Expected: 无新增错误（调用方 `_onPurchase` 仍以无参调用，兼容）

- [ ] **Step 3: Commit**

```bash
git add lumira_app_flutter/lib/features/templates/data/owned_templates_repository.dart
git commit -m "feat(flutter): exchange 支持可选 priceCredits 参数"
```

---

### Task 4: 内置模板定价（20/40/60 三档）+ mock 冲突清理

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/data/templates/film_vintage.dart`（price 3→20）
- Modify: `lumira_app_flutter/lib/features/capture/data/templates/macro_flower.dart`（3→20）
- Modify: `lumira_app_flutter/lib/features/capture/data/templates/neon_portrait.dart`（3→20）
- Modify: `lumira_app_flutter/lib/features/capture/data/templates/urban_architecture.dart`（3→20）
- Modify: `lumira_app_flutter/lib/features/capture/data/templates/blue_night_portrait.dart`（3→40）
- Modify: `lumira_app_flutter/lib/features/capture/data/templates/dark_indoor_portrait.dart`（3→40）
- Modify: `lumira_app_flutter/lib/features/capture/data/templates/anime_dream_portrait.dart`（3→40）
- Modify: `lumira_app_flutter/lib/features/capture/data/templates/french_lazy_portrait.dart`（3→40）
- Modify: `lumira_app_flutter/lib/features/capture/data/templates/y2k_portrait.dart`（3→40）
- Modify: `lumira_app_flutter/lib/features/capture/data/templates/neon_city_portrait.dart`（3→40）
- Modify: `lumira_app_flutter/lib/features/capture/data/templates/elegant_lady_portrait.dart`（3→60）
- Modify: `lumira_app_flutter/lib/features/capture/data/templates/morandi_minimal_portrait.dart`（3→60）
- Modify: `lumira_app_flutter/lib/features/capture/data/templates/purple_dusk_portrait.dart`（3→60）
- Modify: `lumira_app_flutter/lib/features/templates/data/templates_browse_mock_data.dart`（macro_flower 0→20、golden_landscape 18→0，各 2 处）

**Interfaces:**
- Produces: 13 个付费内置模板 `price` 字段新值（详情页/解锁页/拍摄页共享同一数据源）

- [ ] **Step 1: 修改 13 个模板文件 price**

每个文件定位 `price: 3,`（第 16 行附近，模板常量 `PhotoTemplate` 的 meta 中），按上表改为对应值（20 / 40 / 60）。示例（`film_vintage.dart`）：

```dart
      price: 20,
```

- [ ] **Step 2: 清理 mock 价格冲突**

`templates_browse_mock_data.dart`：
- details 中 `macro_flower` 模板（约 805-866 行区间）`price: 0` → `price: 20`
- details 中 `golden_landscape` 模板（约 589-650 行区间）`price: 18` → `price: 0`
- allTemplates 中 `macro_flower`（约 1207-1217 行区间）`price: 0` → `price: 20`
- allTemplates 中 `golden_landscape`（约 1217-1227 行区间）`price: 18` → `price: 0`

> 说明：details/allTemplates 中其余非 registry 付费模板（still_life_warm 12、night_neon 24、landscape_panorama 18、custom_golden_landscape 18）为旧视觉规格残留，不在本次范围，保持原样。

- [ ] **Step 3: 验证**

Run: `flutter analyze`
Expected: 无新增错误

- [ ] **Step 4: Commit**

```bash
git add lumira_app_flutter/lib/features/capture/data/templates/ lumira_app_flutter/lib/features/templates/data/templates_browse_mock_data.dart
git commit -m "feat(flutter): 内置付费模板定价 20/40/60 三档并统一 mock 冲突价格"
```

---

### Task 5: 解锁页精简为"积分购买 / 兑换码 / 分享跳邀请页"

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/pages/templates_unlock_page.dart`
- Modify: `lumira_app_flutter/lib/app/router.dart:191-198`

**Interfaces:**
- Consumes: `OwnedTemplatesRepository.exchange(templateId, {priceCredits})`（Task 3）；`RouteNames.profileInvite`（`core/router/route_names.dart`，已存在）
- Produces: `TemplatesUnlockPage({templateId, price})`

- [ ] **Step 1: 页面增加 price 参数**

`templates_unlock_page.dart` 第 28-37 行：

```dart
class TemplatesUnlockPage extends ConsumerStatefulWidget {
  const TemplatesUnlockPage({super.key, this.templateId, this.price});

  /// 路由参数：模板 id
  final String? templateId;

  /// 路由参数：积分价格（由详情页传入，内置模板用）
  final int? price;

  @override
  ConsumerState<TemplatesUnlockPage> createState() =>
      _TemplatesUnlockPageState();
}
```

- [ ] **Step 2: 移除假解锁方法，改造分享跳邀请页**

`templates_unlock_page.dart` 第 50-65 行替换为：

```dart
  void _onShare() {
    // 分享给好友 → 跳转邀请有礼页，通过邀请获取积分 / 兑换模板
    GoRouter.of(context).push(RouteNames.profileInvite);
  }
```

同时删除 `_onWatchAd` 与 `_onGoCapture` 两个方法。

- [ ] **Step 3: 积分购买走真实价格**

`templates_unlock_page.dart` 第 109-140 行 `_onPurchase` 整体替换为：

```dart
  Future<void> _onPurchase() async {
    final templateId = widget.templateId;
    final price = widget.price;
    if (templateId == null || templateId.isEmpty) {
      lumira.LumiraToast.show(context, '缺少模板信息');
      return;
    }
    if (price == null || price < 1) {
      lumira.LumiraToast.show(context, '缺少模板积分价格');
      return;
    }
    final confirmed = await lumira.showLumiraDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _PayPopupContent(
        price: price,
        onCancel: () => Navigator.pop(context, false),
        onConfirm: () => Navigator.pop(context, true),
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    try {
      final repo = await ref.read(ownedTemplatesRepositoryProvider.future);
      final result = await repo.exchange(templateId, priceCredits: price);
      if (!mounted) return;
      // 刷新 owned 缓存
      ref.invalidate(ownedTemplatesLoaderProvider);
      setState(() => _unlocked = true);
      lumira.LumiraToast.show(
        context,
        '解锁成功！消耗 ${result.spentCredits} 积分，余额 ${result.balance}',
      );
    } catch (e) {
      if (!mounted) return;
      lumira.LumiraToast.show(context, '兑换失败：$e');
    }
  }
```

- [ ] **Step 4: _OptionsList 精简为 3 项**

`templates_unlock_page.dart` 第 494-606 行 `_OptionsList` 构造函数与 build 替换为（移除 onWatchAd / onGoCapture，保留 onShare / onInputCode / onPurchase，并将积分购买卡片置顶显示真实价格）：

```dart
class _OptionsList extends StatelessWidget {
  const _OptionsList({
    required this.tokens,
    required this.price,
    required this.onShare,
    required this.onInputCode,
    required this.onPurchase,
  });

  final ThemeTokens tokens;
  final int? price;
  final VoidCallback onShare;
  final Future<void> Function() onInputCode;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FadeUp(
          delay: const Duration(milliseconds: 80),
          child: _OptionCard(
            tokens: tokens,
            icon: Icons.star, // Flutter 3.7.12 无 Icons.diamond_outlined，用 Icons.star 替代
            iconBgColor: tokens.brandSubtle,
            iconColor: tokens.brand,
            title: '${price ?? 0} 积分解锁',
            desc: '消耗积分，永久使用',
            titleStrong: true,
            brandBorder: true,
            button: _SmallBrandButton(
              tokens: tokens,
              label: '积分购买',
              onTap: onPurchase,
            ),
          ),
        ),
        const SizedBox(height: 12),
        FadeUp(
          delay: const Duration(milliseconds: 160),
          child: _OptionCard(
            tokens: tokens,
            icon: Icons.vpn_key_outlined,
            iconBgColor: tokens.surfaceAlt,
            iconColor: tokens.brand,
            title: '输入兑换码',
            desc: '使用兑换码直接解锁模板',
            button: _SmallOutlineButton(
              tokens: tokens,
              label: '输入',
              onTap: onInputCode,
            ),
          ),
        ),
        const SizedBox(height: 12),
        FadeUp(
          delay: const Duration(milliseconds: 240),
          child: _OptionCard(
            tokens: tokens,
            icon: Icons.send_outlined,
            iconBgColor: tokens.surfaceAlt,
            iconColor: tokens.brand,
            title: '分享给好友',
            desc: '邀请好友赚积分 / 兑换模板',
            button: _SmallOutlineButton(
              tokens: tokens,
              label: '去邀请',
              onTap: onShare,
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: 更新页面 build 中 _OptionsList 调用**

`templates_unlock_page.dart` 第 191-198 行：

```dart
                              _OptionsList(
                                tokens: tokens,
                                price: widget.price,
                                onShare: _onShare,
                                onInputCode: _onInputCode,
                                onPurchase: _onPurchase,
                              ),
```

- [ ] **Step 6: _PayPopupContent 积分化**

`templates_unlock_page.dart` 第 877-989 行 `_PayPopupContent` 增加 `price` 参数并把 ¥3.00 文案改为积分：

```dart
class _PayPopupContent extends ConsumerWidget {
  const _PayPopupContent({
    required this.price,
    required this.onCancel,
    required this.onConfirm,
  });

  final int price;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
```

build 中标题 `'确认支付'` → `'积分解锁'`；金额区 `'¥3.00'` → `'$price 积分'`；副标题 `'日系胶片 · 精选模板 · 永久使用'` → `'消耗 $price 积分，永久解锁该模板'`；按钮 `'确认支付'` → `'确认解锁'`。

- [ ] **Step 7: router 传递 price 参数**

`router.dart` 第 191-198 行：

```dart
      GoRoute(
        path: RouteNames.templatesUnlock,
        name: 'templatesUnlock',
        builder: (context, state) {
          final templateId = state.queryParams[RouteNames.paramTemplateId];
          final priceStr = state.queryParams['price'];
          return TemplatesUnlockPage(
            templateId: templateId,
            price: priceStr != null ? int.tryParse(priceStr) : null,
          );
        },
      ),
```

- [ ] **Step 8: 验证**

Run: `flutter analyze`
Expected: 无新增错误（确认无残留引用 `_onWatchAd` / `_onGoCapture`）

- [ ] **Step 9: Commit**

```bash
git add lumira_app_flutter/lib/features/templates/pages/templates_unlock_page.dart lumira_app_flutter/lib/app/router.dart
git commit -m "feat(flutter): 解锁页精简为积分购买/兑换码/分享跳邀请页"
```

---

### Task 6: 详情页与全部模板页价格文案积分化

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/pages/templates_detail_page.dart`
- Modify: `lumira_app_flutter/lib/features/templates/pages/templates_all_page.dart:1091-1115`

**Interfaces:**
- Consumes: `TemplatesUnlockPage({templateId, price})`（Task 5）
- Produces: 解锁页跳转 URL 携带 `price` 参数

- [ ] **Step 1: 详情页价格文案 ¥ → 积分**

`templates_detail_page.dart` 四处替换：

- 第 250-251 行：
```dart
    final unlockText =
        template.price == 0 ? '免费' : '${template.price} 积分';
```
- 第 713-715 行（标题行价格 tag）：`'免费' : '精选 ¥${template.price}'` → `'免费' : '${template.price} 积分'`
- 第 1416 行：`Text('购买 ¥$price')` → `Text('$price 积分解锁')`
- 第 1497 行：`'¥$price 永久解锁'` → `'$price 积分永久解锁'`

- [ ] **Step 2: 详情页跳解锁页带 price**

`templates_detail_page.dart` 第 86-102 行 `_goCapture` 与 `_goUnlock`：

```dart
    // 门禁：付费模板未拥有时跳解锁页
    final price = template.price;
    final owned = ref.read(ownedTemplateIdsProvider);
    if (price > 0 && !owned.contains(id)) {
      GoRouter.of(context).push(
        '${RouteNames.templatesUnlock}?templateId=$id&price=$price',
      );
      return;
    }
```

```dart
  void _goUnlock(TemplateDetail template) {
    GoRouter.of(context).push(
      '${RouteNames.templatesUnlock}?templateId=${template.id}&price=${template.price}',
    );
  }
```

- [ ] **Step 3: 全部模板页徽章积分化**

`templates_all_page.dart` 第 1091-1115 行 `_PremiumBadge` 的 `'¥$price'`（第 1106 行）→ `'$price 积分'`。

- [ ] **Step 4: 验证**

Run: `flutter analyze`
Expected: 无新增错误

- [ ] **Step 5: Commit**

```bash
git add lumira_app_flutter/lib/features/templates/pages/templates_detail_page.dart lumira_app_flutter/lib/features/templates/pages/templates_all_page.dart
git commit -m "feat(flutter): 模板价格文案由 ¥ 改为积分，解锁跳转携带价格"
```

---

## 验证清单（全部任务完成后）

1. 后端：`pnpm --filter @lumira/backend typecheck` PASS；`pnpm --filter @lumira/backend test:e2e` 全绿。
2. Flutter：`flutter analyze` 无新增错误。
3. 手动冒烟：内置付费模板详情页显示"20 积分"→ 解锁页 3 个入口 → 积分购买确认弹窗"消耗 20 积分" → 兑换成功 → 详情页解锁；积分流水出现 `exchange_template` 负向记录；`GET /templates/prices` 返回内置模板定价。
