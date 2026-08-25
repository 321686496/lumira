import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../../core/db/dao/templates_dao.dart';
import '../../../core/network/api_client.dart';
import '../models/share_token.dart';
import 'template_exporter.dart';

/// 自定义模板「二维码分享」服务。
///
/// - 分享方向：`shareTemplate` 导出 payload 上传后端（Redis TTL 存储）拿 token，
///   接收方 `fetchShare` 按 token 拉取、`revokeShare` 撤回。
/// - 二维码内容：`lumira://imp/{token}`（`buildQrText`），兼容 `https://lumira.app/imp/{token}`。
/// - 图片（封面/剪影）内嵌 base64 data URL，且每张解码字节 ≤1MB
///   （内部对超出限值的 data URL 用 package:image 压缩，缩放 + JPEG，不过度损失画质）。
/// - payload 总大小上限由后端强制（3MB，此处每张图片再限 1MB）。
class TemplateShareService {
  TemplateShareService(this._api);

  final ApiClient _api;

  /// 单张图片解码后字节上限（1MB）。
  static const int maxImageBytes = 1 * 1024 * 1024;

  /// 二维码内容。私钥仅存放 token，接收端凭 token 拉取 payload。
  static String buildQrText(String token) => 'lumira://imp/$token';

  /// 解析扫码 / 粘贴文本，返回可分派的 token 或离线/无效标记。
  ///
  /// - `lumira://imp/{token}` / `https://lumira.app/imp/{token}` → 返回该 token
  /// - `lumira://tpl/{base64}` / `https://lumira.app/tpl?name=...`（离线链接）→ 返回 null
  /// - 其它 → 返回空串 `''`（表示无效内容，需提示重试）
  static String? parseTokenFromScannedText(String text) {
    final t = text.trim();
    const impPrefixes = ['lumira://imp/', 'https://lumira.app/imp/'];
    for (final prefix in impPrefixes) {
      if (t.startsWith(prefix)) {
        final token = t.substring(prefix.length);
        return token.isEmpty ? '' : token;
      }
    }
    if (t.startsWith('lumira://tpl/') ||
        t.startsWith('https://lumira.app/tpl?')) {
      // 离线分享链接（完整 JSON 内嵌在链接中），走原有离线导入管线。
      return null;
    }
    return '';
  }

  /// 直接分享一份 payload JSON 字符串，返回 share token。
  ///
  /// 内部会先扫描 payload 里的 `data:image/...;base64,` 图片做限长压缩
  /// （复用 [TemplateShareService.compressImageToLimit]，>1MB 压缩到 ≤1MB），
  /// 再 POST `/templates/share`。供导出详情页把已读出的 `.pptpl` 原始 JSON
  /// 直接分享，无需依赖 [TemplateRecord]。
  Future<ShareToken> sharePayloadJson(
    String payload,
    int expiresInSeconds,
  ) async {
    final compressed = await _compressEmbeddedImages(payload);
    return _api.post(
      '/templates/share',
      body: <String, dynamic>{
        'payload': compressed,
        'expiresInSeconds': expiresInSeconds,
      },
      fromJson: (j) => ShareToken.fromJson(j as Map<String, dynamic>),
    );
  }

  /// 创建分享：导出 payload 上传，返回 share token。
  Future<ShareToken> shareTemplate(TemplateRecord record, int expiresInSeconds) async {
    final payload = await _buildPayload(record);
    return sharePayloadJson(payload, expiresInSeconds);
  }

  /// 拉取分享内容，返回 `{payload, expiresAt}`。
  Future<Map<String, dynamic>> fetchShare(String token) async {
    return _api.get(
      '/templates/share/$token',
      fromJson: (j) => j == null || j is! Map
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(j),
    );
  }

  /// 撤回分享（仅创建者设备可撤回，否则后端返回 403）。
  Future<void> revokeShare(String token) async {
    await _api.delete<void>(
      '/templates/share/$token',
      fromJson: (_) {},
    );
  }

  /// 构建共享 payload：导出 .pptpl JSON 字符串（图片限长压缩由 sharePayloadJson 统一负责）。
  Future<String> _buildPayload(TemplateRecord record) async {
    final withCover = await TemplateExporter.embedCoverData(record);
    return TemplateExporter.exportToPptpl(withCover);
  }

  /// 将字节压缩到 [maxBytes] 以内（仅当超过时）。
  ///
  /// 策略：优先降 JPEG 质量，仍超限则按比例缩放尺寸；双重兜底确保收敛，
  /// 且避免把质量压得过低（不过度损失画质）。
  static Future<Uint8List> compressImageToLimit(
    Uint8List bytes,
    int maxBytes,
  ) async {
    if (bytes.length <= maxBytes) return bytes;
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    final maxW = image.width;
    final maxH = image.height;
    var scale = 1.0;
    var quality = 88;
    var out = bytes;
    while (out.length > maxBytes && scale > 0.05) {
      final w = (maxW * scale).round().clamp(1, maxW);
      final h = (maxH * scale).round().clamp(1, maxH);
      final resized = img.copyResize(image, width: w, height: h);
      out = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      if (out.length > maxBytes) {
        if (quality > 60) {
          quality -= 10;
        } else {
          quality = 88;
          scale *= 0.8;
        }
      }
    }
    return out;
  }

  /// 扫描 payload JSON 中的 `data:image/...;base64,`，对解码后 >1MB 的图片压缩替换。
  static Future<String> _compressEmbeddedImages(String json) async {
    final matches = _dataUrlRe.allMatches(json).toList();
    if (matches.isEmpty) return json;
    final buffer = StringBuffer();
    var last = 0;
    for (final m in matches) {
      buffer.write(json.substring(last, m.start));
      buffer.write(await _maybeCompress(m.group(0)!, m.group(1)!));
      last = m.end;
    }
    buffer.write(json.substring(last));
    return buffer.toString();
  }

  static final RegExp _dataUrlRe =
      RegExp(r'"data:image/[A-Za-z0-9.+\-]+;base64,([^"]+)"');

  /// 单条 data URL：未超限则原样返回，超限则压缩并用 JPEG 重新编码替换。
  static Future<String> _maybeCompress(String full, String base64Payload) async {
    Uint8List bytes;
    try {
      bytes = base64Decode(base64Payload);
    } catch (_) {
      return full;
    }
    if (bytes.length <= maxImageBytes) return full;
    final compressed = await compressImageToLimit(bytes, maxImageBytes);
    const marker = ';base64,';
    final header = full.substring(0, full.indexOf(marker) + marker.length);
    return '$header${base64Encode(compressed)}"';
  }
}

/// 全局 TemplateShareService Provider（依赖 apiClientProvider，故为 FutureProvider）。
final templateShareServiceProvider = FutureProvider<TemplateShareService>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return TemplateShareService(api);
});