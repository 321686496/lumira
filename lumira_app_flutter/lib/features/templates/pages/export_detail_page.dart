import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
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

class ExportDetailPage extends ConsumerStatefulWidget {
  const ExportDetailPage({
    super.key,
    required this.filePath,
    required this.templateName,
    required this.usePptpl,
  });

  final String filePath;
  final String templateName;
  final bool usePptpl;

  @override
  ConsumerState<ExportDetailPage> createState() => _ExportDetailPageState();
}

class _ExportDetailPageState extends ConsumerState<ExportDetailPage> {
  File? _file;
  String? _contentPreview;
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
          buffer.writeln('价格: ${price == 0 ? '免费' : '¥$price'}');
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
              children: [
                Icon(Icons.save_outlined, size: 20),
                const SizedBox(width: 8),
                const Text('保存到文件管理器'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LumiraButton(
            variant: ButtonVariant.secondary,
            onPressed: _shareFile,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.share_outlined, size: 20),
                const SizedBox(width: 8),
                const Text('分享文件'),
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
