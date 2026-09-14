import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/utils/safe_share.dart';
import 'package:lumira_app_flutter/core/utils/share_reporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final binding = TestDefaultBinaryMessengerBinding.instance!;

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    SafeShare.onFallback = null;
    ShareReporter.onShare = null;
  });

  test('shareXFiles uses native share channel on iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    MethodCall? received;
    var shareCount = 0;
    String? fallback;
    ShareReporter.onShare = () async {
      shareCount++;
    };
    SafeShare.onFallback = (message) => fallback = message;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('lumira/system_share'),
      (call) async {
        received = call;
        return {'success': true};
      },
    );

    await SafeShare.shareXFiles(
      [XFile('/tmp/poster.png')],
      subject: 'subject',
      text: 'text',
    );

    expect(received?.method, 'shareFiles');
    expect(received?.arguments, {
      'paths': ['/tmp/poster.png'],
      'subject': 'subject',
      'text': 'text',
    });
    expect(shareCount, 1);
    expect(fallback, isNull);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('lumira/system_share'),
      null,
    );
  });

  test('share uses native share channel on iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    MethodCall? received;
    var shareCount = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('lumira/system_share'),
      (call) async {
        received = call;
        return {'success': true};
      },
    );
    ShareReporter.onShare = () async {
      shareCount++;
    };

    await SafeShare.share('hello', subject: 'subject');

    expect(received?.method, 'shareText');
    expect(received?.arguments, {'text': 'hello', 'subject': 'subject'});
    expect(shareCount, 1);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('lumira/system_share'),
      null,
    );
  });
}
