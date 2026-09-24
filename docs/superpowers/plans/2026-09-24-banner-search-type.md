# 运营 Banner 新增「App 内搜索」类型 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让运营后台可配置 `kind=search` 的 Banner（搜索关键字 + 搜索范围），App 点击后跳转全局搜索页并预填关键字自动搜索。

**Architecture:** 复用现有 `ad` 的「无条件直接展示 + 按 `.position` 归位插入首页轮播」语义，不引入新机制。四层改动：后端存储/DTO/service 下发两个新字段 → 后台表单支持配置 → Flutter 模型解析 + 推荐分组重构 + 路由透传 → 三层测试。

**Tech Stack:** NestJS + Drizzle ORM + MySQL（后端）；Next.js + shadcn/ui（后台）；Flutter 3.7.12 / Dart 2.19.6 + GoRouter 6.5.7（Flutter）。

## Global Constraints

- Dart 版本为 2.19.6，**禁用 Dart 3 records 语法**。
- UI 一律复用 `HomeBannerItem` / `operationBannerToItem` 通道，`kind=search` 与 `ad` 一样走 `position` 归位组，**不参与 `matchOperationBanner` 条件匹配**。
- 后端 `operation-banner.rules.ts` **不修改**（`OPERATION_BANNER_ROUTES`/`CONDITIONS` 仅约束 `kind=operation`）。
- search 类型跳转 App 内路由，**不写 `externalUrl`**；若运营误填，App 端以 `kind` 为准忽略 `externalUrl`。
- 迁移文件为唯一文件名（`_migrations` 表按文件名幂等）。已存在 `037_ai_silhouette_platform.sql`…`043_*`，故新迁移用 **`044_banner_search.sql`**。
- 后端/后台每完成一次改动必须 git commit 并 push **双远程**（`origin`=gitee master、`github`=github master）。Flutter 改动仅 `flutter analyze` + `flutter test` 验证。

---

### Task 1: 后端迁移 044 + schema.ts 两列

**Files:**
- Create: `lumira-server/packages/backend/src/database/migrations/044_banner_search.sql`
- Modify: `lumira-server/packages/backend/src/database/schema.ts`（`operationBanners`，约 L341 `externalUrl` 之后）

**Interfaces:**
- Consumes: 无
- Produces: DB 列 `search_keyword`(varchar128 NULL)、`search_scope`(varchar16 NULL DEFAULT 'all')；schema 字段 `searchKeyword`、`searchScope`。后续 Task 2/3 依赖。

- [ ] **Step 1: 写迁移文件**

`lumira-server/packages/backend/src/database/migrations/044_banner_search.sql`
```sql
-- lumira-server/packages/backend/src/database/migrations/044_banner_search.sql
-- 首页 Banner 新增「App 内搜索」类型（kind=search）：
--   search_keyword : App 内搜索关键字（kind=search 时必填，跳转全局搜索页并预填）
--   search_scope   : 搜索范围，all=全部 / template=模板 / scene=场景 / academy=美学院（默认 all）
-- NULL 兼容旧数据与非 search 条目；App 读取时 search_scope 空回退 all。
ALTER TABLE `operation_banners`
  ADD COLUMN `search_keyword` varchar(128) NULL AFTER `external_url`,
  ADD COLUMN `search_scope` varchar(16) NULL DEFAULT 'all' AFTER `search_keyword`;
```

- [ ] **Step 2: 修改 schema.ts**

在 `operation_banners` 定义中，`externalUrl` 字段行之后追加：
```ts
  // App 内搜索类型（kind=search）：跳转全局搜索页并预填关键字（spec 2026-09-24）
  searchKeyword: varchar('search_keyword', { length: 128 }),
  searchScope: varchar('search_scope', { length: 16 }).default('all'),
```

- [ ] **Step 3: 类型检查**

Run: `pnpm --filter @lumira/backend build`（cwd: `lumira-server/packages/backend`）
Expected: 编译通过，无 TS 错误。

- [ ] **Step 4: Commit**

```bash
git add lumira-server/packages/backend/src/database/migrations/044_banner_search.sql lumira-server/packages/backend/src/database/schema.ts
git commit -m "feat(backend): 运营 Banner 新增 search 类型存储列（044 迁移）"
```

---

