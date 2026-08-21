# 模板/场景标签 UI 优化 + 系统标签去重 + 模板详情完整分类信息

日期：2026-08-21
范围：Flutter 端（`lumira_app_flutter/`），无后端/后台改动。

## 背景与问题

1. **标签 UI 不随主题/UI 风格变化**：模板详情、场景详情、统一标签区块里的标签 chip 与选择器多处使用「裸 `Container` + 硬编码色」或「强制 `NeuCard` 新拟态」写法，不遵循 AGENTS.md 的 4 套 UI 风格 × 多主题铁律，且无呼吸按压反馈。
2. **模板详情系统标签重复**：`_TitleAndTags`（标题下）已展示 `template.tags`，随后的 `UserTagsSection(systemTags: template.tags)` 又带「系统」角标重复展示同一组系统标签。
3. **模板详情分类信息不完整**：目前仅在封面图左上角展示一级分类 `categoryLabel`，而模板实际拥有四级分类（type → majorStyle → subStyle → method），未展示完整分类路径。

## 已确认的设计决策

- **系统标签去重**：保留标题下方的系统标签，`UserTagsSection` 不再重复展示系统标签（只负责用户自定义标签的展示与增删）。
- **分类展示**：在标题下方新增「分类面包屑」，展示完整分类路径（如 `人像 · 日系 · 情绪`）；封面图保留一级分类角标。
- **系统标签样式**：系统标签**不写「系统」二字**，改用区别于自定义标签的**特殊 UI 样式**标识。

## 改动方案

### A. 新增共享风格自适应组件

新建 `lib/shared/widgets/tags/tag_chip.dart`：
- `TagChip`（`ConsumerWidget`），参数：`label`、`kind`（枚举 `plain` 自定义 / `system` 系统 / `golden` 场景推荐）、`selected`、`onTap`、`onDeleted`。
- 按 `appTheme.style` 自适应装饰（对齐 `NeuCard` 的分支逻辑）：
  - `neumorphic`：实心 `surface`/`surfaceAlt` + 细 `divider` 描边（chip 位于卡片/画布上，不做双向浮雕外阴影）。
  - `flat`：`surfaceAlt` + `divider` 细边框。
  - `glass`：半透明白玻璃底 + 白色细边。
  - `female`：不透明暖色柔和微渐变（`brandSubtle→surface`）+ 柔和品牌阴影。
- `system` kind 使用区别于普通标签的特殊视觉（如品牌色实底/带小图标），**不含「系统」文本**。
- 可交互时（`onTap`/`onDeleted`）走呼吸按压反馈（复用 `breathing_tap.dart` 的 140ms easeIn 内缩 + 300ms easeOutBack 回弹）。

### B. 模板详情页（`templates_detail_page.dart`）

- `_TitleAndTags`：
  - 系统标签改用 `TagChip(kind: system)` 渲染（替换裸 `Container`）。
  - 新增**分类面包屑行**（见 D）。
  - 移除占位/废弃的「添加」按钮与 `_TagSelector`（placeholder 静态标签，真实增删已由 `UserTagsSection` 承担；当前点击仅弹「即将上线」占位）。按项目「去除未完成占位功能」约定清理。
- `UserTagsSection` 调用改为 `systemTags: const []`（去重，仅用户自定义标签）。
- 删除废弃的 `_TagSelector` / `_TagChip` 私有实现，改用共享 `TagChip`。

### C. 场景详情页（`capture_scene_detail_page.dart`）

- `_TagsSection` / `_TagChip` / `_TagSelectorSheet` 改为共享 `TagChip` + `NeuCard` 容器（`NeuCard` 本身已风格自适应），替换裸 `Container`。

### D. 完整分类信息（模板详情）

- 扩展 `TemplateDetail`：新增可空字段 `majorStyle`、`subStyle`、`method`（分类 key）。
- `TemplatesBrowseMockData.fromPhotoTemplate` 从 `tpl.meta.classification` 回填（`type→category` 已有；补 `majorStyle/subStyle/method`）。
- 新建 provider `templateCategoryNameProvider`：加载 `TemplatesDao` 全量分类树 → `Map<key, 中文名>`。
- `_TitleAndTags` 读取该 provider，将非空分类段（`categoryLabel(category)`、`majorStyle`、`subStyle`、`method`）用 ` · ` 拼接，展示为分类面包屑；无分类数据的模板（静态 mock）仅展示一级分类名（不回退、不报错）。

### E. 样式一致性 / 输入框

- `UserTagsSection` 的标签输入改为 `LumiraTextField`（随主题自动）、chip 复用 `TagChip(kind: plain)`，去掉其 `_Chip` 私有的「系统」文本逻辑。

## 不做的事（YAGNI）

- 不改后端/后台、不改数据表结构、不新增数据库迁移。
- 不为静态 mock 模板逐条补分类数据（保证不回退即可；远程/自定义模板已带完整 classification）。
- 不引入 `_TagSelector` 的真实 CRUD 能力（新增标签已由 `UserTagsSection` 承担）。

## 验证

- `flutter analyze` 无新增 error。
- 补齐/更新标签相关 widget 测试，覆盖 4 种风格 × 关键交互（复用 `themeTokensProvider`/`appThemeProvider` 注入）。
- 运行 `flutter test` 相关用例。