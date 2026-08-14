import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../home/data/home_providers.dart';
import '../../home/data/inspiration_models.dart';

class InspirationGuideBar extends ConsumerWidget {
  const InspirationGuideBar({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final async = ref.watch(homeInspirationProvider);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.brandSubtle,
              tokens.brandLight.withOpacity(0.45),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: async.when(
          loading: () => _content(tokens, HeroInspiration.fallback),
          error: (_, __) => _content(tokens, HeroInspiration.fallback),
          data: (insp) => _content(tokens, insp),
        ),
      ),
    );
  }

  Widget _content(ThemeTokens tokens, HeroInspiration insp) {
    final line1 = insp.dateText.isNotEmpty ? insp.dateText : '今天 · 适合拍照';
    final line2 = insp.weatherText.isNotEmpty
        ? '${insp.weatherText} · ${insp.description}'
        : insp.description;

    return Row(
      children: [
        Icon(Icons.wb_twilight_outlined, size: 22, color: tokens.brand),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line1,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                  fontFamily: 'Noto Serif SC',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                line2,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.arrow_forward_ios, size: 14, color: tokens.brand),
      ],
    );
  }
}
