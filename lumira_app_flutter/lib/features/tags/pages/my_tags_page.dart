import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/tags_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/effects/recessed_surface.dart';
import '../../../shared/widgets/lumira/lumira.dart' show LumiraIconButton;
import '../../../shared/widgets/nav/lumira_nav.dart';

/// 「我的标签」：以标签为中心浏览/管理用户自定义标签（tab 切换模板/场景，支持改名/删除）。
class MyTagsPage extends ConsumerStatefulWidget {
  const MyTagsPage({super.key});

  @override
  ConsumerState<MyTagsPage> createState() => _MyTagsPageState();
}

class _MyTagsPageState extends ConsumerState<MyTagsPage> {
  String _itemType = TagItemType.template;
  List<TagWithCount> _tags = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dao = await ref.read(userTagsDaoProvider.future);
    final tags = await dao.allTags(itemType: _itemType);
    if (!mounted) return;
    setState(() => _tags = tags);
  }

  void _switch(String itemType) {
    setState(() => _itemType = itemType);
    _load();
  }

  Future<void> _rename(TagWithCount e) async {
    final controller = TextEditingController(text: e.tag.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名标签'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('保存')),
        ],
      ),
    );
    if (newName == null || newName.trim().isEmpty) return;
    final dao = await ref.read(userTagsDaoProvider.future);
    await dao.renameTag(e.tag.id, newName);
    await _load();
  }

  Future<void> _delete(TagWithCount e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除标签'),
        content: Text('将同时移除「${e.tag.name}」关联的全部内容，确定删除？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    final dao = await ref.read(userTagsDaoProvider.future);
    await dao.deleteTag(e.tag.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Column(
          children: [
            LumiraNav(
              title: '我的标签',
              transparent: true,
              leading: LumiraIconButton(
                icon: Icons.arrow_back_ios_new,
                onPressed: () => Navigator.of(context).pop(),
                size: 20,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  _Tab(
                    label: '模板',
                    active: _itemType == TagItemType.template,
                    onTap: () => _switch(TagItemType.template),
                  ),
                  const SizedBox(width: 8),
                  _Tab(
                    label: '场景',
                    active: _itemType == TagItemType.scene,
                    onTap: () => _switch(TagItemType.scene),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _tags.isEmpty
                  ? Center(
                      child: Text(
                        '还没有标签，去给模板/场景打上标签吧',
                        style: TextStyle(
                            fontSize: 13, color: tokens.textTertiary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: _tags.length,
                      itemBuilder: (_, i) {
                        final e = _tags[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: tokens.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${e.tag.name} · ${e.count} 个',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 18),
                                onPressed: () => _rename(e),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18),
                                onPressed: () => _delete(e),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends ConsumerWidget {
  const _Tab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final isNeu = appTheme.style == UIStyle.neumorphic;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: isNeu && active
          ? RecessedSurface(
              tokens: tokens,
              borderRadius: 9999,
              depth: 0.7,
              rimFraction: 0.32,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active
                        ? (isNeu ? tokens.brandText : Colors.white)
                        : tokens.textSecondary,
                  ),
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                // neumorphic：方案 B 选中/未选中同为 surface，仅凸起↔凹陷翻转；品牌色只在文字
                color: isNeu
                    ? (active ? null : tokens.surface)
                    : (active ? tokens.brand : Colors.transparent),
                borderRadius: BorderRadius.circular(9999),
                boxShadow: isNeu
                    ? (active ? null : tokens.shadowConvexSubtle)
                    : null,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active
                      ? (isNeu ? tokens.brandText : Colors.white)
                      : tokens.textSecondary,
                ),
              ),
            ),
    );
  }
}