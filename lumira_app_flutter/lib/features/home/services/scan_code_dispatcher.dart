import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../shared/widgets/lumira/lumira.dart' as lumira;
import '../../templates/services/template_share_service.dart';
import '../../templates/widgets/template_import_sheet.dart';

/// 扫码识别结果类型。
enum ScanCodeType {
  /// `LUMIRA-{分类}-{名称}` 模板分享码
  templateShareCode,

  /// `lumira://tpl/...` / `https://lumira.app/tpl?...` 模板离线链接
  templateOfflineLink,

  /// `lumira://imp/{token}` / `https://lumira.app/imp/{token}` 模板在线 token
  templateOnlineToken,

  /// `...account-recover?...secret=xxx` 恢复码
  recoveryCode,

  /// 6 位安全字母表邀请码
  inviteCode,

  /// 无法识别
  unknown,
}

/// 分类结果：类型 + 原始文本 + 附加数据（token / secret / 邀请码等）。
class ScanCodeResult {
  const ScanCodeResult(this.type, this.rawText, {this.payload});

  final ScanCodeType type;
  final String rawText;
  final String? payload;
}

/// 首页「扫一扫」分发器：按格式分类扫描文本并执行对应操作。
///
/// 分类规则（按顺序匹配）与 `docs/specs/2026-08-31-home-scan-qr-design.md` 一致：
/// 1. LUMIRA- 前缀 → 模板分享码
/// 2. 含 lumira://tpl / https://lumira.app/tpl → 模板离线链接
/// 3. 含 lumira://imp / https://lumira.app/imp → 模板在线 token
/// 4. 含 account-recover / secret= → 恢复码
/// 5. 6 位安全字母表（排除 O/0/I/1）→ 邀请码
/// 6. 其它 → 未知
class ScanCodeDispatcher {
  ScanCodeDispatcher._();

  /// 邀请码字母表：与后端 `invite-code.generator.ts` 一致（排除易混淆 O/0/I/1）。
  static final RegExp _inviteRe = RegExp(r'^[A-HJ-NP-Z2-9]{6}$', caseSensitive: false);

  static ScanCodeResult classify(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return const ScanCodeResult(ScanCodeType.unknown, '');
    }

    // 1. 模板分享码
    if (text.startsWith('LUMIRA-')) {
      return ScanCodeResult(ScanCodeType.templateShareCode, text, payload: text);
    }

    // 2. 模板离线链接
    if (text.contains('lumira://tpl') || text.contains('https://lumira.app/tpl')) {
      return ScanCodeResult(ScanCodeType.templateOfflineLink, text, payload: text);
    }

    // 3. 模板在线 token
    if (text.contains('lumira://imp') || text.contains('https://lumira.app/imp')) {
      final token = TemplateShareService.parseTokenFromScannedText(text);
      return ScanCodeResult(ScanCodeType.templateOnlineToken, text, payload: token);
    }

    // 4. 恢复码
    if (text.contains('account-recover') || text.contains('secret=')) {
      return ScanCodeResult(
        ScanCodeType.recoveryCode,
        text,
        payload: _extractSecret(text) ?? text,
      );
    }

    // 5. 邀请码
    if (_inviteRe.hasMatch(text)) {
      return ScanCodeResult(
        ScanCodeType.inviteCode,
        text,
        payload: text.toUpperCase(),
      );
    }

    // 6. 未知
    return ScanCodeResult(ScanCodeType.unknown, text);
  }

  /// 从恢复码文本提取 secret：兼容 `scheme://...account-recover?...&secret=xxx`
  /// 与裸 `secret=xxx` 两种形式；提取失败返回 null。
  static String? _extractSecret(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri != null) {
      final s = uri.queryParameters['secret'];
      if (s != null && s.isNotEmpty) return s;
    }
    final m = RegExp(r'[?&]secret=([^&#]+)').firstMatch(raw);
    if (m != null) return Uri.decodeComponent(m.group(1)!);
    return null;
  }

  /// 执行分类结果对应的操作。
  ///
  /// - 模板三类码：复用 [TemplateImportSheet.importScannedText] 导入（与「扫码导入」一致）。
  /// - 恢复码 / 邀请码：跳转对应页面并预填，由用户确认后触发（不直接执行，避免误操作）。
  /// - 未知：Toast 提示。
  static Future<void> execute(
    BuildContext context,
    WidgetRef ref,
    ScanCodeResult result,
  ) async {
    switch (result.type) {
      case ScanCodeType.templateShareCode:
      case ScanCodeType.templateOfflineLink:
      case ScanCodeType.templateOnlineToken:
        await TemplateImportSheet.importScannedText(
          context,
          ref,
          result.rawText,
        );
        break;
      case ScanCodeType.recoveryCode:
        GoRouter.of(context).push(RouteNames.build(
          RouteNames.accountRecover,
          {RouteNames.paramSecret: result.payload ?? ''},
        ));
        break;
      case ScanCodeType.inviteCode:
        GoRouter.of(context).push(RouteNames.build(
          RouteNames.profileInvite,
          {RouteNames.paramInviteCode: result.payload ?? ''},
        ));
        break;
      case ScanCodeType.unknown:
        lumira.LumiraToast.show(context, '无法识别的码');
        break;
    }
  }
}