### Task 2: 后端 DTO schema（create + update）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/banners/dto/create-banner.dto.ts`
- Modify: `lumira-server/packages/backend/src/modules/banners/dto/update-banner.dto.ts`

**Interfaces:**
- Consumes: Task 1 的 DB 列（DTO 仅是校验层，不依赖具体列）。
- Produces: `CreateBannerDto.searchKeyword?: string`、`.searchScope?: string`；`UpdateBannerDto.searchKeyword?: string | null`、`.searchScope?: string`。供 Task 3 service 使用。

- [ ] **Step 1: create-banner.dto.ts 放开 kind 三选一 + 加两个可选字段**

将 `kind` 的 `@IsIn(['operation', 'ad'])` 改为 `@IsIn(['operation', 'ad', 'search'])`（原文 L33）；在 `position` 字段之前追加：
```ts
  /** App 内搜索关键字（kind=search 时必填，非空校验） */
  @ValidateIf((o: CreateBannerDto) => o.kind === 'search')
  @IsString()
  @IsNotEmpty()
  @MaxLength(128)
  searchKeyword?: string;

  /** 搜索范围：all=全部 / template=模板 / scene=场景 / academy=美学院（默认 all） */
  @IsOptional()
  @IsIn(['all', 'template', 'scene', 'academy'])
  searchScope?: string;
```

- [ ] **Step 2: update-banner.dto.ts 同步**

将 `kind` 的 `@IsIn(['operation', 'ad'])` 改为 `@IsIn(['operation', 'ad', 'search'])`（原文 L36）；在 `externalUrl` 之后、`position` 之前追加：
```ts
  /** App 内搜索关键字（kind=search 时必填）；null/空串清除 */
  @IsOptional()
  @ValidateIf((o: UpdateBannerDto) => o.kind === 'search')
  @IsString()
  @IsNotEmpty()
  @MaxLength(128)
  searchKeyword?: string | null;

  /** 搜索范围：all=全部 / template=模板 / scene=场景 / academy=美学院（默认 all） */
  @IsOptional()
  @IsIn(['all', 'template', 'scene', 'academy'])
  searchScope?: string;
```

- [ ] **Step 3: 类型检查**

Run: `pnpm --filter @lumira/backend build`
Expected: 编译通过。

- [ ] **Step 4: Commit**

```bash
git add lumira-server/packages/backend/src/modules/banners/dto/create-banner.dto.ts lumira-server/packages/backend/src/modules/banners/dto/update-banner.dto.ts
git commit -m "feat(backend): Banner DTO 支持 kind=search 的 searchKeyword/searchScope"
```

---

### Task 3: 后端 service 写入/下发 + 单元测试

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/banners/banners.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/banners/banners.service.spec.ts`

**Interfaces:**
- Consumes: Task 2 的 DTO 字段。
- Produces: `listForApp()` 下发 `searchKeyword`/`searchScope`；`create`/`update` 落库两字段。供 Task 8 Flutter 解析依赖。

- [ ] **Step 1: 写失败测试**（追加到 `banners.service.spec.ts`）

在 `import { CreateBannerDto }` 现有行后追加类型（若需）无需改 import；在 describe 末尾追加：
```ts
  it('listForApp 下发 search 条目的 searchKeyword/searchScope', async () => {
    const { service } = buildService({
      selectRows: [{
        ...ROW, kind: 'search', position: 2,
        searchKeyword: '电影感人像 侧拍', searchScope: 'template',
      }],
    });
    const res = await service.listForApp();
    expect(res.banners[0]).toMatchObject({
      kind: 'search',
      searchKeyword: '电影感人像 侧拍',
      searchScope: 'template',
    });
  });

  it('create 透传 searchKeyword/默认 searchScope=all 落库', async () => {
    const { service, insertValues } = buildService();
    await service.create({
      ...CREATE_DTO, kind: 'search',
      searchKeyword: '窗光人像', searchScope: 'scene',
    });
    const row = insertValues.mock.calls[0][0];
    expect(row.searchKeyword).toBe('窗光人像');
    expect(row.searchScope).toBe('scene');
  });

  it('create kind=search 未传 searchScope 时默认 all、searchKeyword 空转为 null', async () => {
    const { service, insertValues } = buildService();
    await service.create({ ...CREATE_DTO, kind: 'search', searchKeyword: '' });
    const row = insertValues.mock.calls[0][0];
    expect(row.searchScope).toBe('all');
    expect(row.searchKeyword).toBeNull();
  });

  it('update 可 patch searchKeyword/searchScope；空串清除 searchKeyword', async () => {
    const { service, updateSet } = buildService({ selectRows: [ROW] });
    await service.update('op_invite', { searchKeyword: '', searchScope: 'all' });
    const patch = updateSet.mock.calls[0][0];
    expect(patch.searchKeyword).toBeNull();
    expect(patch.searchScope).toBe('all');
  });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `pnpm --filter @lumira/backend test -- banners.service.spec`
