# 模板分类四级化 + 二级封面 + 二级独立页 设计

> 日期：2026-08-17
> 范围：模板分类从「题材 / 风格 / 方式」三级扩展为「题材 / 大风格 / 子风格 / 方法」四级；二级分类支持封面图；App 浏览改为「一级 → 二级独立页 → 模板列表」两级钻取。
> 状态：设计已获确认；后端实施完成，后台 UI 实施完成，待用户确认分组后推送。

## 一、背景与目标

当前模板分类为三级树（题材 → 风格 → 方式），经评审确认存在数据建模上的痛点和业务新诉求：

1. **建模问题**：题材、方式本应正交，却被压成严格父子链，导致大量同 key 跨层级重复与 `(key, parentKey, level)` 三重消歧；各分支深度严重不均。
2. **业务新诉求（本次需求）**：
   - 题材下存在「大风格 → 子风格」的真实层级诉求（如更新后的：人像 → 情绪 → 破碎清冷情绪风）。
   - 目前只有一级分类能设置封面图，希望**二级分类也能设置封面**。
   - App 浏览目前点一级直接进模板列表，希望改为**点一级先进二级分类独立页，再进该分类下的模板页**。

## 二、决策记录

| 决策点 | 结论 |
|---|---|
| 分类层级 | 扩展到 4 级：`题材 → 大风格 → 子风格 → 方法` |
| 层级是否强制 | **非强制**。允许题材内部深度不一致（如 landscape 仅到 2 级），不强制满四级 |
| 方法(L4) 挂载 | 每个子风格下重复建（接受同 key 跨父级重复，沿用消歧） |
| 二级封面 | 支持；复用现有 `icon_url` 字段，不新增字段 |
| App 钻取 | **固定两级**：题材(L1) → 二级类别卡片页 → 模板列表 |
| 「该分类下的模板」| **包含子孙级的模板**（即该分类族内所有后代挂的模板） |
| 模板关联 | `classification_json` 由 3 字段扩为 5 字段 `{type, majorStyle, subStyle, method}` |
| 老数据迁移 | 用户选择「先出草稿再改」：见第七节大风格分组草稿，需用户确认后用于迁移种子 |

## 三、数据模型（现状，仅扩展层级，不新增表/字段）

沿用现有通用树结构 `template_categories`：

```
( id, key, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at )
UNIQUE(key, parent_key)
```

- 层级：
  - `level=1` 题材（type）：portrait / landscape / food / street / night / macro / still-life
  - `level=2` 大风格（majorStyle）：情绪 / 松弛感 / ...（新增粗粒度）
  - `level=3` 子风格（subStyle）：破碎清冷情绪风 / 电影感叙事人像 / ...
  - `level=4` 方法（method）：他拍 / 自拍 / 仰拍 / ...
- 消歧：同 key 可在不同 parentKey 下重复，定位分类一律用 `(key, parentKey)`，并辅以 `level` 精确匹配。

## 四、后端改动

文件：`lumira-server/packages/backend/src/modules/templates/admin-categories.service.ts`

1. `MAX_LEVEL`：`3` → `4`（L56）。
2. `create()` 父分类校验：许可 `parent.level <= 2` 放宽为 `parent.level <= 3`（L106），使 level-3（子风格）也能有孩子。
3. `countTemplateReferences()` 层→JSON 字段映射（L279）改为：
   - L1 → `$.type`
   - L2 → `$.majorStyle`
   - L3 → `$.subStyle`
   - L4 → `$.method`
4. 其余（delete/toggleActive/list 的 level 匹配、`parent_key` 不可变、系统分类保护）逻辑不变，树天然支持任意深度。

### 4.1 `classification_json` 结构变更

- 由 `{ type, style, method }` → `{ type, majorStyle, subStyle, method }`。
- 同步位置：
  - `lumira-server/packages/shared/src/types/template.ts` 的 classification 类型。
  - Create/Update Template 的 DTO 与校验。
  - `admin-templates.service.ts` 读写该字段处。

### 4.2 迁移脚本（新增）

