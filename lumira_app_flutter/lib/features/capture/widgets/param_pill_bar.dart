import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/capture_state.dart';
import '../domain/photo_template.dart';
import 'apply_button.dart';
import 'raw_mode_toggle.dart';

/// 顶部参数 Pill 栏：横向滚动的 EV / WB / ISO 标签 + ApplyButton + RawModeToggle + 滤镜入口。
/// 当 editableTemplate 为 null（自由拍摄）时整栏隐藏。
class ParamPillBar extends ConsumerWidget {
  const ParamPillBar({super.key});

  String _evDisplay(CameraParams c) {
    final ev = c.exposureCompensation;
    return ev == 0 ? 'EV 0' : 'EV ${ev >= 0 ? '+' : ''}$ev';
  }

  String _wbDisplay(CameraParams c) {
    const labels = {
      'daylight': '日光',
      'cloudy': '阴天',
      'shade': '阴影',
      'tungsten': '白炽灯',
      'fluorescent': '荧光',
      'custom': '自定义',
    };
    return 'WB ${labels[c.whiteBalance] ?? c.whiteBalance}';
  }

  String _isoDisplay(CameraParams c) {
    return 'ISO ${c.isoMode == 'manual' ? c.iso.toString() : 'Auto'}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editable = ref.watch(CaptureState.editableTemplateProvider);
    final cam = editable?.camera;
    if (cam == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Pill(text: _evDisplay(cam), onTap: () => _openPanel(context, ref, 'camera')),
          _Pill(text: _wbDisplay(cam), onTap: () => _openPanel(context, ref, 'camera')),
          _Pill(text: _isoDisplay(cam), onTap: () => _openPanel(context, ref, 'camera')),
          const ApplyButton(),
          const RawModeToggle(),
          _Pill(
            icon: Icons.filter_alt_outlined,
            text: '滤镜',
            onTap: () =>
                ref.read(CaptureState.filterPickerVisibleProvider.notifier).state = true,
          ),
        ].map((w) => Padding(padding: const EdgeInsets.only(right: 8), child: w)).toList(),
      ),
    );
  }

  /// 打开参数面板。`tab` 参数当前未使用（Task 8 将添加 activeTab provider 后接入）。
  void _openPanel(BuildContext context, WidgetRef ref, String tab) {
    ref.read(CaptureState.panelExpandedProvider.notifier).state = true;
  }
}

class _Pill extends StatelessWidget {
  final IconData? icon;
  final String? text;
  final VoidCallback onTap;
  const _Pill({this.icon, this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 12, color: Colors.white),
            if (icon != null && text != null) const SizedBox(width: 4),
            if (text != null)
              Text(
                text!,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}