Expected: `listForApp 下发 search…`、`create 透传 searchKeyword…` 失败（`searchKeyword undefined`），其余通过。

- [ ] **Step 3: 实现 service**

（a）`listForApp` 映射对象末尾补两字段（`externalUrl: r.externalUrl ?? null` 之后）：
```ts
        searchKeyword: r.searchKeyword ?? null,
        searchScope: r.searchScope || 'all',
```
（b）`create` 的 `values` 里，`externalUrl` 之后补：
```ts
      searchKeyword: dto.searchKeyword || null,
      searchScope: dto.searchScope || 'all',
```
（c）`update` 里，`externalUrl` 处理后补：
```ts
    // searchKeyword：空串/缺省清除；searchScope：缺省置 all
    if ('searchKeyword' in dto) patch.searchKeyword = dto.searchKeyword || null;
    if (dto.searchScope !== undefined) patch.searchScope = dto.searchScope || 'all';
```
（d）`listAdmin` 透传原生行（`{ ...r, imageUrl }`）已含新列，无需改动。

- [ ] **Step 4: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend test -- banners.service.spec`
Expected: 全部通过。

- [ ] **Step 5: 类型检查 + Commit**

Run: `pnpm --filter @lumira/backend build`
Expected: 编译通过。

```bash
git add lumira-server/packages/backend/src/modules/banners/banners.service.ts lumira-server/packages/backend/src/modules/banners/banners.service.spec.ts
git commit -m "feat(backend): Banner service 落库与下发 searchKeyword/searchScope"
```

- [ ] **Step 6: Push 双远程（后端改动完成后）**

```bash
git push origin master
git push github master
```

---

### Task 4: 后台类型与 actions 透传

**Files:**
- Modify: `lumira-server/packages/admin/src/types/admin.ts`（`BannerAdminItem` / `BannerPayload`）
- Modify: `lumira-server/packages/admin/src/actions/banners.ts`（无逻辑改动，确认透传即可）

**Interfaces:**
- Consumes: 无（类型自洽）。
- Produces: `BannerAdminItem.searchKeyword?: string | null`、`.searchScope?: string`；`BannerPayload.searchKeyword?: string | null`、`.searchScope?: string`。供 Task 5 表单使用。

- [ ] **Step 1: types/admin.ts 补字段**

`BannerAdminItem`（L388 `updatedAt` 之前）追加：
```ts
  /** App 内搜索关键字（kind=search 时必填） */
  searchKeyword?: string | null;
  /** 搜索范围：all=全部 / template=模板 / scene=场景 / academy=美学院 */
  searchScope?: string;
```
`BannerPayload`（L412 `sortOrder` 之前）追加：
```ts
  /** App 内搜索关键字（kind=search 时必填） */
  searchKeyword?: string | null;
  /** 搜索范围：all=全部 / template=模板 / scene=场景 / academy=美学院 */
  searchScope?: string;
```

- [ ] **Step 2: actions/banners.ts 不需改动**

`saveBanner` 把 `BannerPayload` 原样交给 `api.createBanner/updateBanner`，已透传任意 payload 字段。确认无字段白名单即可跳过本文件改动。

- [ ] **Step 3: 构建验证**

Run: `pnpm --filter @lumira/admin build`（cwd: `lumira-server/packages/admin`）
Expected: 构建通过。

- [ ] **Step 4: Commit + Push 双远程**

```bash
git add lumira-server/packages/admin/src/types/admin.ts
git commit -m "feat(admin): Banner 类型补 searchKeyword/searchScope"
git push origin master
git push github master
```

---

### Task 5: 后台表单支持 search 类型

**Files:**
- Modify: `lumira-server/packages/admin/src/components/banner-manager.tsx`

**Interfaces:**
- Consumes: Task 4 的 `BannerAdminItem.searchKeyword/searchScope`、`BannerPayload` 两字段。
- Produces: `kind` 三选一（含「App内搜索」）；选中时渲染「搜索关键字」必填输入 + 「搜索范围」下拉；保存时校验关键字非空并随 payload 提交。

- [ ] **Step 1: FormState 与 EMPTY_FORM 补字段**

`interface FormState`（L71 `sortOrder` 前）加：
```ts
  searchKeyword: string;
  searchScope: string;
