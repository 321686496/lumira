import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../capture/data/capture_state.dart';

/// 默认分辨率选择页
///
/// 控制拍摄成片的最大边长（高清/标准/流畅三档）：
/// - 选择即时写入 CaptureState.defaultResolutionProvider + 持久化到 user_settings
/// - 拍摄页 _onCapture 读取该值决定解码与输出尺寸
class ProfileSettingsResolutionPage extends ConsumerWidget {
  const ProfileSettingsResolutionPage({super.key});

  void _select(WidgetRef ref, BuildContext context, String id) {
    final label = CaptureResolutions.labelOf(id);
    ref.read(CaptureState.defaultResolutionProvider.notifier).state = id;
    // ignore: unawaited_futures
    CaptureState.persistDefaultResolution(
        ProviderScope.containerOf(context, listen: false), id);
    LumiraToast.show(context, '已切换至$label分辨率',
        duration: const Duration(milliseconds: 1000));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final current = ref.watch(CaptureState.defaultResolutionProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '默认分辨率',
        transparent: true,
        leading: _BackButton(tokens: tokens),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NeuCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < CaptureResolutions.options.length; i++) ...[
                      _ResolutionItem(
                        option: CaptureResolutions.options[i],
                        selected: CaptureResolutions.options[i].id == current,
                        tokens: tokens,
                        onTap: () => _select(ref, context, CaptureResolutions.options[i].id),
                      ),
                      if (i < CaptureResolutions.options.length - 1)
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: tokens.divider,
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _BottomNote(tokens: tokens),
            ],
          ),
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
      onTap: () {
        // canPop 保护
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          GoRouter.of(context).go(RouteNames.profileSettings);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.arrow_back_ios_new, size: 20, color: tokens.textPrimary),
      ),
    );
  }
}

class _ResolutionItem extends StatelessWidget {
  const _ResolutionItem({
    required this.option,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });
  final CaptureResolution option;
  final bool selected;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? tokens.brand : tokens.textTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, size: 18, color: tokens.brand),
          ],
        ),
      ),
    );
  }
}

class _BottomNote extends StatelessWidget {
  const _BottomNote({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '分辨率影响成片清晰度与处理速度，切换后下次拍摄生效',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: tokens.textTertiary,
        ),
      ),
    );
  }
}
