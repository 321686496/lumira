import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/cache_utils.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';

/// 缓存详情页
///
/// 展示应用各类缓存分布（图片磁盘 / 图片内存 / API 离线数据），
/// 支持单独清理某项，或一键全部清理。
/// 清理仅涉及缓存，不影响照片、模板、设置等用户数据。
class ProfileSettingsCachePage extends ConsumerStatefulWidget {
  const ProfileSettingsCachePage({super.key});

  @override
  ConsumerState<ProfileSettingsCachePage> createState() =>
      _ProfileSettingsCachePageState();
}

class _ProfileSettingsCachePageState
    extends ConsumerState<ProfileSettingsCachePage> {
  int _diskBytes = 0;
  int _memoryBytes = 0;
  int _apiBytes = 0;
  int _apiCount = 0;
  bool _loading = true;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final apiDao = await ref.read(apiCacheDaoProvider.future);
      final disk = await CacheInfo.diskImageCacheBytes();
      final memory = CacheInfo.memoryImageCacheBytes();
      final api = await CacheInfo.apiCacheBytes(apiDao);
      final count = await apiDao.count();
      if (!mounted) return;
      setState(() {
        _diskBytes = disk;
        _memoryBytes = memory;
        _apiBytes = api;
        _apiCount = count;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[cache] refresh failed: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// 单独清理某一类缓存：0=图片磁盘 / 1=图片内存 / 2=API 数据
  Future<void> _clearSingle(int kind) async {
    if (_clearing) return;
    setState(() => _clearing = true);
    try {
      if (kind == 0) {
        await CacheInfo.clearDiskImageCache();
      } else if (kind == 1) {
        CacheInfo.clearMemoryImageCache();
      } else {
        final apiDao = await ref.read(apiCacheDaoProvider.future);
        await CacheInfo.clearApiCache(apiDao);
      }
      if (!mounted) return;
      LumiraToast.show(context, '已清理', duration: const Duration(milliseconds: 1000));
      await _refresh();
    } catch (e) {
      debugPrint('[cache] clear single failed: $e');
      if (!mounted) return;
      LumiraToast.show(context, '清理失败', duration: const Duration(milliseconds: 1200));
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Future<void> _clearAll() async {
    if (_clearing) return;
    setState(() => _clearing = true);
    try {
      await CacheInfo.clearDiskImageCache();
      CacheInfo.clearMemoryImageCache();
      final apiDao = await ref.read(apiCacheDaoProvider.future);
      await CacheInfo.clearApiCache(apiDao);
      if (!mounted) return;
      LumiraToast.show(context, '缓存已全部清理', duration: const Duration(milliseconds: 1000));
      await _refresh();
    } catch (e) {
      debugPrint('[cache] clear all failed: $e');
      if (!mounted) return;
      LumiraToast.show(context, '清理失败', duration: const Duration(milliseconds: 1200));
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final totalBytes = _diskBytes + _memoryBytes + _apiBytes;

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '缓存',
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
          child: _loading
              ? Center(
                  child: CircularProgressIndicator(color: tokens.brand),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SummaryCard(
                        tokens: tokens,
                        totalBytes: totalBytes,
                        clearing: _clearing,
                        onClearAll: _clearAll,
                      ),
                      const SizedBox(height: 20),
                      _GroupTitle(text: '缓存分布', tokens: tokens),
                      const SizedBox(height: 8),
                      NeuCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Column(
                          children: [
                            _CacheItem(
                              icon: Icons.photo_library_outlined,
                              label: '图片缓存（磁盘）',
                              value: formatBytes(_diskBytes),
                              onClear: _clearing ? null : () => _clearSingle(0),
                              tokens: tokens,
                            ),
                            _CacheItem(
                              icon: Icons.memory_outlined,
                              label: '图片缓存（内存）',
                              value: formatBytes(_memoryBytes),
                              onClear: _clearing ? null : () => _clearSingle(1),
                              tokens: tokens,
                            ),
                            _CacheItem(
                              icon: Icons.cloud_off_outlined,
                              label: 'API 数据缓存',
                              value:
                                  '${formatBytes(_apiBytes)} · $_apiCount 条',
                              onClear: _clearing ? null : () => _clearSingle(2),
                              tokens: tokens,
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '提示：清理缓存不会删除你的照片、模板或设置数据。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textTertiary,
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

/// 顶部总览卡：占用空间 + 全部清理
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.tokens,
    required this.totalBytes,
    required this.clearing,
    required this.onClearAll,
  });

  final ThemeTokens tokens;
  final int totalBytes;
  final bool clearing;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          Text(
            '当前占用空间',
            style: TextStyle(
              fontSize: 13,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatBytes(totalBytes),
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          LumiraButton(
            variant: ButtonVariant.primary,
            onPressed: clearing ? null : onClearAll,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
            child: Text(clearing ? '清理中…' : '全部清理'),
          ),
        ],
      ),
    );
  }
}

class _CacheItem extends StatelessWidget {
  const _CacheItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.onClear,
    required this.tokens,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onClear;
  final ThemeTokens tokens;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(color: tokens.divider, width: 0.5),
              ),
            ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tokens.brand),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: tokens.textPrimary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: tokens.textTertiary,
            ),
          ),
          const SizedBox(width: 8),
          if (onClear != null)
            LumiraButton(
              variant: ButtonVariant.ghost,
              onPressed: onClear,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: const Text('清理'),
            ),
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle({required this.text, required this.tokens});
  final String text;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: tokens.textTertiary,
          letterSpacing: 0.04 * 13,
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
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.arrow_back_ios_new, size: 20, color: tokens.textPrimary),
      ),
    );
  }
}
