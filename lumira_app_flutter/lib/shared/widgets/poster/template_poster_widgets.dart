import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/db/dao/templates_dao.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../features/capture/domain/photo_template.dart';
import '../../../features/templates/services/template_share_code.dart';

/// 共享海报 UI 组件：照片详情「模板海报分享」与模板详情「模板分享海报」共用。
///
/// 二维码统一生成「离线分享链接」（`lumira://tpl/{base64}`，含完整模板 JSON），
/// 可被 App 首页「扫一扫」识别回详情页 / 导入。样式跟随当前 UI 风格 + 主题 tokens。

/// 海报二维码内容。
String buildTemplatePosterQrData(TemplateRecord record) =>
    TemplateShareCode.buildShareLink(record, usePptpl: true);

/// 用户未填写分享内容时，按模板动态生成的系统默认文案。
String buildAutoShareText(TemplateRecord record) {
  final name = record.name.trim();
  if (name.isEmpty) return '我拍了一张质感的照片，你也快来 LUMIRA 试试吧！';
  return '我用「$name」模板拍出了超满意的照片，质感绝了，你也来试试吧！';
}

/// 渲染模板封面图（兼容 base64 data / 网络 url / 本地资源 / 资源文件）。
Widget templateCoverImage(
  TemplateImage img, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  required ThemeTokens tokens,
}) {
  final data = img.data;
  if (data != null && data.isNotEmpty) {
    try {
      final bytes = base64Decode(
        data.contains(',')
            ? data.substring(data.indexOf(',') + 1)
            : data,
      );
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _PosterImagePlaceholder(tokens: tokens),
      );
    } catch (_) {}
  }

  final url = img.url;
  if (url.isNotEmpty && url.startsWith('http')) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => _PosterImagePlaceholder(tokens: tokens),
    );
  }
  if (url.startsWith('assets/')) {
    return Image.asset(
      url,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => _PosterImagePlaceholder(tokens: tokens),
    );
  }
  return _PosterImagePlaceholder(tokens: tokens);
}

/// 海报内模板封面所需的封面 [TemplateImage]（record.images[0]，缺省用 cover/coverData 构造）。
TemplateImage templateRecordCover(TemplateRecord record) {
  final images = record.images;
  if (images != null && images.isNotEmpty) return images.first;
  return TemplateImage(url: record.cover, data: record.coverData);
}

/// 照片详情「模板照片海报」正文。
///
/// 上：照片；中：分享文案；下：模板信息 + 模板二维码 + 品牌字。
class TemplatePhotoPosterContent extends ConsumerWidget {
  const TemplatePhotoPosterContent({
    super.key,
    required this.photoPath,
    required this.shareText,
    required this.template,
  });

  /// 照片本地文件绝对路径。
  final String photoPath;
  final String shareText;
  final TemplateRecord template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tokens.brandSubtle, tokens.surface],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部：照片
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(photoPath),
              width: double.infinity,
              height: 360,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _PosterImagePlaceholder(tokens: tokens, height: 360),
            ),
          ),
          const SizedBox(height: 16),
          // 分享文案
          Text(
            shareText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: tokens.divider),
          const SizedBox(height: 14),
          // 模板信息
          Text(
            template.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            template.category,
            style: TextStyle(
              fontSize: 12,
              color: tokens.brandText,
            ),
          ),
          const SizedBox(height: 16),
          // 模板二维码
          QrImageView(
            data: buildTemplatePosterQrData(template),
            version: QrVersions.auto,
            size: 140,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: tokens.textPrimary,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '长按识别二维码 · 查看模板',
            style: TextStyle(fontSize: 11, color: tokens.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// 模板详情「模板分享海报」正文。
///
/// 上：模板封面；下：模板名/分类 + 模板二维码 + 品牌字。
class TemplateSharePosterContent extends ConsumerWidget {
  const TemplateSharePosterContent({
    super.key,
    required this.template,
  });

  final TemplateRecord template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tokens.brandSubtle, tokens.surface],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部：模板封面
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: templateCoverImage(
              templateRecordCover(template),
              width: double.infinity,
              height: 340,
              fit: BoxFit.cover,
              tokens: tokens,
            ),
          ),
          const SizedBox(height: 16),
          // 模板信息
          Text(
            template.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            template.category,
            style: TextStyle(fontSize: 12, color: tokens.brandText),
          ),
          const SizedBox(height: 16),
          // 模板二维码
          QrImageView(
            data: buildTemplatePosterQrData(template),
            version: QrVersions.auto,
            size: 140,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: tokens.textPrimary,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '长按识别二维码 · 查看模板',
            style: TextStyle(fontSize: 11, color: tokens.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// 封面/图片缺失时的品牌渐变占位。
class _PosterImagePlaceholder extends StatelessWidget {
  const _PosterImagePlaceholder({required this.tokens, this.height});

  final ThemeTokens tokens;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.brandSubtle, t.surface],
        ),
      ),
      child: Center(
        child: Icon(Icons.photo_outlined, size: 40, color: t.brand),
      ),
    );
  }
}