```
`EMPTY_FORM`（L88 `sortOrder` 前）加：
```ts
  searchKeyword: '',
  searchScope: 'all',
```

- [ ] **Step 2: openEdit 回填**

`openEdit` 的 setForm（L160 `templateId: b.templateId || ''` 附近）补：
```ts
      searchKeyword: b.searchKeyword || '',
      searchScope: b.searchScope || 'all',
```

- [ ] **Step 3: handleSubmit 校验 + payload**

校验块（L227 附近，`if (form.kind === 'ad' && ...)` 之后）追加：
```ts
    if (form.kind === 'search' && !(form.searchKeyword || '').trim()) {
      setError('App内搜索类型请填写搜索关键字');
      return;
    }
```
payload 对象（L241 `externalUrl` 之后）追加：
```ts
      searchKeyword: (form.searchKeyword || '').trim() || null,
      searchScope: form.searchScope || 'all',
```

- [ ] **Step 4: 种类下拉加 search 选项**

`SelectContent` 内（L580 `<SelectItem value="ad">广告</SelectItem>` 之后）追加：
```tsx
                    <SelectItem value="search">App内搜索</SelectItem>
```

- [ ] **Step 5: search 专属表单区**

在 `{form.kind === 'ad' && (...)}` 块之后追加：
```tsx
            {form.kind === 'search' && (
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div className="space-y-2">
                  <Label htmlFor="bnr-search-kw">搜索关键字 *</Label>
                  <Input
                    id="bnr-search-kw"
                    value={form.searchKeyword}
                    onChange={(e) => setForm({ ...form, searchKeyword: e.target.value })}
                    placeholder="如：电影感人像 侧拍"
                    maxLength={128}
                  />
                  <p className="text-xs text-muted-foreground">
                    点击该 Banner 后会在 App 内跳转全局搜索页，并按此关键字自动搜索。
                  </p>
                </div>
                <div className="space-y-2">
                  <Label>搜索范围</Label>
                  <Select
                    value={form.searchScope}
                    onValueChange={(v) => setForm({ ...form, searchScope: v })}
                  >
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">全部</SelectItem>
                      <SelectItem value="template">模板</SelectItem>
                      <SelectItem value="scene">场景</SelectItem>
                      <SelectItem value="academy">美学院</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
            )}
```

- [ ] **Step 6: 列表「跳转路由」列对 search 显示关键字**

L381 附近 `route` 列 `code` 内容保持 `b.route`（search 类型 route 为占位）。可选在 L377 角标处补：
```tsx
                    {b.kind === 'search' && <Badge variant="secondary">搜索</Badge>}
```

- [ ] **Step 7: 构建验证**

Run: `pnpm --filter @lumira/admin build`
Expected: 构建通过。

- [ ] **Step 8: Commit + Push 双远程**

```bash
git add lumira-server/packages/admin/src/components/banner-manager.tsx
git commit -m "feat(admin): Banner 表单支持 App内搜索（关键字+范围）"
git push origin master
git push github master
```

---

### Task 6: Flutter 模型——kind=search 解析与跳转路由

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/data/operation_banners.dart`

**Interfaces:**
- Consumes: Task 3 后端下发的 `kind='search'`、`searchKeyword`、`searchScope`。
- Produces: `OperationBannerKind.search` 枚举值、`OperationBanner.searchKeyword/searchScope` 字段、`operationBannerFromJson` 的 search 分支、`operationBannerToItem` 的 search 路由拼接。供 Task 7/8 使用。

- [ ] **Step 1: 写失败测试**（追加到 `test/features/home/operation_banners_test.dart`，Task 9 合并一次跑；此处先只写实现保证可控）

> 说明：测试集中在 Task 9 统一写入并运行，本任务仅实现模型。为满足 TDD，先在下方 Task 9 写断言、本任务先实现。

