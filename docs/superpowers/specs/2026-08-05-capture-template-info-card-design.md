# 拍摄页套用模板后顶部可折叠模板信息卡

**日期**: 2026-08-05
**状态**: 已通过设计评审，待编写实现计划
**关联文档**:
- 拍照页增强: `docs/superpowers/specs/2026-07-14-capture-page-enhancement-design.md`
- 拍摄页全功能: `docs/superpowers/specs/2026-07-21-capture-page-full-features-design.md`

---

## 一、背景与目标

### 1.1 问题

拍摄页（`CapturePage`）套用模板后，顶部区域没有展示模板的简介与拍摄注意点。模板数据中 `meta.description`（一句话简介）与 `sceneGuide.tips`（拍摄注意点列表，如"避免顶光直射造成眼窝阴影"）在拍摄过程中完全不可见，用户无法在取景时对照模板的拍摄要点。

### 1.2 目标

1. 套用模板后，拍摄页上方区域显示一个**可折叠卡片**，展示模板简介 + 拍摄注意点
2. 卡片默认展开（让用户第一时间看到拍摄要点），可手动收起
3. 全屏模式下卡片隐藏，退出全屏恢复（与参数 Pill 栏一致）
4. 切换模板时卡片内容更新并重置为展开

### 1.3 范围边界

| 项 | 本次实现 | 不在本次范围 |
|---|---|---|
| 数据源 | `PhotoTemplate.meta.description` + `sceneGuide.tips` | 不新增模板数据字段 |
| UI | 新增 `TemplateInfoCard` 组件 + 拍摄页顶部布局整合 | 不重新设计其他顶部浮层 |
| 交互 | 折叠/展开切换、模板切换重置、全屏隐藏 | 不做拍照时自动折叠、不做卡片样式配置 |

---

## 二、设计

### 2.1 方案选型

采用**方案 A：顶部 Column 整合 + 独立可折叠卡片组件**。

理由：
- 卡片高度动态变化（tips 数量 3-4 条不等），用 Column 让下方浮层（比例切换器、挑战悬浮条、参数 Pill 栏）随卡片自然流动，**无需手工计算偏移**，展开/收起动画期间所有元素平滑跟随
- 复用 `ChallengeOverlayBar` 已验证的浮层视觉语言与 `AnimatedSize` 方案，风格统一、风险低
- 卡片组件独立成文件，职责单一，便于单测与后续复用

### 2.2 新增组件：`TemplateInfoCard`

位置：`lumira_app_flutter/lib/features/capture/widgets/template_info_card.dart`

**类型**：`ConsumerStatefulWidget`，接收 `PhotoTemplate template` 参数。

**状态**：
- 本地 `bool _expanded`（默认 `true`，即套用模板默认展开）
- `didUpdateWidget`：当 `template.meta.id` 变化时，`_expanded` 重置为 `true`（新模板默认展开）

**视觉**（与 `ChallengeOverlayBar` 保持一致）：
- `Material(color: transparent)` + `AnimatedSize(240ms, easeOutCubic)`
- 外层 `GestureDetector(onTap: 切换折叠, behavior: opaque)`
- 容器：`margin: horizontal 12, vertical 8`；`padding: horizontal 14, vertical 10~12`
- 背景 `Color(0xF0171512).withOpacity(0.92)`；圆角折叠 24 / 展开 14；边框品牌色 35% 透明度 1px；阴影黑色 30% (0,4) blur 12

**内容结构**：
- 标题行（常显）：`Icons.auto_awesome`（品牌色 16）+ 模板名（白色 13 w600，单行省略）+ 展开箭头（`AnimatedRotation`，折叠 0 / 展开 0.5）
- 展开区：
  - 分隔线（白色 12% 透明度 1px）
  - 简介：`template.meta.description`（白色 78% 透明度 12，行高 1.5，最多 3 行省略）
  - 注意点列表：`template.sceneGuide.tips` 每条一行，`Icons.check_circle_outline`（品牌色 13）+ 文案（白色 85% 透明度 11，行高 1.5），条目间 6px 间距
- **兜底**：`description` 与 `tips` 均为空时仅渲染标题行（无展开内容）

### 2.3 布局改动：`CapturePage.build`

将顶部 3 个独立 `Positioned` 浮层整合为一个顶部 Column：

```
Positioned(top: padding.top + 56, left: 0, right: 0)
└─ Column(mainAxisSize: min)
   ├─ [TemplateInfoCard]          // template != null 且 !isFullscreen
   ├─ SizedBox(height: 8)
   ├─ Center(AspectRatioSelector) // 常显（含全屏），行为不变
   ├─ [ChallengeOverlayBar]       // isChallengeMode 且 !isFullscreen
   └─ Padding(horizontal: 12)
      └─ [ParamPillBar]           // !isFullscreen
```

改动点：
- 删除原 2.5（比例切换器 `+64`）、2.6（挑战悬浮条 `+104`）、3（参数 Pill 栏 `+112`/`+168`）三个独立 `Positioned`
- 新增一个顶部 Column `Positioned`（top = `padding.top + 56`）
- 模板卡数据源：`ref.watch(CaptureState.originalTemplateProvider)`（自定义/远程模板的 description、tips 已由 `TemplateMapper` 完整映射）

### 2.4 交互细节

| 场景 | 行为 |
|---|---|
| 套用模板（含 kit 套件 / 挑战模式带模板） | 卡片出现，默认展开 |
| 自由模式（无模板） | 卡片不显示，布局与原一致 |
| 切换模板 | 卡片内容更新，`_expanded` 重置为 true |
| 取消模板（点击已选中模板） | 卡片消失 |
| 全屏 | 卡片隐藏；退出全屏恢复 |
| 挑战模式 + 模板 | 卡片与挑战悬浮条在 Column 中顺序堆叠 |

### 2.5 数据流

- `TemplateStrip` 点击 → `currentTemplateIdProvider` 变化 → `originalTemplateProvider` 派生新模板 → 卡片 `didUpdateWidget` 感知 id 变化重置展开 → 内容重新渲染
- 无新增 Provider / DAO / 后端改动

---

## 三、验证

1. `flutter analyze` 通过（项目 Dart 2.19.6 / Flutter 3.7.12）
2. 手动验证：
   - 套用模板 → 卡片出现且展开，简介 + 注意点正确显示
   - 点击卡片 → 折叠 / 再点 → 展开，下方浮层平滑跟随
   - 全屏 → 卡片隐藏；退出恢复
   - 切换模板 → 内容更新且重新展开
   - 自由模式 → 无卡片，布局正常
