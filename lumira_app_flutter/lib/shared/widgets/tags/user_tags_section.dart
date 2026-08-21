import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/tags_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../lumira/lumira.dart';
import 'tag_chip.dart' show TagChip, TagChipKind;

/// 用户自定义标签区块（可复用于模板/场景详情页）。
///
/// 仅负责用户自定义标签的展示与增删；系统标签由模板/场景详情页自身负责展示，
/// 避免重复。输入时联想已有标签名。
class UserTagsSection extends ConsumerStatefulWidget {
  const UserTagsSection({
    super.key,
    required this.itemType,
    required this.itemId,
  });

  final String itemType;
  final String itemId;

  @override
  ConsumerState<UserTagsSection> createState() => _UserTagsSectionState();
}

class _UserTagsSectionState extends ConsumerState<UserTagsSection> {
  final TextEditingController _controller = TextEditingController();
  List<UserTag> _userTags = const [];
  List<String> _suggestions = const [];
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dao = await ref.read(userTagsDaoProvider.future);
    final tags = await dao.tagsFor(
      itemType: widget.itemType,
      itemId: widget.itemId,
    );
    if (!mounted) return;
    setState(() => _userTags = tags);
  }

  Future<void> _onChanged(String value) async {
    final dao = await ref.read(userTagsDaoProvider.future);
    final all = await dao.allTags(itemType: widget.itemType);
    final q = value.trim();
    final hits = q.isEmpty
        ? const <TagWithCount>[]
        : all.where((e) => e.tag.name.contains(q)).take(5).toList();
    if (!mounted) return;
    setState(() => _suggestions = hits.map((e) => e.tag.name).toList());
  }

  Future<void> _submit(String raw) async {
    final name = TagsDao.normalize(raw);
    if (name.isEmpty) return;
    final dao = await ref.read(userTagsDaoProvider.future);
    await dao.addTag(
      itemType: widget.itemType,
      itemId: widget.itemId,
      name: name,
    );
    if (!mounted) return;
    _controller.clear();
    setState(() {
      _suggestions = const [];
      _expanded = false;
    });
    await _load();
  }

  Future<void> _remove(int tagId) async {
    final dao = await ref.read(userTagsDaoProvider.future);
    await dao.removeTag(
      itemType: widget.itemType,
      itemId: widget.itemId,
      tagId: tagId,
    );
    await _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '标签',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary),
              ),
              if (_userTags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    '${_userTags.length}',
                    style: TextStyle(fontSize: 12, color: tokens.textTertiary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_userTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in _userTags)
                    TagChip(
                      label: t.name,
                      kind: TagChipKind.plain,
                      onDeleted: () => _remove(t.id),
                    ),
                ],
              ),
            ),
          if (!_expanded)
            GestureDetector(
              onTap: () => setState(() {
                _expanded = true;
                _onChanged('');
              }),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.add, size: 16, color: tokens.brand),
                    const SizedBox(width: 4),
                    Text('添加标签，方便日后查找',
                        style: TextStyle(fontSize: 12, color: tokens.brand)),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LumiraTextField(
                  controller: _controller,
                  hintText: '输入标签名，回车添加',
                  onChanged: _onChanged,
                  onSubmitted: _submit,
                ),
                if (_suggestions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in _suggestions)
                          TagChip(
                            label: s,
                            kind: TagChipKind.plain,
                            onTap: () => _submit(s),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}