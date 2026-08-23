# 自定义模板表单 Tab 化重设计 + 新字段 设计

> 日期：2026-08-23
> 范围：Flutter 端自定义模板创建/编辑表单从「长列表滚动表单」改为「顶部 Tab 切换表单」，镜像后台新建模板表单交互；补齐模板新字段（短简介 / 四级分类 / 适用季节天气时段）；标签改为「选旧 + 新增」。
> 状态：设计已获用户确认。

## 一、背景与目标

当前自定义模板表单页 `lumira_app_flutter/lib/features/templates/pages/templates_editor_page.dart` 将 6 个 step 全部堆叠在单个 `SingleChildScrollView` 中，字段多、页面极长，长时间滚动填写体验差。

同时模板信息在后台新增了一批字段（短简介、适用季节/天气/时段、四级分类），但自定义模板表单页未同步。此外，标签目前是「用逗号分隔的文本框」，期望改为「从用户已添加过的自定义标签中勾选 + 输入新增」。

目标：
1. 改为**顶部 Tab 切换**，交互镜像后台新建模板表单。
2. 补齐自定义模板可填写的新字段。
3. 标签支持「选旧标签 / 新增标签」。

约束：所有样式必须从 `themeTokensProvider`（`AppThemeData.tokens` 等）+ `uiStyleProvider` 派生，遵循 neumorphic/flat/glass/female 四风格该有的浮层取向，禁止硬编码颜色/阴影。改动全部在 Flutter 端，不动后台。

## 二、决策记录

| 决策点 | 结论 |
|---|---|
| 布局 | 顶部 6 个 Tab + `AnimatedSwitcher` 切换内容，镜像后台 `STEPS` |
| Tab 分组 | 完全镜像后台：基本信息 / 封面与剪影 / 构图 / 相机参数 / 场景引导 / 后期处理 |
| 封面图归属 | 从「基本信息」移入「封面与剪影」；姿势剪影（原独立 Step3）并入「封面与剪影」 |
| 新增字段 | 短简介 shortDesc、适用季节/天气/时段 ambience、四级分类 |
| 不暴露字段 | 价格 / 作者 / 版本号 / 排序 / 上架（后台运营专属，自定义模板不需要） |
| 分类存储 | 对齐后端四级 `{type, majorStyle, subStyle, method}`，对旧数据 `{type, style, method}` 向后兼容读取 |
| 标签交互 | 候选 chips（聚合自定义模板的标签，按频次排序）+「新增标签」输入 |
| 候选标签来源 | `TemplatesDao` 聚合 `source='custom'` 模板的 `tags`，去重；无需新增表 |

## 三、顶层布局（交互层）

改造点在 `templates_editor_page.dart` 的 `build()`：

```
LumiraNav(标题：新建模板/编辑模板)            ← 保留
└─ 顶部 Tab 条（横向，主题自适应）
   [基本信息][封面与剪影][构图][相机参数][场景引导][后期处理]
└─ Expanded
   └─ AnimatedSwitcher(按当前 Tab 渲染对应内容)
      └─ 每个 Tab 内容自带 Scroll（原 step 的 body 抽离）
└─ _EditorFooter(草稿/预览/保存/导出)         ← 保留
```

原 `SingleChildScrollView` 中按顺序排列的 6 个 step 拆分为 6 档 Tab 内容，一次只渲染当前 Tab。底部 footer 与顶部 Tab 固定，中间内容区随 Tab 切换。

Tab 条样式用 `tokens` 派生：当前风格为需浮层的用浮层取向，纯画布上用画布取向；选中态用主题强调色区分。参考后台 step chips 的「编号 + 标题」样式，但按各自 UI 风格实现。

## 四、Tab → 字段映射

| Tab | 字段 | 变更 |
|---|---|---|
| 基本信息 | 模板名称*、四级分类（新）、短简介（新）、适用季节/天气/时段（新）、标签（增强）、简介、参数参考来源 | 封面图移出；+3 类新字段 |
| 封面与剪影 | 效果图（封面图）、姿势剪影（来源/内置/导入/绘制 + 位置/缩放/旋转 + 描述） | 封面移入；姿势剪影并入 |
| 构图 | overlayType、gridType、subjectFrame、aspectRatio、opacity、description | 原 Step2，不变 |
| 相机参数 | exposure、isoMode/iso、shutterSpeed、whiteBalance/K、flashMode、focusMode、lensSuggestion/lensType | 原 Step4，不变 |
| 场景引导 | lightDirection、shootingDistance、background、props、bestTime、tips | 原 Step5，不变 |
| 后期处理 | cropRatio、color（基础+高级）、smoothStrength、sharpen、vignette、grain、lut/systemFilter、fillLight | 原 Step6，不变 |

