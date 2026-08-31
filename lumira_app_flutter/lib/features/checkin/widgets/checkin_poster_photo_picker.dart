import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/lumira/dialog/lumira_bottom_sheet.dart';
import 'checkin_common.dart';

const int _kMaxPhotos = 5;

/// 探店足迹照片 >5 张时弹出的「选照片」面板。
///
/// 网格多选，最多 5 张；选中顺序即展示顺序，列表首位为大图；可上移/下移调序。
/// 返回按展示顺序排列的 URL 列表；取消或未选返回 null。
Future<List<String>?> showCheckinPhotoPicker({
  required BuildContext context,
  required ThemeTokens tokens,
  required List<String> photoUrls,
}) {
  return showLumiraBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _CheckinPhotoPickerPanel(tokens: tokens, photoUrls: photoUrls),
  );
}

class _CheckinPhotoPickerPanel extends StatefulWidget {
  const _CheckinPhotoPickerPanel({required this.tokens, required this.photoUrls});
  final ThemeTokens tokens;
  final List<String> photoUrls;

  @override
  State<_CheckinPhotoPickerPanel> createState() => _CheckinPhotoPickerPanelState();
}

class _CheckinPhotoPickerPanelState extends State<_CheckinPhotoPickerPanel> {
  // 已选下标（有序，首位为大图）
  final List<int> _selected = [];

  bool get _full => _selected.length >= _kMaxPhotos;

  void _toggle(int index) {
    setState(() {
      if (_selected.contains(index)) {
        _selected.remove(index);
      } else if (!_full) {
        _selected.add(index);
      }
    });
  }

  void _move(int pos, int delta) {
    final swap = pos + delta;
    if (swap < 0 || swap >= _selected.length) return;
    setState(() {
      final tmp = _selected[pos];
      _selected[pos] = _selected[swap];
      _selected[swap] = tmp;
    });
  }

  List<String> get _result => _selected.map((i) => widget.photoUrls[i]).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final cell = (MediaQuery.of(context).size.width - 20 * 2 - 8 * 2) / 3;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('选择照片', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: t.textPrimary)),
                  const SizedBox(height: 4),
                  Text('已选 ${_selected.length} / $_kMaxPhotos，首位为海报大图', style: TextStyle(fontSize: 12, color: t.textTertiary)),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: widget.photoUrls.length,
                itemBuilder: (context, i) {
                  final sel = _selected.contains(i);
                  final order = _selected.indexOf(i);
                  return GestureDetector(
                    onTap: () => _toggle(i),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CheckinPhotoImage(
                            url: widget.photoUrls[i],
                            tokens: t,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (sel)
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: t.brand, width: 3),
                              color: const Color(0x33000000),
                            ),
                            child: Center(
                              child: Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: t.brand),
                                child: Text('${order + 1}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_selected.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: cell * 0.62,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _selected.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, pos) {
                    final idx = _selected[pos];
                    return Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: cell * 0.62,
                            height: cell * 0.62,
                            child: CheckinPhotoImage(url: widget.photoUrls[idx], tokens: t, fit: BoxFit.cover),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.arrow_upward, size: 16),
                              onPressed: pos == 0 ? null : () => _move(pos, -1),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.arrow_downward, size: 16),
                              onPressed: pos == _selected.length - 1 ? null : () => _move(pos, 1),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _selected.isEmpty ? null : () => Navigator.of(context).pop(_result),
                  child: Text(_selected.isEmpty ? '尚未选择' : '确定（${_selected.length} 张）'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
