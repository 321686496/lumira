import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/capture_state.dart';

/// RAW 模式切换开关：禁用所有滤镜和后期处理。
/// 激活时背景为 amber，未激活时为白色半透明。
class RawModeToggle extends ConsumerWidget {
  const RawModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raw = ref.watch(CaptureState.rawModeProvider);
    return GestureDetector(
      onTap: () =>
          ref.read(CaptureState.rawModeProvider.notifier).state = !raw,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: raw ? Colors.amber : Colors.white24,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'RAW',
          style: TextStyle(
            color: raw ? Colors.black : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
