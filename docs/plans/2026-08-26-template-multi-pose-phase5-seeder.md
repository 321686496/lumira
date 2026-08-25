# 模板多姿势 Phase 5：内置模板归并为套 + 搜索/推荐收敛 + 全量回归 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: 用 superpowers:subagent-driven-development 按任务逐条执行。

**Goal:** 将 Flutter 内置模板从「每模板 = 1 封面 + 1 姿势」归并为「模板套（每套 = 1 模板，含 images[] + poses[]）」，三级分类树重生成，搜索/推荐以套为粒度，全量测试通过。

**Architecture:** `template_registry.dart` 按子风格归并同配置模板为套；`builtin_data_seeder.dart` 分类树收敛为三级（删 method 层）；`template_mapper.dart` 读写对齐 Phase 2 多图/多姿势；测试断言更新为套口径。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6；sqflite；flutter_riverpod。

## 全局约束

- 不改 `lumira-app/`（uni-app 原型）。
- 归并策略：同一 `classification`（type + majorStyle + style）+ 同一共享配置（composition/camera/sceneGuide/postProcess）的模板归为一套；各模板的 cover 进入 `images[]`，各模板的 pose 进入 `poses[]`。
- 封面统一取 `images[0]`。
- 三级分类树：大类(type) → 风格(majorStyle) → 子风格(style)；删 level=4 method 节点（保留字段兼容旧数据读取）。
- 搜索/推荐以套为粒度：命中一套只返回一次，封面取 `images[0]`。
- `flutter analyze` 0 error；`flutter test` 全量通过（断言更新为套口径）。
- 禁止硬编码皮肤色。

---

### Task 1: 分类树三级收敛

**Files:**
- Modify: `lumira_app_flutter/lib/core/db/seeders/builtin_data_seeder.dart`
- Modify: `lumira_app_flutter/lib/features/capture/domain/photo_template.dart`（`TemplateClassification` 注释，Phase 2 Task 7 已部分完成）

- [ ] **Step 1: `seedStyleMethodCategories` 删 level=4 method 节点**

在 `builtin_data_seeder.dart` L271+ 的 `portraitMethods` 列表，删除全部 method 节点的 INSERT（不再播种 level=4）。保留 level 1/2/3 节点。非人像的 level=2 风格 + level=3 method 保留（因为非人像的 level=2 就是风格，level=3 就是子风格——这与三级命名一致）。

> 验证：播种后 `template_categories` 表中 `level` 最大值为 3。

- [ ] **Step 2: 注释更新**

将「四级树形结构」注释改为「三级：大类 → 风格 → 子风格」。

- [ ] **Step 3: Commit**

```bash
git add lumira_app_flutter/lib/core/db/seeders/builtin_data_seeder.dart
git commit -m "refactor(seeder): 分类树收敛为三级（删 level=4 method 节点）"
```

---

### Task 2: 内置模板归并为套

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/data/template_registry.dart`
- Modify: `lumira_app_flutter/lib/core/db/seeders/builtin_data_seeder.dart`（reseed 逻辑适配）

- [ ] **Step 1: 归并策略实现**

在 `template_registry.dart` 中，将 `_templates` map 改为按归并 key 分组：
- 归并 key = `{type}:{majorStyle}:{style}` + 共享配置的 hash（composition/camera/sceneGuide/postProcess 的关键参数）
- 同 key 下的模板合并为一个 `PhotoTemplate`：`images` = 各模板 cover 的列表；`poses` = 各模板 pose 的列表
- 模板 name 取归并组中首个或按 `{子风格}套` 命名
- `id` 使用归并 key 的 hash 或首模板 id

- [ ] **Step 2: 保持 `allTemplates` 返回归并后的套列表**

`allTemplates` getter 返回归并后的 `List<PhotoTemplate>`（套数 < 原模板数）。

- [ ] **Step 3: seeder 适配**

`reseedBuiltinTemplates` 遍历 `TemplateRegistry.allTemplates`（归并后的套），通过 `TemplateMapper.toRecord` 落库。确认 `images_json` / `pose_json` 数组正确写入。

- [ ] **Step 4: Commit**

```bash
git add lumira_app_flutter/lib/features/capture/data/template_registry.dart lumira_app_flutter/lib/core/db/seeders/builtin_data_seeder.dart
git commit -m "feat(seeder): 内置模板按子风格归并为套（images[]+poses[]）"
```

---

### Task 3: 搜索/推荐以套为粒度

**Files:**
- Modify: 搜索相关 provider/service（根据 explore 结果定位）
- Modify: 推荐相关 provider（`TemplateRanking` / `InterestService` 等）

- [ ] **Step 1: 搜索去重**

确认关键词搜索按模板 id（套 id）去重——归并后每个套只有一个 id，自然去重。如果搜索逻辑按 cover/name 匹配，需确认不会因 images[] 多图导致重复命中。

- [ ] **Step 2: 推荐封面一致**

推荐算法中取封面的位置统一改为 `template.meta.images[0]` / `template.meta.cover` getter（Phase 2 已落为存储字段）。

- [ ] **Step 3: Commit**

```bash
git add lumira_app_flutter/lib/features/templates/ lumira_app_flutter/lib/features/inspiration/
git commit -m "feat(recommend): 搜索/推荐以套为粒度，封面统一 images[0]"
```

---

### Task 4: 测试断言更新 + 全量回归

**Files:**
- Modify: `lumira_app_flutter/test/features/templates/template_registry_test.dart`（如有）
- Modify: 其他因归并导致数量变化的测试

- [ ] **Step 1: 更新数量断言**

将原模板数量断言（如 29 / 132 等）更新为归并后的套数。如果确数需运行后才能得到，先运行测试获取失败信息，再更新断言。

- [ ] **Step 2: 分类树断言**

确认三级树断言：`level` 最大值为 3，无 level=4 节点。

- [ ] **Step 3: 全量测试**

```bash
cd lumira_app_flutter
flutter analyze
flutter test
```
Expected: 0 error；全量通过（Phase 2 遗留的 227 个 pre-existing 失败需确认是否因 Phase 5 改动而变化——如不变则视为 pre-existing 不阻塞）。

- [ ] **Step 4: Commit**

```bash
git add -u lumira_app_flutter/test/
git commit -m "test(seeder): 更新归并后套数断言 + 三级分类树断言"
```

---

## 自检记录

- **Spec 覆盖**：设计稿 §8（内置模板归并）→ Task 2；§3.2（三级分类）→ Task 1；§九（搜索/推荐以套为粒度）→ Task 3；§十（验证）→ Task 4。
- **依赖**：Phase 2（TemplateMeta.images 存储字段 + TemplateRecord.images_json + TemplateDetail.displayImages/displayPoses）必须先完成。Phase 2 已完成（7 个提交）。
- **风险**：归并后模板数量减少可能影响推荐算法的候选池大小——需确认推荐 fallback 逻辑（Phase 2 已有 50/50 explore-exploit）。