新增迁移 SQL（序号接续现有迁移），职责：

1. 为每个题材插入「大风格」层级（L2），数据来源见第七节分组草稿（待用户确认后填成种子）。
2. 现有 `level=2` 分类（风格）下移为 `level=3`（子风格），`parent_key` 改为其新归属的大风格。
3. 现有 `level=3` 分类（方式）下移为 `level=4`（方法），`parent_key` 保持不变（随其父级上移至子风格）。
4. 老模板 `classification_json` 字段平移：`style` → `subStyle`，`method` 保留；`majorStyle` 由子风格所属大风格回填。

> ⚠️ 迁移的幂等写法与现有 INSERT IGNORE / UNIQUE 约束保持一致。

## 五、后台 UI 改动

文件：`lumira-server/packages/admin/src/components/category-manager.tsx`

1. **四级标签与徽标**：
   - `LEVEL_LABEL` / `LEVEL_BADGE` / `LEVEL_DOT` / 层级统计胶囊 从 3 级扩到 4 级。
2. **新建对话框：通用逐级选父**：
   - 现状仅特判 `level===3` 的 `grandparentKey`（一/二级两级父选择）。
   - 改为任意层级的「面包屑路径」父选择：L2 选题材 → L3 选大风格 → L4 选子风格，替换 `handleGrandparentChange` / `getCreateContext` 等三级特例。
3. **封面上传放开到二级**：
   - 图标上传显示条件 `form.level === 1` → `form.level <= 2`（L856）。
   - submit 附 icon 条件 `form.level === 1` → `form.level <= 2`（L288）。
   - 复用 `icon_url`，后端已支持任意层级 icon。
4. 树形/折叠/排序/搜索逻辑为通用递归，无需改动（`MAX_TREE_DEPTH=8` 够用）。

## 六、App（Flutter）改动

文件主要在 `lumira_app_flutter/lib/`（`app/router.dart`、`features/templates/`）。

1. **新增「二级分类独立页」**：
   - 进入某题材后，展示该题材的**直接子分类**（大风格 / 浅层风格）卡片，封面用 `icon_url`。
   - 分类数据来自已扁平同步到 sqflite 的远程分类表（已有 `level/parentKey/iconUrl`），按 `parentKey === 题材.key` 过滤。
2. **钻取方式（固定两级）**：
   - 一级点击 → 进入上面的二级独立页（不再直接进模板列表）。
   - 二级点击 → `TemplatesAllPage(category=该二级key)`。
3. **「该分类下的模板」= 包含子孙级**：
   - 用已同步的完整分类树，把所选二级的**所有后代 key（含自身）**展开成 key 集合。
   - 模板列表按该集合筛（模板的分类叶子路径命中的即算；后端可提供按子树 key 列表查询，或前端在已取数据内过滤）。
4. **路由**：复用 `templatesAll` 的 `category` 参数语义（由「精确实配某一级」扩展为「按合集匹配」）；二级独立页新增一条 route 或由题材页携带子树参数进入。

> 注：Flutter 当前推荐/列表只用一级 `category` 展示，四级化对其无破坏；分类同步仍是扁平存 `level/parentKey`，无需改表。

## 七、迁移依赖 —— 人像大风格分组草稿（待确认）

用户已选择「我先出草稿你再改」。下述为提议的人像（portrait）大风格分组（非人像题材为浅层，暂不强制插入大风格，或按需补）：

```
清新治愈  japanese日系 / japanese_fresh日系清新 / cream_healing奶油治愈
          fresh_green清新绿意 / sweet_girl甜美少女 / morandi_minimal莫兰迪极简
情绪胶片  emotional情绪 / film胶片 / ccd_retro CCD复古
复古怀旧  hk_noir港风Noir / french_lazy法式慵懒 / chinese_classical中式古典
都市潮流  western欧美 / neon_city霓虹都市 / y2k Y2K千禧 / dark_indoor暗调室内
梦幻夜色  blue_night蓝色之夜 / purple_dusk紫色黄昏 / anime_dream动漫梦境
场景人像  foodie_portrait美食人像 / elegant_lady优雅女士
```

