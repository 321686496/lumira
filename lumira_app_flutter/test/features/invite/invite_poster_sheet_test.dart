import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/invite/widgets/invite_card_scene.dart';

String? captured;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    captured = null;
    TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        final arg = (call.arguments as Map)['text'] as String?;
        captured = arg;
      }
      return null;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  testWidgets('复制按钮将邀请码写入剪贴板', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeKeyProvider.overrideWith((_) => ThemeKey.warmWhite),
          uiStyleProvider.overrideWith((_) => UIStyle.neumorphic),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: InviteCardScene(
              code: 'LUMIRA-9KX2',
              onCopy: () => showInviteCopyToast(
                  tester.element(find.byType(InviteCardScene)), 'LUMIRA-9KX2'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(InviteCardScene));
    await tester.pump();
    expect(captured, 'LUMIRA-9KX2');
  });
}