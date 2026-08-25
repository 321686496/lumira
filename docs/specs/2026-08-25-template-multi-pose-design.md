# 模板多姿势（一套 = 一个模板）设计

> 日期：2026-08-25
> 范围：模板数据模型从「1 模板 = 1 封面 + 1 姿势」改为「1 模板（一套）= 1 组效果图 + 1 组姿势剪影」；四级分类收敛为三级；同步调整 App 内自定义模板表单、后台上传模板、推荐算法与搜索。
> 状态：设计草案，待用户审阅。

## 一、背景与目标

当前一个模板只能对应「一张封面 + 一个姿势剪影」，其余配置（构图/相机/场景引导/后期）为该模板独有。实际使用中，用户往往在一个风格下要拍多种不同姿势的照片，于是只能建立「多个配置完全一样、仅姿势不同」的重复模板。带来的问题：

1. **搜索/推荐不友好**：用户搜一个关键词，结果刷出一堆只差姿势的重复卡片；
2. **一套连着拍很痛苦**：搜到某个模板只有一个姿势，用户想多拍几组不同姿势，不知道该去哪拍。

目标（用户已确认方案二）：
1. **一套 = 一个模板**：一个模板内置多个姿势剪影，拍摄时可切换。
2. 搜索只命中一个模板，不再重复；多姿势直接在一个模板里解决。
3. 分类从四级收敛为三级（大类 → 风格 → 子风格），旧第四级（姿势/构图）内化为模板的姿势列表。

补充约束（用户明确）：
- 所有与「模板字段修改」相关的功能都要同步调整：App 内自定义模板与表单、后台上传模板。
- 有多张效果图时，**第一张为封面图**，列表卡片与推荐算法推荐的卡片使用**同一张封面**。
- **效果图数量与剪影数量不必相等、也不一一对应**——效果图列表用于展示，剪影列表用于拍摄切换，两者独立。

## 二、决策记录

| 决策点 | 结论 |
|---|---|
| 建模方式 | 方案二：一个模板内 `images[]`（效果图，`[0]`=封面）+ `poses[]`（姿势剪影组），加模板级共享配置，不引入「模板组」实体 |
| 分类层级 | 三级：大类(type) → 风格(majorStyle) → 子风格(style)；旧第四级 method 不再是一级分类 |
| 售卖粒度 | 整套作为一个整体售卖；付费模板 = 整套 |
| 效果图与剪影关系 | 独立两条列表，数量可不等、不一一对应（封面取 images[0]） |
| 封面一致性 | 卡片、推荐、详情一律使用 `images[0]`，保证同源 |
| 老数据兼容 | 旧 `pose_json` 单对象 → 数组包装；旧四分类字段向后兼容读取 |

## 三、数据模型（Flutter 领域层）

### 3.1 `PhotoTemplate`
文件：`lumira_app_flutter/lib/features/templates/...`（`PhotoTemplate` 定义）

| 字段 | 变更 |
|---|---|
| `meta`（TemplateMeta） | 保留；分类字段见 3.2；封面改为 `images` 派生 |
| ~~`cover` / `coverData`~~ | 改为由 `images[0]` 派生（见 3.3），不再单独存封面 |
| **`images`**（新增） | `List<Asset>` 效果图，**`[0]` = 封面**；用于卡片/推荐/详情展示 |
| **`poses`**（改 pose → poses） | `List<TemplatePose>` 姿势剪影组，用于拍摄页切换 |
| composition / camera / sceneGuide / postProcess | **保留为模板级、整组共享，不重复存储** |

### 3.2 `TemplateClassification`（三级）
| 字段 | 变更 |
|---|---|
| `type` | 一级：大类，不变 |
| `majorStyle` | 二级：风格，不变 |
| `style` | 三级：子风格，不变 |
| ~~`subStyle` / `method`~~ | 不再作为独立分类层级（旧兼容读取可保留字段，但不进分类树筛选） |

> 三级命名对齐：大类 / 风格 / 子风格。旧四分类数据读取时向后兼容映射。

### 3.3 封面派生规则
- `images` 非空时，`cover = images[0]`。
- 卡片 / 推荐 / 详情三处**统一走一个取封面入口**（如 `template.coverImage` 或 `template.coverAsset` getter），保证同源不重不散。

### 3.4 `TemplatePose`
每个姿势剪影自带（类比现有 `PoseData`，增加 `name`）：
- `name`：姿势名（如 侧拍 / 俯拍 / 姿势1）
- `description`
- `silhouette`（剪影：来源类型 + data）
- `position {x, y}`、`scale`、`rotation`

> 剪影列表只用于拍摄姿势参考/切换；**不要求与 images 一一对应**。

## 四、后端 / 数据库

### 4.1 存储
文件：后端 `lumira-server/packages/backend/`（模板表 / DTO）

- `templates` 表 `pose_json` 字段存放改为**数组**结构：`[{name, description, silhouette, position, scale, rotation}, ...]`。
- 新增效果图列表字段（如 `images_json`）：`[{url|data, ...}]`，`[0]` = 封面。
- 分类字段收敛为三级 `{type, majorStyle, style}`（旧 method 不再作为层级）。
- 返回给 App 的模板 DTO 中 `pose` 改为 `poses[]`，并新增 `images[]`；`cover` 由 `images[0]` 派生。