> ⚠️ 待用户确认/修改后，才可据此填充迁移种子。树为单父约束，`film / ccd_retro / neon_city / dark_indoor` 等多义风格只能归属一格。

## 八、范围

### In scope
- 后端四级扩展、`classification_json` 5 字段、迁移脚本。
- 后台四级 UI + 二级封面上传 + 通用逐级选父。
- App 二级独立页 + 固定两级钻取 + 子树模板归属查询。

### Out of scope
- App 的「多选/自由组合」扁平化改造（本次维持树形四级）。
- Blog/教程等其他模块的分类消费（不在本次范围待评估）。

## 九、风险与取舍

| 取舍 | 说明 |
|---|---|
| 同 key 跨父级重复 | L4 方法每子风格重复建，需持续依赖 `(key, parentKey, level)` 消歧；复杂度较三级继承并放大 |
| 深度不一致 | 浅层题材无满四级，属预期；App 固定两级钻取已规避深钻 |
| 老数据归属主观 | film/ccd_retro 等多义风格只能归一格，语义由用户分组草稿兜底 |
| `classification_json` 结构变更 | 属破坏性迁移，需同步 shared 类型、后端 DTO、老数据平移、Flutter 解析端 |

## 十、待确认 / 开放问题

1. 第七节「人像大风格分组草稿」是否确认或修改（影响迁移种子）——**待用户确认后推送**。
2. `classification_json` 语义由「风格」改「大风格/子风格」，老数据平移后是否需要人工复核——**已按草稿平移，推送上线后可抽查**。
3. 子树模板查询放后端还是前端过滤——**已落地为后端 `subtreeKeys` 参数（见十一·后端 `templates.service.ts` 行），前端可传分类族 key 集合**。

## 十一、实施进度（2026-08-17）

### 后端 ✅ 完成并通过验证

文件改动：

| 文件 | 改动 |
|---|---|
| `shared/src/types/template.ts` | `classification` 扩为 `{ type, majorStyle, subStyle, method }`；`TemplateCategory.level` 注释对齐四级 |
| `admin-categories.service.ts` | `MAX_LEVEL` `3→4`（L56）；`create()` 父校验放宽 `level <= 2 → level <= 3`（L106）；`countTemplateReferences()` 按全字段匹配 `$.type / $.majorStyle / $.subStyle / $.method`（兼容人像四级 + 浅层题材，见代码注释） |
| `categories.service.ts` | `hasChildren()` 叶子判断 `level === 3 → level === 4` |
| `templates.service.ts` | `listRemoteTemplates()` 新增 `subtreeKeys` 参数：按 key 集合对 `category` 与 `classification_json` 四字段做 OR 匹配 |
| `templates.controller.ts` | `GET /api/v1/templates/list` 暴露 `subtreeKeys`（逗号分隔）查询参数 |
| `admin-templates.service.ts` | 写 `classification_json` 为 `{ type, majorStyle, subStyle, method }`；兼容旧 admin 前端仅提交 `style` 时回退为 `subStyle` |
| `create-template.dto.ts` / `update-template.dto.ts` | `classification` 保留可选 `style` 字段（旧前端兼容） |
| `migrations/009_template_category_4level.sql`（新增） | ① 插入人像 6 大风格 L2（种子来自第七节草稿）② 原 L2 风格下移为 L3 并改挂新大风格 ③ 原 L3 方式下移为 L4 ④ 老 `classification_json` 平移：`style→subStyle`、`method` 保留、`majorStyle` 由子风格归属回填 |

验证结果：

- ✅ `pnpm --filter @lumira/backend build` 通过
- ✅ 迁移 `001-009` 在本机 `mysql:8.0`（3307 端口）全部执行成功，无 SQL 错误，009 幂等
- ✅ e2e 全套 7 套件 48 测试通过（含 templates / admin）；注意需 `--testTimeout=120000`（`beforeAll` 迁移耗时超过默认 5s）

### 后台 UI ✅ 完成并通过验证

