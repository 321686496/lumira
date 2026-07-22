import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../data/challenge_providers.dart';

class ChallengeTipCard extends ConsumerWidget {
  const ChallengeTipCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final asyncTip = ref.watch(challengeTipProvider);

    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: asyncTip.when(
        loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => SizedBox(height: 80, child: Center(child: Text('加载失败', style: TextStyle(color: tokens.textSecondary)))),
        data: (tip) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: tokens.brandSubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(tip.icon, size: 20, color: tokens.brand),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tip.title,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                tip.description,
                style: TextStyle(fontSize: 13, height: 1.5, color: tokens.textSecondary),
              ),
            ],
          );
        },
      ),
    );
  }
}