实际上更稳妥：**在本任务内先加测试**。追加到 `operation_banners_test.dart` 末尾 `import 'package:lumira_app_flutter/shared/searchengine/search_scope.dart';`，并在 `main()` 内追加 group：
```dart
  group('operationBannerFromJson · kind=search', () {
    test('合法 search 条目（带 keyword/scope）解析成功', () {
      final b = operationBannerFromJson({
        'id': 'op_search_director',
        'title': '电影感人像 · 一键搜',
        'subtitle': '按你喜欢的风格直接搜',
        'tag': '搜索',
        'route': '/search',
        'kind': 'search',
        'searchKeyword': '电影感人像 侧拍',
        'searchScope': 'template',
        'position': 2,
      });
      expect(b, isNotNull);
      expect(b!.kind, OperationBannerKind.search);
      expect(b.searchKeyword, '电影感人像 侧拍');
      expect(b.searchScope, 'template');
      expect(b.position, 2);
      expect(b.externalUrl, isNull);
    });

    test('缺 searchKeyword 或为空 → fail-safe 丢弃', () {
      expect(
          operationBannerFromJson({
            'id': 'x', 'title': 't', 'subtitle': 's', 'tag': 'tag',
            'route': '/search', 'kind': 'search',
          }),
          isNull);
      expect(
          operationBannerFromJson({
            'id': 'x', 'title': 't', 'subtitle': 's', 'tag': 'tag',
            'route': '/search', 'kind': 'search', 'searchKeyword': '',
          }),
          isNull);
    });

    test('searchScope 非法/缺失 → 兜底 all（不丢弃）', () {
      final b = operationBannerFromJson({
        'id': 'x', 'title': 't', 'subtitle': 's', 'tag': 'tag',
        'route': '/search', 'kind': 'search',
        'searchKeyword': '复古', 'searchScope': 'whatever',
      });
      expect(b, isNotNull);
      expect(b!.searchScope, 'all');
    });

    test('误填 externalUrl 时以 kind=search 为准忽略 externalUrl', () {
      final b = operationBannerFromJson({
        'id': 'x', 'title': 't', 'subtitle': 's', 'tag': 'tag',
        'route': '/search', 'kind': 'search',
        'searchKeyword': '窗光', 'externalUrl': 'https://example.com',
      });
      expect(b, isNotNull);
      expect(b!.externalUrl, isNull);
    });
  });

  group('operationBannerToItem · kind=search', () {
    test('拼出 /search?scope=X&keyword=Y 跳转路由（不含 externalUrl）', () {
      const banner = OperationBanner(
        id: 'op_s', title: 't', subtitle: 's', tag: 'se',
        route: '/search', condition: OperationCondition.hasLockedTemplate,
        kind: OperationBannerKind.search,
        searchKeyword: '电影感人像 侧拍',
        searchScope: 'template',
      );
      final item = operationBannerToItem(banner);
      expect(item.type, BannerType.operation);
      expect(item.route, '/search?scope=template&keyword=%E7%94%B5%E5%BD%B1%E6%84%9F%E4%BA%BA%E5%83%8F%20%E4%BE%A7%E6%8B%8D');
      expect(item.externalUrl, isNull);
    });
  });
```

- [ ] **Step 2: 运行失败**

Run: `flutter analyze` 与 `flutter test test/features/home/operation_banners_test.dart`（cwd: `lumira_app_flutter`）
Expected: 编译错误（enum 缺 `search` / 字段缺）。

- [ ] **Step 3: 实现 operation_banners.dart**

（a）`OperationBannerKind` 追加 `search`：
```dart
enum OperationBannerKind {
  operation,
  ad,
  /// App 内搜索（按 position 归位展示，点击跳全局搜索页并预填关键字）
  search,
}
```
（b）`OperationBanner` 加两字段：
```dart
  /// App 内搜索关键字（kind=search 时非空）
  final String? searchKeyword;

  /// 搜索范围（all/template/scene/academy；kind=search 时有效，空回退 all）
  final String? searchScope;
```
构造器参数补：`this.searchKeyword, this.searchScope,`

