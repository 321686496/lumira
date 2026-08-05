# 设置页合规与法律内容 — 设计文档

日期：2026-08-05
范围：`lumira_app_flutter/`（Flutter 客户端，纯前端静态内容，不涉及后端）

## 1. 目标

在设置页新增「合规与法律」分组，提供 3 个国内 App 上架合规条目入口，点击进入独立静态详情页：

1. 用户协议
2. 隐私政策
3. 个人信息清单与第三方 SDK 目录

## 2. 设置页改动

文件：`lib/features/profile/pages/profile_settings_page.dart`

- 在「关于」分组之后新增分组标题 `合规与法律`（复用 `_GroupTitle`）
- 一个 `NeuCard` 内含 3 个 `_SettingItem` 条目，样式与现有分组完全一致
- 每个条目带图标 + 右箭头，`onTap` 跳转对应路由

## 3. 详情页

新增 3 个文件：

- `lib/features/profile/pages/compliance_doc_page.dart` — 通用静态正文页 `ComplianceDocPage`
  - 构造参数：`title`、`updatedAt`、`List<ComplianceSection>`
  - 视觉复用「关于如画」页模式：`LumiraNav`（透明 + 返回按钮）+ 渐变背景 + 滚动正文
  - 章节渲染：小节标题（加粗）+ 段落正文；列表型章节（个人信息清单 / SDK）渲染为「字段 / 内容」行
  - 页面底部显示更新时间
- `lib/features/profile/data/compliance_content.dart` — 集中存放 3 篇文档的结构化内容
  - 数据模型：`ComplianceSection { String title; List<ComplianceBlock> }`，`ComplianceBlock` 支持段落 / 键值行两种形式
  - 3 篇内容：
    - 用户协议（agreement）：服务说明、账号与行为规范、内容知识产权、免责声明、协议变更与终止、联系方式等标准条款
    - 隐私政策（privacy）：收集的信息与用途、存储与保护、共享与第三方、用户权利、未成年人保护、政策更新、联系方式等
    - 个人信息清单与 SDK 目录（sdk）：收集场景 / 信息类型 / 用途 / 是否必需；第三方 SDK：名称 / 提供方 / 用途 / 收集信息
- 内容为正式占位性文本，后续可替换为法务审核后的正式版本

## 4. 路由

`lib/core/router/route_names.dart` 新增 3 个常量：

- `profileComplianceAgreement = '/profile/settings/agreement'`
- `profileCompliancePrivacy = '/profile/settings/privacy'`
- `profileComplianceSdk = '/profile/settings/sdk'`

`lib/app/router.dart` 在 `profileSettingsTheme` 附近新增 3 个 `GoRoute`，各自绑定 `ComplianceDocPage` 并传入对应内容数据。

## 5. 明确不做

- 不添加儿童隐私保护规则（未要求）
- 不做弹窗 / 底部面板形式
- 不改动后端、不新增依赖
- 不改动 uni-app 原型（`lumira-app/`）
