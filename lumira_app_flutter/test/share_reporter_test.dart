import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/utils/safe_share.dart';
import 'package:lumira_app_flutter/core/utils/share_reporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('notify 触发 onShare hook（同步段立即执行）', () {
    var called = 0;
    ShareReporter.onShare = () async {
      called++;
    };
    ShareReporter.notify();
    expect(called, 1);
    ShareReporter.onShare = null;
  });

  test('未 wire hook 时 notify 不抛错', () {
    ShareReporter.onShare = null;
    expect(ShareReporter.notify, returnsNormally);
  });

  test('SafeShare.share 调起后调用 notify（测试环境走剪贴板降级路径）', () async {
    var called = 0;
    ShareReporter.onShare = () async {
      called++;
    };
    await SafeShare.share('hello');
    expect(called, 1);
    ShareReporter.onShare = null;
  });

  test('降级到剪贴板时触发 onFallback 反馈（鸿蒙 share_plus 缺失场景）', () async {
    String? feedback;
    SafeShare.onFallback = (m) => feedback = m;
    await SafeShare.share('hello');
    expect(feedback, isNotNull);
    expect(feedback, contains('剪贴板'));
    SafeShare.onFallback = null;
  });

  test('shareXFiles 降级时同样触发 onFallback', () async {
    String? feedback;
    SafeShare.onFallback = (m) => feedback = m;
    await SafeShare.shareXFiles([XFile('/tmp/foo.pptpl')]);
    expect(feedback, isNotNull);
    expect(feedback, contains('剪贴板'));
    SafeShare.onFallback = null;
  });
}