（c）`operationBannerFromJson`：把 `final kind = json['kind'] == 'ad' ? ... : operation;` 改为三态解析（L179-181 替换）：
```dart
  final rawKind = json['kind'];
  final kind = rawKind == 'ad'
      ? OperationBannerKind.ad
      : rawKind == 'search'
          ? OperationBannerKind.search
          : OperationBannerKind.operation;
```
原 `if (kind == OperationBannerKind.operation) { ... }` 与 `if (kind == OperationBannerKind.ad) { ... }` 之间追加 search 分支（在 ad 分支之后）：
```dart
  if (kind == OperationBannerKind.search) {
    // 搜索：searchKeyword 必填，缺失/为空整条丢弃（fail-safe）；
    // searchScope 非法回退 all；不解析 externalUrl（忽略误填）
    final rawKeyword = json['searchKeyword'];
    if (rawKeyword is! String || rawKeyword.isEmpty) return null;
    final rawScope = json['searchScope'];
    final scope = SearchScopeExt.fromName(rawScope is String ? rawScope : null);
    return OperationBanner(
      id: id,
      title: title,
      subtitle: subtitle,
      tag: tag,
      route: route,
      condition: OperationCondition.hasLockedTemplate,
      kind: kind,
      position: rawPosition,
      externalUrl: null,
      imageUrl: imageUrl,
      focusX: _clampDouble(json['focusX'], 0, 1, 0.5),
      focusY: _clampDouble(json['focusY'], 0, 1, 0.5),
      focusZoom: _clampDouble(json['focusZoom'], 1, 3, 1.0),
      templateId: null,
      searchKeyword: rawKeyword,
      searchScope: scope.name,
    );
  }
```
> 注意：`rawPosition`/`imageUrl`/`_clampDouble` 在前面已定义；`rawPosition` 在 L208 才定义，需把 `rawPosition`/`imageUrl` 提取放前面（见 Step 4 说明）。

（d）`operationBannerToItem`：在函数开头对 search 分支拼 route（在既有 `route` 计算前）：
```dart
  // kind=search：拼全局搜索页路由（scope + URL 编码关键字），不写 externalUrl
  if (banner.kind == OperationBannerKind.search) {
    final scope = banner.searchScope ?? 'all';
    final encoded = Uri.encodeComponent(banner.searchKeyword ?? '');
    return HomeBannerItem(
      id: banner.id,
      title: banner.title,
      subtitle: banner.subtitle,
      imageSeed: 'banner-op-${banner.id}',
      tag: banner.tag,
      route: '/search?scope=$scope&keyword=$encoded',
      externalUrl: null,
      cover: banner.imageUrl,
      focusX: banner.focusX,
      focusY: banner.focusY,
      focusZoom: banner.focusZoom,
      type: BannerType.operation,
      bannerId: banner.id,
    );
  }
```
顶部 import 追加 `import '../../../shared/searchengine/search_scope.dart';`

- [ ] **Step 4: 修正 fromJson 变量作用域**

`operationBannerFromJson` 中 `rawPosition` 当前在 L208 才定义、`imageUrl`/`templateId` 在 L196 定义。search 分支需要 `rawPosition` 提前可用。将 `final rawPosition = json['position'];` 与 `final position = rawPosition is num ? rawPosition.toInt() : null;` 上移到 `final rawImage` 之前（L196 前），search 分支内使用 `position`。`imageUrl` 变量已在 L197 之前定义，search 分支可复用。

- [ ] **Step 5: 运行测试通过**

Run: `flutter test test/features/home/operation_banners_test.dart`
Expected: 全部通过（包括既有 + 新增 search 用例）。

- [ ] **Step 6: Commit**

```bash
git add lumira_app_flutter/lib/features/home/data/operation_banners.dart lumira_app_flutter/lib/features/home/data/operation_banners.dart.test.dummy
git commit -m "feat(flutter): 运营 Banner 支持 kind=search 解析与跳转路由"
```
> 若测试文件未在本任务提交，仅提交 `operation_banners.dart`（排除上述 dummy 路径）。

（仅在测试文件已写入时）同时 `git add lumira_app_flutter/test/features/home/operation_banners_test.dart`，包含同一 commit。

---

### Task 7: Flutter 推荐分组重构（search 归位）

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/services/recommendation_service.dart:140-146`

**Interfaces:**
- Consumes: Task 6 的 `OperationBannerKind.search`。
- Produces: `ad` 与 `search` 统一进入 `fixed`（position 归位组），`operation` 单独进 `ops` 条件匹配组。供 Task 9 断言。

- [ ] **Step 1: 改分组逻辑**

将 L141-146 替换为：
```dart
    // 拆分「条件触达运营位」与「无条件归位条目（广告+App内搜索）」：
    // ad 与 search 都按 position 归位插入，不参与 slot 0 条件匹配；
    // ops 仅保留 kind==operation（不能再用「非 ad」，否则 search 会误入条件匹配）。
    final fixed = operationBanners
        .where((b) => b.kind != OperationBannerKind.operation)
        .toList();
    final ops = operationBanners
        .where((b) => b.kind == OperationBannerKind.operation)
        .toList();
