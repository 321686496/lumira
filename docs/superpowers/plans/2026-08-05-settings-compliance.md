# 设置页合规与法律内容 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在设置页新增「合规与法律」分组，提供用户协议、隐私政策、个人信息清单与第三方 SDK 目录 3 个静态详情页入口。

**Architecture:** 纯前端静态内容。新增 1 个数据文件（模型 + 3 篇结构化文档）、1 个通用正文页 `ComplianceDocPage`（3 个路由复用同一页面类），设置页复用现有 `_GroupTitle` / `_SettingItem` / `NeuCard` 新增分组，路由注册遵循现有 `RouteNames + GoRoute` 模式。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6、flutter_riverpod、go_router、flutter_test

## Global Constraints

- Dart 2.19.6：**禁止 Dart 3 语法**（`sealed`、records、patterns、class modifiers、switch 表达式 pattern 等），抽象类用 `abstract class` + const 构造
- 所有颜色/字体必须使用 `ThemeTokens` 中的 token（`tokens.canvas` / `textPrimary` / `textSecondary` / `textTertiary` / `brand` / `brandSubtle` / `brandLight` / `divider` / `surface`），禁止新增自定义颜色
- 视觉模式参照 `profile_about_page.dart`：`LumiraNav`（透明 + `_BackButton`）+ 渐变背景 + `SingleChildScrollView`
- 列表型正文（个人信息清单 / SDK 目录）用「字段 / 内容」键值行呈现
- 新文件路径：
  - `lumira_app_flutter/lib/features/profile/data/compliance_content.dart`
  - `lumira_app_flutter/lib/features/profile/pages/compliance_doc_page.dart`
  - `lumira_app_flutter/test/features/profile/compliance_content_test.dart`
  - `lumira_app_flutter/test/features/profile/compliance_doc_page_test.dart`
- 不改动 `lumira-app/`（uni-app 原型）、不改后端、不新增依赖

---

### Task 1: 合规文档数据模型与内容

**Files:**
- Create: `lumira_app_flutter/lib/features/profile/data/compliance_content.dart`
- Test: `lumira_app_flutter/test/features/profile/compliance_content_test.dart`

**Interfaces:**
- Produces（Task 2 消费）:
  - `class ComplianceSection { final String title; final List<ComplianceBlock> blocks; const ComplianceSection({required this.title, required this.blocks}); }`
  - `abstract class ComplianceBlock { const ComplianceBlock(); }`
  - `class ComplianceParagraph extends ComplianceBlock { final String text; const ComplianceParagraph(this.text); }`
  - `class ComplianceKVRow extends ComplianceBlock { final String label; final String value; const ComplianceKVRow({required this.label, required this.value}); }`
  - `class ComplianceListItem extends ComplianceBlock { final String title; final List<ComplianceKVRow> rows; const ComplianceListItem({required this.title, required this.rows}); }`
  - `class ComplianceDocs { static const String agreementUpdatedAt; static const List<ComplianceSection> agreement; static const String privacyUpdatedAt; static const List<ComplianceSection> privacy; static const String sdkUpdatedAt; static const List<ComplianceSection> sdk; }`

- [ ] **Step 1: 写失败的单测**

创建 `lumira_app_flutter/test/features/profile/compliance_content_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/profile/data/compliance_content.dart';

void main() {
  group('ComplianceDocs', () {
    test('用户协议非空且包含关键章节', () {
      expect(ComplianceDocs.agreement, isNotEmpty);
      expect(ComplianceDocs.agreementUpdatedAt, isNotEmpty);
      final titles = ComplianceDocs.agreement.map((s) => s.title).toList();
      expect(titles, contains('服务内容'));
      expect(titles, contains('知识产权'));
    });

    test('隐私政策非空且包含关键章节', () {
      expect(ComplianceDocs.privacy, isNotEmpty);
      expect(ComplianceDocs.privacyUpdatedAt, isNotEmpty);
      final titles = ComplianceDocs.privacy.map((s) => s.title).toList();
      expect(titles, contains('我们收集的信息'));
      expect(titles, contains('未成年人保护'));
    });

    test('个人信息清单与SDK目录包含键值行与列表项', () {
      expect(ComplianceDocs.sdk, isNotEmpty);
      expect(ComplianceDocs.sdkUpdatedAt, isNotEmpty);
      final sections = ComplianceDocs.sdk;
      final hasKV = sections.any((s) => s.blocks.any((b) => b is ComplianceKVRow));
      final hasListItem = sections.any((s) => s.blocks.any((b) => b is ComplianceListItem));
      expect(hasKV, isTrue);
      expect(hasListItem, isTrue);
    });

    test('每个 section 的 blocks 均为受支持的类型', () {
      for (final doc in [ComplianceDocs.agreement, ComplianceDocs.privacy, ComplianceDocs.sdk]) {
        for (final section in doc) {
          for (final block in section.blocks) {
            expect(
              block is ComplianceParagraph ||
                  block is ComplianceKVRow ||
                  block is ComplianceListItem,
              isTrue,
              reason: 'unexpected block ${block.runtimeType}',
            );
          }
        }
      }
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/profile/compliance_content_test.dart`（cwd: `lumira_app_flutter/`）
Expected: 编译失败，报 `URI target doesn't exist: compliance_content.dart`

