import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/router/route_names.dart';
import '../../../core/services/file_picker_service.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/safe_share.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../../shared/widgets/poster/template_import_poster.dart';
import '../models/share_token.dart';
import '../services/template_share_service.dart';

class ExportDetailPage extends ConsumerStatefulWidget {
  const ExportDetailPage({
    super.key,
    required this.filePath,
    required this.templateName,
    required this.usePptpl,
    this.shareLink,
    this.shareCode,
  });

  final String filePath;
  final String templateName;
  final bool usePptpl;
  final String? shareLink;
  final String? shareCode;

  @override
  ConsumerState<ExportDetailPage> createState() => _ExportDetailPageState();
}

class _ExportDetailPageState extends ConsumerState<ExportDetailPage> {
  File? _file;
  String? _contentPreview;
  String? _rawContent;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        setState(() {
          _error = '文件不存在';
          _isLoading = false;
        });
        return;
      }

      final content = await file.readAsString();
      final preview = _generatePreview(content);

      setState(() {
        _file = file;
        _contentPreview = preview;
        _rawContent = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载文件失败: $e';
        _isLoading = false;
      });
    }
  }

  String _generatePreview(String content) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      final buffer = StringBuffer();

      buffer.writeln('格式: ${json['format']?.toString().toUpperCase() ?? '未知'}');
      buffer.writeln('版本: ${json['version'] ?? '未知'}');
      buffer.writeln('');

      final meta = json['meta'] as Map<String, dynamic>?;
      if (meta != null) {
        buffer.writeln('=== 基本信息 ===');
        buffer.writeln('名称: ${meta['name'] ?? '未命名'}');
        buffer.writeln('分类: ${meta['category'] ?? '未分类'}');
        
        final tags = meta['tags'] as List<dynamic>?;
        if (tags != null && tags.isNotEmpty) {
          buffer.writeln('标签: ${tags.join(', ')}');
        }

        final price = meta['price'];
        if (price != null) {
          buffer.writeln('价格: ${price == 0 ? '免费' : '$price 积分'}');
        }
      }

      if (widget.usePptpl) {
        final camera = json['camera'] as Map<String, dynamic>?;
        if (camera != null) {
          buffer.writeln('');
          buffer.writeln('=== 相机参数 ===');
          final ev = camera['exposureCompensation'];
          if (ev != null) buffer.writeln('曝光补偿: $ev');
          
          final iso = camera['iso'];
          if (iso != null) buffer.writeln('ISO: $iso');
          
          final shutter = camera['shutterSpeed'];
          if (shutter != null) buffer.writeln('快门速度: ${shutter}s');
        }

        final composition = json['composition'] as Map<String, dynamic>?;
        if (composition != null) {
          buffer.writeln('');
          buffer.writeln('=== 构图设置 ===');
          final overlayType = composition['overlayType'];
          if (overlayType != null) buffer.writeln('叠加类型: $overlayType');
        }
      }

      return buffer.toString();
    } catch (e) {
      return '无法解析文件内容';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _saveToFileManager() async {
    if (_file == null) return;

    try {
      // OHOS 无目录选择 API（DocumentViewPicker 只能选文件），改用系统「保存文件」对话框
      if (Platform.operatingSystem == 'ohos') {
        final savedPath = await FilePickerService.saveFile(
          sourceFilePath: _file!.path,
          fileName: _file!.path.split('/').last,
        );
        if (savedPath == null || !mounted) return;
        if (!mounted) return;
        LumiraToast.show(context, '已保存');
        return;
      }

      final dirPath = await FilePickerService.pickDirectory();
      if (dirPath == null || !mounted) return;

      LumiraToast.show(context, '正在保存...');

      final fileName = _file!.path.split('/').last;
      final targetPath = '$dirPath/$fileName';
      final targetFile = File(targetPath);

      await targetFile.writeAsBytes(await _file!.readAsBytes());

      if (!mounted) return;
      LumiraToast.show(context, '已保存到 $dirPath');
    } catch (e) {
      if (!mounted) return;
      LumiraToast.show(context, '保存失败: $e');
    }
  }

  Future<void> _shareFile() async {
    if (_file == null) return;

    try {
      await SafeShare.shareXFiles(
        [XFile(_file!.path)],
        subject: '如画模板：${widget.templateName}',
        text: '我分享了一个如画摄影模板「${widget.templateName}」，用如画 App 导入即可使用。',
      );
    } catch (e) {
      if (!mounted) return;
      LumiraToast.show(context, '分享失败: $e');
    }
  }

  Future<void> _copyText(String text, String toast) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    LumiraToast.show(context, toast);
  }

  Future<void> _shareAsText() async {
    final link = widget.shareLink ?? '';
    final code = widget.shareCode ?? '';
    await SafeShare.share(
      '我用如画分享了模板「${widget.templateName}」\n链接：$link\n分享码：$code',
      subject: '如画模板：${widget.templateName}',
    );
  }

  /// 弹出分享有效期选择底部面板，生成自定义模板分享二维码。
  Future<void> _generateShareQr() async {
    final content = _rawContent;
    if (content == null) {
      if (mounted) LumiraToast.show(context, '暂无可分享内容');
      return;
    }

    TemplateShareService service;
    try {
      service = await ref.read(templateShareServiceProvider.future);
    } catch (_) {
      if (mounted) LumiraToast.show(context, '分享服务不可用');
      return;
    }
    if (!mounted) return;

    await showLumiraBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ShareQrSheet(
        service: service,
        rawContent: content,
        templateName: widget.templateName,
      ),
    );
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.templates);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _BackgroundDecoration(tokens: tokens),
          SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                LumiraNav(
                  title: '导出详情',
                  transparent: true,
                  leading: _BackButton(tokens: tokens, onTap: _back),
                ),
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: LumiraProgress.circular(),
                        )
                      : _error != null
                          ? Center(
                              child: Text(
                                _error!,
                                style: TextStyle(color: tokens.textSecondary),
                              ),
                            )
                          : _buildContent(tokens),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeTokens tokens) {
    final fileName = _file!.path.split('/').last;
    final fileSize = _formatFileSize(_file!.lengthSync());
    final format = widget.usePptpl ? '.pptpl' : '.lumira';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: tokens.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: tokens.divider, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description_outlined, color: tokens.brand, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.templateName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '已导出为 $format 格式',
                              style: TextStyle(
                                fontSize: 13,
                                color: tokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(tokens: tokens, label: '文件名', value: fileName),
                  const SizedBox(height: 8),
                  _InfoRow(tokens: tokens, label: '文件大小', value: fileSize),
                  const SizedBox(height: 8),
                  _InfoRow(
                    tokens: tokens,
                    label: '保存位置',
                    value: _file!.parent.path,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            color: tokens.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: tokens.divider, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.preview_outlined, color: tokens.brand, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '内容预览',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tokens.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _contentPreview ?? '无内容',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: tokens.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          LumiraButton(
            variant: ButtonVariant.primary,
            onPressed: _saveToFileManager,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.save_outlined, size: 20),
                SizedBox(width: 8),
                Text('保存到文件管理器'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LumiraButton(
            variant: ButtonVariant.secondary,
            onPressed: _shareFile,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.share_outlined, size: 20),
                SizedBox(width: 8),
                Text('分享文件'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LumiraButton(
            variant: ButtonVariant.secondary,
            onPressed: _generateShareQr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.qr_code_2_outlined, size: 20),
                SizedBox(width: 8),
                Text('生成分享二维码'),
              ],
            ),
          ),
          if (widget.shareLink != null) ...[
            const SizedBox(height: 12),
            LumiraButton(
              variant: ButtonVariant.secondary,
              onPressed: () => _copyText(widget.shareLink!, '分享链接已复制'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.link_outlined, size: 20),
                  SizedBox(width: 8),
                  Text('复制分享链接'),
                ],
              ),
            ),
          ],
          if (widget.shareCode != null) ...[
            const SizedBox(height: 12),
            LumiraButton(
              variant: ButtonVariant.secondary,
              onPressed: () => _copyText(widget.shareCode!, '分享码已复制'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.qr_code_2_outlined, size: 20),
                  SizedBox(width: 8),
                  Text('复制分享码'),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          LumiraButton(
            variant: ButtonVariant.secondary,
            onPressed: _shareAsText,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.chat_bubble_outline, size: 20),
                SizedBox(width: 8),
                Text('以文本分享'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 可选的分享有效期。
class _TtlOption {
  const _TtlOption(this.label, this.seconds);

  final String label;
  final int seconds;
}

const _shareTtlOptions = <_TtlOption>[
  _TtlOption('15分钟', 900),
  _TtlOption('1小时', 3600),
  _TtlOption('6小时', 21600),
  _TtlOption('12小时', 43200),
];

enum _SharePhase { select, loading, result }

/// 生成分享二维码的底部面板：有效期选择 → loading → 结果视图。
class _ShareQrSheet extends ConsumerStatefulWidget {
  const _ShareQrSheet({
    required this.service,
    required this.rawContent,
    required this.templateName,
  });

  final TemplateShareService service;
  final String rawContent;
  final String templateName;

  @override
  ConsumerState<_ShareQrSheet> createState() => _ShareQrSheetState();
}

class _ShareQrSheetState extends ConsumerState<_ShareQrSheet> {
  _SharePhase _phase = _SharePhase.select;
  ShareToken? _shareToken;
  String? _error;

  /// 导出 payload 解析结果（用于取封面 / 分类）。
  Map<String, dynamic>? _payload;
  ImportPosterCover? _cover;

  @override
  void initState() {
    super.initState();
    try {
      _payload = jsonDecode(widget.rawContent) as Map<String, dynamic>;
    } catch (_) {
      _payload = null;
    }
    _resolveCover();
  }

  Future<void> _resolveCover() async {
    final payload = _payload;
    if (payload == null) return;
    final cover = await resolveImportPosterCover(payload);
    if (!mounted) return;
    setState(() {
      _cover = cover;
    });
  }

  String get _category {
    final meta = _payload?['meta'];
    if (meta is Map<String, dynamic>) {
      final cat = meta['category'];
      if (cat is String) return cat;
    }
    return '';
  }

  Future<void> _createShare(int ttl) async {
    setState(() {
      _phase = _SharePhase.loading;
      _error = null;
    });
    try {
      final result =
          await widget.service.sharePayloadJson(widget.rawContent, ttl);
      if (!mounted) return;
      setState(() {
        _shareToken = result;
        _phase = _SharePhase.result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _SharePhase.select;
        _error = '生成二维码失败: $e';
      });
      LumiraToast.show(context, '生成二维码失败: $e');
    }
  }

  void _copyLink(String link) {
    Clipboard.setData(ClipboardData(text: link));
    LumiraToast.show(context, '分享链接已复制');
  }

  Future<void> _revoke() async {
    final token = _shareToken?.token;
    if (token == null) return;
    setState(() {
      _phase = _SharePhase.loading;
    });
    try {
      await widget.service.revokeShare(token);
      if (!mounted) return;
      final overlay = Overlay.of(context, rootOverlay: true);
      LumiraToast.showWithOverlay(overlay, '已撤回分享');
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _SharePhase.result;
        _error = '撤回分享失败: $e';
      });
      LumiraToast.show(context, '撤回分享失败: $e');
    }
  }

  String _formatExpiry(int expiresAt) {
    final dt = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
    String two(int n) => n.toString().padLeft(2, '0');
    final hm = '${two(dt.hour)}:${two(dt.minute)}';
    final now = DateTime.now();
    final sameDay = dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;
    if (sameDay) return '有效期至 $hm';
    return '有效期至 ${two(dt.month)}-${two(dt.day)} $hm';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);

    final Widget body;
    if (_phase == _SharePhase.loading) {
      body = Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 24),
        child: Center(
          child: LumiraProgress.circular(),
        ),
      );
    } else if (_phase == _SharePhase.result) {
      body = _buildResult(tokens);
    } else {
      body = _buildSelect(tokens);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '生成分享二维码',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        body,
      ],
    );
  }

  Widget _buildSelect(ThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '请选择分享链接有效期（超期后链接与二维码自动失效）：',
          style: TextStyle(fontSize: 13, color: tokens.textSecondary),
        ),
        const SizedBox(height: 16),
        for (final option in _shareTtlOptions) ...[
          LumiraButton(
            variant: ButtonVariant.secondary,
            onPressed: () => _createShare(option.seconds),
            child: Text(option.label),
          ),
          const SizedBox(height: 8),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(fontSize: 13, color: tokens.danger),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          '最长有效期 12 小时，生成后链接仅限装如画 App 的设备扫码导入。',
          style: TextStyle(fontSize: 12, color: tokens.textTertiary),
        ),
      ],
    );
  }

  Widget _buildResult(ThemeTokens tokens) {
    final token = _shareToken;
    if (token == null) return const SizedBox.shrink();
    final link = TemplateShareService.buildQrText(token.token);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // V3 画幅自适应分享海报（二维码内置于海报，按封面比例切换五种排版）
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: TemplateImportPoster(
                cover: _cover,
                templateName: widget.templateName,
                category: _category,
                qrData: link,
                expiryText: _formatExpiry(token.expiresAt),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.templateName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatExpiry(token.expiresAt),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: tokens.textSecondary),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              link,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: tokens.textSecondary,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(fontSize: 13, color: tokens.danger),
            ),
          ],
          const SizedBox(height: 16),
          LumiraButton(
            variant: ButtonVariant.secondary,
            onPressed: () => _copyLink(link),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.link_outlined, size: 20),
                SizedBox(width: 8),
                Text('复制链接'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LumiraButton(
            variant: ButtonVariant.danger,
            onPressed: _revoke,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.close, size: 20),
                SizedBox(width: 8),
                Text('撤回分享'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundDecoration extends StatelessWidget {
  const _BackgroundDecoration({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.6, -0.8),
              radius: 1.4,
              colors: [
                tokens.brandSubtle.withOpacity(0.45),
                tokens.canvas.withOpacity(0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tokens, required this.onTap});
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.arrow_back_ios_new,
          size: 20,
          color: tokens.textPrimary,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.tokens,
    required this.label,
    required this.value,
  });

  final ThemeTokens tokens;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: tokens.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: tokens.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