## 五、数据模型更新

文件：`lumira_app_flutter/lib/features/templates/data/templates_editor_mock_data.dart`

### 5.1 `EditorFormMeta` 扩展
新增：
- `String shortDesc`（短简介，≤20 字展示约束）
- `EditorFormAmbience? ambience`（季节/天气/时段，结构对齐 `RemoteTemplateAmbienceDto`：`seasons`、`weathers`、`timeTones`）

四级分类字段（与后端 `{type, majorStyle, subStyle, method}` 完全对齐）：
- `category`：一级（type）
- `style`：二级（majorStyle）
- `subStyle`：三级（subStyle）——**由现有 `method` 改得更名而来**（旧字段原存储 key 为 `method`，实为三级）
- `method`：四级（method）——**新增**，表达第 4 级「方法」

> 即：把旧 `EditorFormMeta.method`（三级）改名为 `subStyle`，再新增一个 `method` 字段表示四级。「切换上级时清空下级」保持现状键位即可。

`copy()`、`createBlankEditorForm()`、mock 数据同步补充/改名新字段。

### 5.2 四级分类持久化
- 表单展示 4 个级联下拉：一级(题材)→二级(大风格)→三级(子风格)→四级(方法)。
- `templates_editor_page.dart` `_Step1TemplateInfoState` 当前只做三级级联加载（`_typeOptions`→`_styleOptions`→`_methodOptions`，按 `getCategoriesByParent`）。改为四级级联，新增第 4 级选项加载与「切换上级时清空下级」逻辑。
- `template_mapper.dart`：
  - `fromEditorForm` 的 `classificationJson` 由 `{type, style, method}` 改为 `{type, majorStyle, subStyle, method}`（字段值从表单四级读取）。
  - `toEditorForm` 读取 classification 时做向后兼容：`majorStyle ?? style`、`subStyle`、`method`，缺失回空。

> 说明：后端已迁移为 `{type, majorStyle, subStyle, method}`（见 2026-08-17 四级分类设计），此处让本地自定义模板存储与之一致。

## 六、标签交互与数据源

- 标签组件替换当前逗号文本框（`_Step1TemplateInfo` 中 `标签` 字段）：
  - 已有自定义模板聚合出的候选标签若干
  - **候选**：`TemplatesDao` 查 `source='custom'` 模板，聚合 `tags` 去重（保留出现频次，候选按频次降序展示）
  - **新增**：一个输入框 + 添加按钮，输入后追加为标签
  - 选中项以 chips 形式展示，可取消（从 `meta.tags` 增删）
- 现有 `_tagsController`、`_onTagsChanged` 逻辑保留，改为驱动 chips 选中集。

## 七、改动文件清单（预估）

| 文件 | 改动 |
|---|---|
| `lib/features/templates/data/templates_editor_mock_data.dart` | `EditorFormMeta` + 新增 `EditorFormAmbience`/四级字段；`copy`/`createBlankEditorForm`/mock |
| `lib/features/templates/pages/templates_editor_page.dart` | 顶层改 Tab 布局；`_Step1TemplateInfoState` 四级级联 + 短简介/ambience/标签 UI；封面与剪影 Tab；其余 list attr 抽离 |
| `lib/features/templates/services/template_mapper.dart` | classification 四级读写 + 向后兼容；shortDesc/ambience 持久化（shortDesc 已支持，需接入表单） |
| `lib/features/templates/data/preview_form_provider.dart` | 若依赖 `EditorForm` 新字段则同步 |
| 相关测试 | `templates_editor_test` 等按需更新 |

## 八、主题与验证

- 全部样式用 `ref.watch(appThemeProvider)` / `uiStyleProvider` 派生，遵循四风格规范，不硬编码。
- 新增 `EditorForm.ambience` 序列化/反序列化与 mapper 保持对齐。
- `flutter analyze` 通过；`flutter test`（editor/mapper 相关用例）通过。
- 真机验证：Tab 切换、四级级联、标签选旧/新增、封面与剪影合一后的裁剪/绘制可用、保存后回填字段正确。