- [ ] **Step 3: 实现数据模型与内容**

创建 `lumira_app_flutter/lib/features/profile/data/compliance_content.dart`：

```dart
/// 合规文档（用户协议 / 隐私政策 / 个人信息清单与SDK目录）结构化数据。
///
/// 国内 App 上架合规要求。内容为正式占位文本，后续可替换为法务审核后的正式版本。

/// 一个章节：小节标题 + 若干正文块
class ComplianceSection {
  const ComplianceSection({required this.title, required this.blocks});

  final String title;
  final List<ComplianceBlock> blocks;
}

/// 正文块基类
abstract class ComplianceBlock {
  const ComplianceBlock();
}

/// 段落正文
class ComplianceParagraph extends ComplianceBlock {
  const ComplianceParagraph(this.text);

  final String text;
}

/// 「字段 / 内容」键值行（用于清单类条目字段）
class ComplianceKVRow extends ComplianceBlock {
  const ComplianceKVRow({required this.label, required this.value});

  final String label;
  final String value;
}

/// 带标题的列表项（用于个人信息清单 / SDK 目录中的单个条目）
class ComplianceListItem extends ComplianceBlock {
  const ComplianceListItem({required this.title, required this.rows});

  final String title;
  final List<ComplianceKVRow> rows;
}

/// 3 篇合规文档的入口
class ComplianceDocs {
  ComplianceDocs._();

  // ===== 用户协议 =====
  static const String agreementUpdatedAt = '2026-08-05';

  static const List<ComplianceSection> agreement = [
    ComplianceSection(
      title: '一、协议的接受与范围',
      blocks: [
        ComplianceParagraph(
          '欢迎使用「如画 Lumira」。在使用本应用前，请您仔细阅读并充分理解本用户协议的全部内容。您点击同意、开始使用或继续使用本应用，即视为您已阅读并同意接受本协议的约束。',
        ),
        ComplianceParagraph(
          '如您为未成年人，请在监护人陪同下阅读本协议，并在取得监护人同意后使用本应用。',
        ),
      ],
    ),
    ComplianceSection(
      title: '二、服务内容',
      blocks: [
        ComplianceParagraph(
          '本应用提供摄影模板、拍摄指导、作品管理与分享等线上服务。我们可能根据产品规划对服务内容进行增加、调整或下线，并将通过合理方式向您告知。',
        ),
      ],
    ),
    ComplianceSection(
      title: '三、账号与行为规范',
      blocks: [
        ComplianceParagraph(
          '您应妥善保管账号与登录凭证，不得出借、转让或与他人共享。因您保管不善导致的损失由您自行承担。',
        ),
        ComplianceParagraph(
          '您承诺在使用本应用时不发布、传播法律法规禁止的内容，不从事任何侵犯他人合法权益或危害网络安全的行为。',
        ),
      ],
    ),
    ComplianceSection(
      title: '四、知识产权',
      blocks: [
        ComplianceParagraph(
          '本应用所展示的界面、文案、模板素材、软件程序等内容的知识产权归我们或相关权利人所有。未经许可，您不得以任何形式复制、修改、传播或用于商业用途。',
        ),
        ComplianceParagraph(
          '您通过本应用创作的作品，其著作权归您所有。您授权我们在为您提供服务的必要范围内使用您的作品。',
        ),
      ],
    ),
    ComplianceSection(
      title: '五、免责声明',
      blocks: [
        ComplianceParagraph(
          '我们将尽合理努力保障服务的稳定与安全，但因不可抗力、网络故障、第三方服务异常等原因导致服务中断或数据丢失的，我们将在法律允许的范围内免除责任。',
        ),
      ],
    ),
    ComplianceSection(
      title: '六、协议的变更与终止',
      blocks: [
        ComplianceParagraph(
          '我们可能根据法律法规或业务需要修订本协议。修订后的协议将在应用内公布，若您继续使用本应用，即视为接受修订后的协议。',
        ),
        ComplianceParagraph(
          '如您违反本协议约定，我们有权视情况采取警示、限制功能、暂停或终止服务等措施。',
        ),
      ],
    ),
    ComplianceSection(
      title: '七、法律适用与争议解决',
      blocks: [
        ComplianceParagraph(
          '本协议的订立、履行与解释均适用中华人民共和国法律。因本协议产生的争议，双方应友好协商解决；协商不成的，任何一方可向有管辖权的人民法院提起诉讼。',
        ),
      ],
    ),
    ComplianceSection(
      title: '八、联系我们',
      blocks: [
        ComplianceKVRow(label: '官方邮箱', value: 'hello@lumira.app'),
        ComplianceKVRow(label: '用户反馈', value: 'feedback@lumira.app'),
      ],
    ),
  ];

  // ===== 隐私政策 =====
  static const String privacyUpdatedAt = '2026-08-05';

  static const List<ComplianceSection> privacy = [
    ComplianceSection(
      title: '一、引言',
      blocks: [
        ComplianceParagraph(
          '我们深知个人信息对您的重要性，并会尽全力保护您的个人信息安全。本隐私政策旨在说明我们如何收集、使用、存储、共享和保护您的个人信息，以及您享有的相关权利。',
        ),
      ],
    ),
    ComplianceSection(
      title: '二、我们收集的信息',
      blocks: [
        ComplianceParagraph('在您使用本应用的过程中，我们可能会收集以下类别的信息：'),
        ComplianceListItem(
          title: '账号信息',
          rows: [
            ComplianceKVRow(label: '信息类型', value: '昵称、头像、联系方式（如您主动提供）'),
            ComplianceKVRow(label: '使用目的', value: '用于账号注册、登录与身份验证'),
            ComplianceKVRow(label: '是否必需', value: '否，仅在您主动填写时收集'),
          ],
        ),
        ComplianceListItem(
          title: '设备信息',
          rows: [
            ComplianceKVRow(label: '信息类型', value: '设备型号、操作系统版本、设备标识符'),
            ComplianceKVRow(label: '使用目的', value: '用于保障服务安全、排查故障与统计分析'),
            ComplianceKVRow(label: '是否必需', value: '是，用于基础功能运行'),
          ],
        ),
        ComplianceListItem(
          title: '作品数据',
          rows: [
            ComplianceKVRow(label: '信息类型', value: '您拍摄的照片、创作的作品与相关设置'),
            ComplianceKVRow(label: '使用目的', value: '用于为您提供拍摄、编辑与作品管理功能'),
            ComplianceKVRow(label: '是否必需', value: '是，为功能核心数据'),
          ],
        ),
      ],
    ),
    ComplianceSection(
      title: '三、信息的使用目的',
      blocks: [
        ComplianceParagraph(
          '我们仅在实现以下目的所必需的范围内使用您的信息：提供与维护服务、改进产品体验、保障账户与网络安全、履行法律法规义务。',
        ),
      ],
    ),
    ComplianceSection(
      title: '四、信息的存储与保护',
      blocks: [
        ComplianceParagraph(
          '您的作品数据默认保存在您的设备本地。若您使用云端相关功能，数据将存储于中国大陆境内的服务器。',
        ),
        ComplianceParagraph(
          '我们采用加密传输、访问控制等合理的技术与管理措施保护您的个人信息，并定期开展安全评估。',
        ),
      ],
    ),
    ComplianceSection(
      title: '五、信息的共享与第三方服务',
      blocks: [
        ComplianceParagraph(
          '我们不会向第三方出售您的个人信息。仅在与第三方 SDK 提供方合作、且为实现基本功能所必需时，我们才会共享必要的信息，具体见《个人信息清单与第三方 SDK 目录》。',
        ),
      ],
    ),
    ComplianceSection(
      title: '六、您的权利',
      blocks: [
        ComplianceParagraph(
          '您有权查询、更正、删除您的个人信息，有权撤回授权同意，并有权注销您的账号。您可以通过本政策底部提供的联系方式行使上述权利，我们将在 15 个工作日内予以响应。',
        ),
      ],
    ),
    ComplianceSection(
      title: '七、未成年人保护',
      blocks: [
        ComplianceParagraph(
          '我们非常重视未成年人的个人信息保护。若您为未满 14 周岁的儿童，请在监护人同意和指导下使用本应用；如我们发现在未取得监护人同意的情况下收集了儿童个人信息，将尽快删除相关数据。',
        ),
      ],
    ),
    ComplianceSection(
      title: '八、政策的更新',
      blocks: [
        ComplianceParagraph(
          '我们可能适时修订本隐私政策。重大变更将以应用内显著方式通知您，您继续使用本应用即视为接受修订后的政策。',
        ),
      ],
    ),
    ComplianceSection(
      title: '九、联系我们',
      blocks: [
        ComplianceKVRow(label: '隐私保护负责人邮箱', value: 'privacy@lumira.app'),
        ComplianceKVRow(label: '用户反馈', value: 'feedback@lumira.app'),
      ],
    ),
  ];

  // ===== 个人信息清单与第三方 SDK 目录 =====
  static const String sdkUpdatedAt = '2026-08-05';

  static const List<ComplianceSection> sdk = [
    ComplianceSection(
      title: '一、个人信息收集使用清单',
      blocks: [
        ComplianceListItem(
          title: '基础功能运行',
          rows: [
            ComplianceKVRow(label: '收集场景', value: '启动应用、浏览首页'),
            ComplianceKVRow(label: '信息类型', value: '设备型号、操作系统版本、设备标识符'),
            ComplianceKVRow(label: '使用目的', value: '保障服务稳定运行、故障排查'),
            ComplianceKVRow(label: '是否必需', value: '是'),
          ],
        ),
        ComplianceListItem(
          title: '账号注册与登录',
          rows: [
            ComplianceKVRow(label: '收集场景', value: '注册、登录'),
            ComplianceKVRow(label: '信息类型', value: '昵称、头像、联系方式'),
            ComplianceKVRow(label: '使用目的', value: '身份验证与账号管理'),
            ComplianceKVRow(label: '是否必需', value: '否，仅在主动填写时收集'),
          ],
        ),
        ComplianceListItem(
          title: '拍摄与作品管理',
          rows: [
            ComplianceKVRow(label: '收集场景', value: '拍摄照片、编辑作品'),
            ComplianceKVRow(label: '信息类型', value: '照片、作品数据与相关设置'),
            ComplianceKVRow(label: '使用目的', value: '提供拍摄与编辑功能'),
            ComplianceKVRow(label: '是否必需', value: '是'),
          ],
        ),
      ],
    ),
    ComplianceSection(
      title: '二、第三方 SDK 目录',
      blocks: [
        ComplianceParagraph('为实现以下功能，我们接入了第三方 SDK。相关 SDK 仅在您使用对应功能时收集必要信息：'),
        ComplianceListItem(
          title: '统计分析 SDK',
          rows: [
            ComplianceKVRow(label: 'SDK 名称', value: '基础统计服务'),
            ComplianceKVRow(label: '提供方', value: '本应用运营方自建'),
            ComplianceKVRow(label: '使用目的', value: '崩溃日志与使用统计'),
            ComplianceKVRow(label: '收集的信息', value: '设备型号、操作系统版本、崩溃日志'),
          ],
        ),
        ComplianceListItem(
          title: '图像处理能力',
          rows: [
            ComplianceKVRow(label: 'SDK 名称', value: '本地图像处理组件'),
            ComplianceKVRow(label: '提供方', value: '本应用内置组件'),
            ComplianceKVRow(label: '使用目的', value: '照片编辑、滤镜与模板合成'),
            ComplianceKVRow(label: '收集的信息', value: '不收集，均在设备本地完成'),
          ],
        ),
      ],
    ),
  ];
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/profile/compliance_content_test.dart`（cwd: `lumira_app_flutter/`）
Expected: 4 个测试全部 PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/profile/data/compliance_content.dart test/features/profile/compliance_content_test.dart
git commit -m "feat(profile): add compliance content data model and documents"
```

---

### Task 2: 通用合规正文页 ComplianceDocPage

**Files:**
- Create: `lumira_app_flutter/lib/features/profile/pages/compliance_doc_page.dart`
- Test: `lumira_app_flutter/test/features/profile/compliance_doc_page_test.dart`

**Interfaces:**
- Consumes（Task 1）: `ComplianceSection`、`ComplianceBlock`、`ComplianceParagraph`、`ComplianceKVRow`、`ComplianceListItem`
- Produces（Task 3 消费）: `class ComplianceDocPage extends ConsumerWidget { const ComplianceDocPage({required this.title, required this.updatedAt, required this.sections}); final String title; final String updatedAt; final List<ComplianceSection> sections; }`

- [ ] **Step 1: 写失败的 Widget 测试**

创建 `lumira_app_flutter/test/features/profile/compliance_doc_page_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/features/profile/data/compliance_content.dart';
import 'package:lumira_app_flutter/features/profile/pages/compliance_doc_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