文件：`packages/admin/src/components/category-manager.tsx`

1. **四级标签与徽标**：`LEVEL_LABEL` / `LEVEL_BADGE` / `LEVEL_DOT` / 层级统计胶囊 扩到 4 级（L4 用 accent 赭石色，沿用 Morandi 主题）；页头副标题改为「题材 → 大风格 → 子风格 → 方法」。
2. **通用逐级选父**：删除 `grandparentKey` / `level1Categories` / `level2ByGrandparent` / `handleGrandparentChange` 三级特判，改为任意层级的「面包屑路径」级联选择（`FormState.path`），L2 选题材 → L3 选大风格 → L4 选子风格；`openCreateChild` 预填祖先路径、`openEdit` 重建路径。
3. **封面上传放开到二级**：图标上传显示与提交条件 `form.level === 1 → form.level <= 2`；表格名称单元格二级分类也显示封面图；hint 文案同步更新。
4. 树形/折叠/排序/搜索保持通用递归，未改。

验证结果：

- ✅ `pnpm --filter @lumira/admin exec tsc --noEmit` 通过
- ✅ `pnpm --filter @lumira/admin test` 通过

### Flutter（App）阶段 ✅ 完成并通过验证

见第六节：二级分类独立页 + 固定两级钻取 + 子树模板归属查询。后端 `subtreeKeys` 已就绪，Flutter 侧采用「前端取回完整分类树 → 递归展开子树 key 集合 → 内存过滤」方案（模板量级内开销可忽略，且与本地 sqflite 同步的分类表天然契合）。

文件改动（`lumira_app_flutter/`）：

| 文件 | 改动 |
|---|---|
| `lib/core/db/dao/templates_dao.dart` | 新增 `getSubtreeKeys(key)`：从 sqflite 分类表递归收集指定分类的子树 key 集合（含自身 + 所有后代 key） |
| `lib/core/router/route_names.dart` | 新增 `templatesCategory = '/templates/category'` 路由路径与 `paramTypeKey` 参数名 |
| `lib/features/templates/pages/templates_category_page.dart`（新增） | 「二级分类独立页」：展示题材的直接子分类（大风格 / 浅层风格）卡片，封面用 `iconUrl`（非空网络图 / 空回退 Material Icon）；浅层题材（无子分类）显示「查看全部模板」兜底入口 |
| `lib/app/router.dart` | 注册 `templatesCategory` 路由（`?category=` 传入一级题材 key）并 import 新页面 |
| `lib/features/templates/pages/templates_all_page.dart` | 概览点击一级分类 → push 二级分类独立页（不再原地切模板列表）；分类视图按所选分类的子树 key 集合过滤模板 |
| `lib/features/templates/data/templates_browse_mock_data.dart` | `AllTemplateItem` 新增 `majorStyle` / `subStyle` 字段与 `matchesSubtree(Set<String>)`：模板的分类叶子路径（category/type、style、majorStyle、subStyle、method）任一命中集合即算（兼容老模板 style 字段与四级新模板） |
| `test/features/templates/templates_all_page_test.dart` | 新增「两级钻取导航」用例组：一级 → 二级独立页 → 子树过滤模板列表 → 返回栈路径；浅层题材兜底；测试 seed 扩展二级/三级分类 |

验证结果：

- ✅ `flutter analyze` 通过（328 个 info 级既有问题，无 error/warning，改动文件零新增告警）
- ✅ `flutter test test/features/templates/templates_all_page_test.dart` 22/22 通过
- ✅ `flutter test test/features/templates/` 全套 157/157 通过

### 推送状态 ✅ 已完成

按项目规则已 commit + push 到两个远程（用户已确认第七节人像大风格分组草稿）：

- `03d50c7` 后端/后台四级化改动（此前会话已提交）
- `5102ec0` Flutter 二级分类独立页 + 固定两级钻取 + 子树模板过滤（本次提交，8 文件 +687/-91）
- 双远程验证：`origin`（gitee）与 `github` 的 `master` 均指向 `5102ec0`，完全同步