### 4.2 迁移
- 旧 `pose_json` 单对象 → 包成 `[single]` 数组。
- 旧效果图字段（如果有）迁移进 `images[]`。
- 旧四分类数据 → 三级映射（method 丢弃或保留为非层级字段）。

## 五、UI 改动（Flutter）

### 5.1 列表卡片 & 推荐卡片
- 封面取 `images[0]`，走统一封面 getter；列表卡与推荐卡保证同一张图。

### 5.2 详情页
`templates_detail_page.dart`
- 展示多张效果图画廊（横滑/点选大图），第一张即封面。
- 展示姿势剪影组（可选，点击预览对应剪影）。
- 底部 CTA「应用」携带整组 `poses` + 共享配置进入拍摄。

### 5.3 拍摄页（姿势切换）
- 进入时携带 `poses[]` + 共享配置。
- `poses.length > 1`：拍摄区提供「切换姿势」按钮（按 `tokens`/`uiStyle` 风格实现），点击切换当前生效的剪影/姿势参考；切换只影响剪影显示，**不影响**共享的构图/相机/场景/后期。
- `poses.length <= 1`：**不显示**切换按钮（保持现有单姿势行为）。

## 六、自定义模板表单（App 内）

文件：`lumira_app_flutter/lib/features/templates/pages/templates_editor_page.dart`、`data/templates_editor_mock_data.dart`、`services/template_mapper.dart`

- 「封面与剪影」Tab 改造为**两组独立列表**：
  - **效果图列表**：多图增删，**第一张默认封面**，可标记/重排（重排后封面跟随 `[0]`）。
  - **姿势列表**：多组姿势增删，每组含名字/描述/剪影（来源/内置/导入/绘制）+ 位置/缩放/旋转。
  - 效果图与姿势**互相独立增删**，不强求数量一致、不一一对应。
- 分类下拉由四级级联改为**三级级联**（大类 → 风格 → 子风格）。
- `EditorFormMeta` / `fromEditorForm` / `toEditorForm` 同步：`cover` → `images[]`、单 `pose` → `poses[]`、分类三级。
- 保存/导出时遵循新数组结构。

## 七、后台上传模板（Admin）

文件：`lumira-server/packages/admin/`

- 模板新建/编辑表单：效果图**多图上传（第一张 = 封面）** + 姿势**多组剪影上传/配置**；效果图与剪影独立，数量可不等、不一一对应。
- 分类选择收敛为**三级级联**。
- 保存后接口按 4.1 数组结构落库、返回。

## 八、内置模板种子 & 归并（Flutter）

文件：`builtin_data_seeder.dart`、`template_registry.dart`、相关 mock/断言

- 现有 132 款按其「子风格 × 姿势」**归并**为「模板套」：同一模板级共享配置 + 各自多样的 `images[]` 与 `poses[]`。
- 三级分类树由 seeder 重生成；断言与 `template_registry_test.dart` 数量按新模型调整。
- 关键词搜索 / 推荐算法以**套（模板）**为粒度，保证命中唯一、封面取 `images[0]`。

## 九、改动文件清单（预估）

| 模块 | 文件 | 改动 |
|---|---|---|
| Flutter 模型 | `PhotoTemplate`/`TemplateClassification` 定义 | pose→poses、cover→images、分类三级 |
| Flutter 映射 | `template_mapper.dart` | 数组读写 + 老数据兼容 + 三级分类 |
| Flutter DB | `tables.dart`、`templates_dao.dart`、`TemplateRecord` | pose_json→数组、images 字段 |
| Flutter 卡片/详情 | 模板卡片、`templates_detail_page.dart` | 封面统一取 images[0]；多图画廊；姿势组预览 |
| Flutter 拍摄 | 拍摄页/`capture_state.dart` 相关 | poses 切换按钮 |
| Flutter 表单 | `templates_editor_page.dart`、`templates_editor_mock_data.dart` | 效果图/姿势双列表；三级级联 |
| Flutter seeder | `builtin_data_seeder.dart`、`template_registry.dart` | 归并为套；三级分类树；断言 |
| 后端 | 模板 DTO / service / 表定义 / 迁移 | images[]、poses[]、三级分类 |
| 后台 | admin 模板表单/接口 | 多图+多剪影、三级级联 |
| 测试 | mapper/editor/seeder 相关测试 | 按新结构更新 |

## 十、主题与验证

- 所有 UI 样式从 `appThemeProvider` / `uiStyleProvider` 派生，遵循 4 风格规范，不硬编码。
- `flutter analyze` 通过；`flutter test`（mapper / editor / seeder / registry 相关）通过。
- 真机验证：卡片/推荐封面一致；详情多图画廊；拍摄页多姿势切换（>1 显示按钮、=1 不显示）；编辑效果图/剪影独立增删；后台多图上传与首图封面。
- 老数据迁移后能加载（兼容旧 pose_json / 旧分类）。