Widget _wrap({required String title, required String updatedAt, required List<ComplianceSection> sections}) {
  final router = GoRouter(
    initialLocation: '/doc',
    routes: [
      GoRoute(
        path: '/doc',
        builder: (_, __) => ComplianceDocPage(
          title: title,
          updatedAt: updatedAt,
          sections: sections,
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      themeKeyProvider.overrideWith((r) => ThemeKey.warmWhite),
      uiStyleProvider.overrideWith((r) => UIStyle.neumorphic),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('renders nav title and updated time', (tester) async {
    await tester.pumpWidget(_wrap(
      title: '隐私政策',
      updatedAt: '2026-08-05',
      sections: ComplianceDocs.privacy,
    ));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(LumiraNav, '隐私政策'), findsOneWidget);
    expect(find.textContaining('2026-08-05'), findsWidgets);
  });

  testWidgets('renders section titles, paragraphs and key-value rows', (tester) async {
    await tester.pumpWidget(_wrap(
      title: '隐私政策',
      updatedAt: '2026-08-05',
      sections: ComplianceDocs.privacy,
    ));
    await tester.pumpAndSettle();

    expect(find.text('一、引言'), findsOneWidget);
    expect(find.text('二、我们收集的信息'), findsOneWidget);
    expect(find.text('三、信息的使用目的'), findsOneWidget);
  });

  testWidgets('renders list items with kv rows for sdk doc', (tester) async {
    await tester.pumpWidget(_wrap(
      title: '个人信息清单与第三方 SDK 目录',
      updatedAt: '2026-08-05',
      sections: ComplianceDocs.sdk,
    ));
    await tester.pumpAndSettle();

    expect(find.text('一、个人信息收集使用清单'), findsOneWidget);
    expect(find.text('基础功能运行'), findsOneWidget);
    expect(find.text('收集场景'), findsOneWidget);
    expect(find.text('启动应用、浏览首页'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/profile/compliance_doc_page_test.dart`（cwd: `lumira_app_flutter/`）
Expected: 编译失败，报 `URI target doesn't exist: compliance_doc_page.dart`

- [ ] **Step 3: 实现页面**

创建 `lumira_app_flutter/lib/features/profile/pages/compliance_doc_page.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/compliance_content.dart';

/// 合规文档通用正文页（用户协议 / 隐私政策 / 个人信息清单与SDK目录共用）
///
/// 视觉风格与「关于如画」页保持一致：LumiraNav + 渐变背景 + 滚动正文卡片。
class ComplianceDocPage extends ConsumerWidget {
  const ComplianceDocPage({
    super.key,
    required this.title,
    required this.updatedAt,
    required this.sections,
  });

  final String title;
  final String updatedAt;
  final List<ComplianceSection> sections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: title,
        transparent: true,
        leading: _BackButton(tokens: tokens),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 1.2,
            colors: [
              tokens.brandSubtle.withOpacity(0.35),
              tokens.canvas.withOpacity(0.0),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Noto Serif SC',
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '更新日期：$updatedAt',
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.textTertiary,
                  ),
                ),
                const SizedBox(height: 16),
                ...sections.map(
                  (section) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _SectionCard(section: section, tokens: tokens),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '© 2026 如画 Lumira',
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.textTertiary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          GoRouter.of(context).go(RouteNames.profileSettings);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.arrow_back_ios_new, size: 20, color: tokens.textPrimary),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.tokens});
  final ComplianceSection section;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...section.blocks.map((block) => _buildBlock(block)),
        ],
      ),
    );
  }

  Widget _buildBlock(ComplianceBlock block) {
    if (block is ComplianceParagraph) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          block.text,
          style: TextStyle(
            fontSize: 13,
            color: tokens.textSecondary,
            height: 1.6,
          ),
        ),
      );
    }
    if (block is ComplianceKVRow) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              block.label,
              style: TextStyle(
                fontSize: 13,
                color: tokens.textTertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                block.value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: tokens.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (block is ComplianceListItem) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.brand,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    block.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...block.rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 76,
                      child: Text(
                        row.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textTertiary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.value,
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/profile/compliance_doc_page_test.dart`（cwd: `lumira_app_flutter/`）
Expected: 3 个测试全部 PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/profile/pages/compliance_doc_page.dart test/features/profile/compliance_doc_page_test.dart
git commit -m "feat(profile): add reusable compliance doc page"
```

---

### Task 3: 设置页新增「合规与法律」分组与路由注册

**Files:**
- Modify: `lumira_app_flutter/lib/core/router/route_names.dart`
- Modify: `lumira_app_flutter/lib/app/router.dart`
- Modify: `lumira_app_flutter/lib/features/profile/pages/profile_settings_page.dart`
- Test: `lumira_app_flutter/test/features/profile/profile_settings_page_test.dart`

**Interfaces:**
- Consumes（Task 1/2）: `ComplianceDocs`、`ComplianceDocPage`
- Produces: 无（收尾任务，供端到端验证）

- [ ] **Step 1: 写失败的测试（更新设置页测试）**

在 `lumira_app_flutter/test/features/profile/profile_settings_page_test.dart` 中做 3 处修改：

1. 在 `setUp` 的 `routes` 列表（现有 `profileSettingsTheme` 路由之后）追加 3 个 stub 路由：

```dart
        GoRoute(
          path: RouteNames.profileComplianceAgreement,
          name: 'profileComplianceAgreement',
          builder: (_, __) => const Scaffold(body: Center(child: Text('COMPLIANCE_AGREEMENT'))),
        ),
        GoRoute(
          path: RouteNames.profileCompliancePrivacy,
          name: 'profileCompliancePrivacy',
          builder: (_, __) => const Scaffold(body: Center(child: Text('COMPLIANCE_PRIVACY'))),
        ),
        GoRoute(
          path: RouteNames.profileComplianceSdk,
          name: 'profileComplianceSdk',
          builder: (_, __) => const Scaffold(body: Center(child: Text('COMPLIANCE_SDK'))),
        ),
```

2. 在「renders all 4 setting groups」测试的 group title 断言处追加：

```dart
      expect(find.text('合规与法律'), findsOneWidget);
```

3. 在「关于组」断言之后追加 3 条新条目断言与 2 个跳转测试：

```dart
      // 合规与法律组
      expect(find.text('用户协议'), findsOneWidget);
      expect(find.text('隐私政策'), findsOneWidget);
      expect(find.text('个人信息清单与第三方SDK目录'), findsOneWidget);
```

```dart
    testWidgets('tapping 隐私政策 pushes compliance privacy page', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('隐私政策'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('COMPLIANCE_PRIVACY'), findsOneWidget);
    });

    testWidgets('tapping 用户协议 pushes compliance agreement page', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('用户协议'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('COMPLIANCE_AGREEMENT'), findsOneWidget);
    });
```

（注意：上述 3 个新条目断言加入已有「renders all 4 setting groups」测试体的「关于组」断言之后；若屏幕高度不够导致条目不可见，可保持 `setLargeViewport` 的 800x2400 视口，该测试已设置。）

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/profile/profile_settings_page_test.dart`（cwd: `lumira_app_flutter/`）
Expected: 编译失败（`RouteNames.profileComplianceAgreement` 等常量不存在）

- [ ] **Step 3: 新增路由常量**

在 `lumira_app_flutter/lib/core/router/route_names.dart` 的 `profileAbout` 常量（第 49 行）之后追加：

```dart
  static const String profileComplianceAgreement = '/profile/settings/agreement';
  static const String profileCompliancePrivacy = '/profile/settings/privacy';
  static const String profileComplianceSdk = '/profile/settings/sdk';
```

- [ ] **Step 4: 注册 GoRoute**

在 `lumira_app_flutter/lib/app/router.dart` 的 `profileAbout` 路由（约第 375 行）之后追加 3 个 `GoRoute`：

```dart
      GoRoute(
        path: RouteNames.profileComplianceAgreement,
        name: 'profileComplianceAgreement',
        builder: (context, state) => const ComplianceDocPage(
          title: '用户协议',
          updatedAt: ComplianceDocs.agreementUpdatedAt,
          sections: ComplianceDocs.agreement,
        ),
      ),
      GoRoute(
        path: RouteNames.profileCompliancePrivacy,
        name: 'profileCompliancePrivacy',
        builder: (context, state) => const ComplianceDocPage(
          title: '隐私政策',
          updatedAt: ComplianceDocs.privacyUpdatedAt,
          sections: ComplianceDocs.privacy,
        ),
      ),
      GoRoute(
        path: RouteNames.profileComplianceSdk,
        name: 'profileComplianceSdk',
        builder: (context, state) => const ComplianceDocPage(
          title: '个人信息清单与第三方SDK目录',
          updatedAt: ComplianceDocs.sdkUpdatedAt,
          sections: ComplianceDocs.sdk,
        ),
      ),
```

并检查 `router.dart` 头部 import，补充：

```dart
import 'package:lumira_app_flutter/features/profile/data/compliance_content.dart';
import 'package:lumira_app_flutter/features/profile/pages/compliance_doc_page.dart';
```

（按现有 import 排序位置插入。）

- [ ] **Step 5: 设置页新增分组**

在 `lumira_app_flutter/lib/features/profile/pages/profile_settings_page.dart` 的「关于」分组 `NeuCard` 之后、`_VersionFooter` 之前（约第 345 行 `const SizedBox(height: 24),` 处，改为在其前插入新分组）追加：

```dart
                const SizedBox(height: 20),
                _GroupTitle(text: '合规与法律', tokens: tokens),
                const SizedBox(height: 8),
                NeuCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SettingItem(
                        icon: Icons.description_outlined,
                        label: '用户协议',
                        onTap: () => GoRouter.of(context).push(RouteNames.profileComplianceAgreement),
                        tokens: tokens,
                      ),
                      _SettingItem(
                        icon: Icons.privacy_tip_outlined,
                        label: '隐私政策',
                        onTap: () => GoRouter.of(context).push(RouteNames.profileCompliancePrivacy),
                        tokens: tokens,
                      ),
                      _SettingItem(
                        icon: Icons.list_alt_outlined,
                        label: '个人信息清单与第三方SDK目录',
                        onTap: () => GoRouter.of(context).push(RouteNames.profileComplianceSdk),
                        tokens: tokens,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
```

（原「关于」分组末尾 `_SettingItem` 的 `isLast: true` 保持不变；新分组自身最后一个条目设 `isLast: true`。）

- [ ] **Step 6: 运行测试确认通过**

Run: `flutter test test/features/profile/profile_settings_page_test.dart`（cwd: `lumira_app_flutter/`）
Expected: 全部测试 PASS

- [ ] **Step 7: 提交**

```bash
git add lib/core/router/route_names.dart lib/app/router.dart lib/features/profile/pages/profile_settings_page.dart test/features/profile/profile_settings_page_test.dart
git commit -m "feat(profile): add compliance section and routes to settings page"
```

---

### Task 4: 全量验证

**Files:**
- 无新增/修改（仅运行验证）

**Interfaces:**
- 无

- [ ] **Step 1: 运行静态分析**

Run: `flutter analyze`（cwd: `lumira_app_flutter/`）
Expected: No issues found（无新增 issue；若有既有 warning，确认本次改动未引入新问题）

- [ ] **Step 2: 运行相关测试套件**

Run: `flutter test test/features/profile`（cwd: `lumira_app_flutter/`）
Expected: 所有 profile 相关测试全部 PASS（含 compliance_content_test、compliance_doc_page_test、profile_settings_page_test）

- [ ] **Step 3: 确认 git 状态干净**

Run: `git status`（cwd: `d:\app\projects\photo_post`）
Expected: 工作区干净（无未提交改动）