```
并将 L383-390 的 `for (final ad in ads)` 与 `banners.insert(insertAt, operationBannerToItem(ad));` 改为：
```dart
    // === 广告/搜索位：按各自 position 归位插入（缺省/越界放最后） ===
    for (final fixedItem in fixed) {
      final insertAt = (fixedItem.position != null &&
              fixedItem.position! >= 0 &&
              fixedItem.position! < banners.length)
          ? fixedItem.position!
          : banners.length;
      banners.insert(insertAt, operationBannerToItem(fixedItem));
    }
```

- [ ] **Step 2: 运行既有测试确认无回归**

Run: `flutter test test/features/home/recommendation_service_test.dart`
Expected: 全部通过（分组变化不影响既有 ad 归位行为）。

- [ ] **Step 3: Commit**

```bash
git add lumira_app_flutter/lib/features/home/services/recommendation_service.dart
git commit -m "refactor(flutter): Banner 分组重构，search 与 ad 统一归位"
```

---

### Task 8: Flutter 路由 builder 透传 keyword

**Files:**
- Modify: `lumira_app_flutter/lib/app/router.dart:248-254`

**Interfaces:**
- Consumes: `RouteNames.paramKeyword`（已存在，`route_names.dart#L118`）、`SearchScopeExt.fromName`、`GlobalSearchPage(scope, initialKeyword)`。
- Produces: `search` route builder 传入 `initialKeyword`。

- [ ] **Step 1: 改 builder**

将 L251-253 替换为：
```dart
        builder: (context, state) => GlobalSearchPage(
          scope: SearchScopeExt.fromName(state.queryParams[RouteNames.paramScope]),
          initialKeyword: state.queryParams[RouteNames.paramKeyword],
        ),
```
确认 `route_names.dart` 为 `import 'core/router/route_names.dart'`（同文件已引用 `RouteNames.` 与 `SearchScopeExt`，无新增 import 需求）。

- [ ] **Step 2: 运行分析**

Run: `flutter analyze`
Expected: 无错误。

- [ ] **Step 3: Commit**

```bash
git add lumira_app_flutter/lib/app/router.dart
git commit -m "feat(flutter): 全局搜索路由透传 initialKeyword 预填"
```

---

### Task 9: Flutter 测试补齐（recommendation + home_page）

**Files:**
- Modify: `lumira_app_flutter/test/features/home/recommendation_service_test.dart`
- Modify: `lumira_app_flutter/test/features/home/operation_banners_test.dart`（若 Task 6 已含则跳过）
- Modify: `lumira_app_flutter/test/features/home/home_page_test.dart`

**Interfaces:**
- Consumes: Task 6 模型、Task 7 分组、Task 8 路由。
- Produces: 覆盖 search 归位、跳转路由、首页轮播点击 search 跳转。

- [ ] **Step 1: recommendation 归位断言**（`recommendation_service_test.dart`，老用户有运营位场景内追加）

在 `test('运营位 slot 0：老用户未绑定邀请 → 邀请运营位占位且不补探索', ...)` 内，`buildBanners` 传 `operationBanners: [...kOperationBanners, searchBanner]`，其中：
```dart
const searchBanner = OperationBanner(
  id: 'op_search', title: '搜', subtitle: 's', tag: '搜索',
  route: '/search', condition: OperationCondition.hasLockedTemplate,
  kind: OperationBannerKind.search,
  searchKeyword: '复古', searchScope: 'template', position: 2,
);
```
追加断言：`banners` 中存在 `bannerId == 'op_search'` 的条目，其 `route == '/search?scope=template&keyword=%E5%A4%8D%E5%8F%A4'`，且 **search 未参与 slot 0**（首个 banner 非 op_search）。并在文件顶部 import 已含 `operation_banners.dart`，无需新 import。

- [ ] **Step 2: home_page 轮播点击 search 跳转测试**

`home_page_test.dart` `_wrapWithRouter` 目前用 `bannerRecommendationProvider.overrideWith(async => HomeMockData.banners)`。新增一个自定义 `HomeBannerItem`（type=operation，route=`/search?scope=template&keyword=x`）并入 mock 列表，构造 `ProviderScope` override，`await tester.tap(find.text(banner.title))`，然后 `expect(find.textContaining('SEARCH'), findsOneWidget)`——需在 `_wrapWithRouter` 路由表中加一条：
```dart
      GoRoute(
        path: RouteNames.search,
        name: 'search',
        builder: (context, state) => Scaffold(
          body: Center(child: Text('SEARCH:${state.queryParams[RouteNames.paramKeyword]}')),
        ),
      ),
```
并在新测试内 override banner 为含该 search item 的单条列表，tap 后断言 `find.text('SEARCH:x')`。若 mock 依赖过多，实现为「仅覆盖 bannerRecommendationProvider + homeStreak/openRecentShots 等已 override 项」，复用 `_wrapWithRouter`。
> 若断言复杂度高，可退化为只验证「点击后 context 推送了 `/search?...`」，用自定义 RouterObserver。

- [ ] **Step 3: 运行全部 Flutter 测试**

Run: `flutter analyze && flutter test`
Expected: 全部通过（含既有 operation/ad 用例，无回归）。

- [ ] **Step 4: Commit**

```bash
git add lumira_app_flutter/test/features/home/recommendation_service_test.dart lumira_app_flutter/test/features/home/home_page_test.dart
git commit -m "test(flutter): 覆盖 search banner 归位与跳转"
```

---

### Task 10: 全量验证 + 文档收尾（可选）

**Files:**
- Modify: `docs/specs/2026-09-24-banner-search-type-design.md`（若定义方向有变则更新状态/迁移号）
- Modify: `docs/future-optimizations.md`（如有登记）

- [ ] **Step 1: 后端 e2e/类型全量**

Run: `pnpm --filter @lumira/backend test && pnpm --filter @lumira/backend build`
Expected: 通过。

- [ ] **Step 2: 后台构建**

Run: `pnpm --filter @lumira/admin build`
Expected: 通过。

- [ ] **Step 3: Flutter 全量**

Run: `flutter analyze && flutter test`
Expected: 通过。

- [ ] **Step 4: 更新 spec 迁移号（037 → 044）并 commit**

将 spec 内 `037_banner_search.sql` 引用改为 `044_banner_search.sql`。
```bash
git add docs/specs/2026-09-24-banner-search-type-design.md
git commit -m "docs: 修正 banner search 迁移号为 044"
git push origin master
git push github master
```
> 纯文档改动可由用户决定是否推送；此处如用户未要求推送可不 push。

- [ ] **Step 5: 汇总给用户**

列出所有改动文件、测试结果、双远程推送状态，交由用户确认是否处理先前未提交的「广告点击修复」Flutter 改动。

---

## 改动文件清单（汇总）

后端：
- [新增] `lumira-server/packages/backend/src/database/migrations/044_banner_search.sql`
- 修改 `lumira-server/packages/backend/src/database/schema.ts`
- 修改 `lumira-server/packages/backend/src/modules/banners/dto/create-banner.dto.ts`
- 修改 `lumira-server/packages/backend/src/modules/banners/dto/update-banner.dto.ts`
- 修改 `lumira-server/packages/backend/src/modules/banners/banners.service.ts`
- 修改 `lumira-server/packages/backend/src/modules/banners/banners.service.spec.ts`

后台：
- 修改 `lumira-server/packages/admin/src/types/admin.ts`
- 修改 `lumira-server/packages/admin/src/components/banner-manager.tsx`
- （`actions/banners.ts` 确认无需改动）

Flutter：
- 修改 `lumira_app_flutter/lib/features/home/data/operation_banners.dart`
- 修改 `lumira_app_flutter/lib/features/home/services/recommendation_service.dart`
- 修改 `lumira_app_flutter/lib/app/router.dart`
- 修改 `lumira_app_flutter/test/features/home/operation_banners_test.dart`
- 修改 `lumira_app_flutter/test/features/home/recommendation_service_test.dart`
- 修改 `lumira_app_flutter/test/features/home/home_page_test.dart`

文档：
- 修改 `docs/specs/2026-09-24-banner-search-type-design.md`