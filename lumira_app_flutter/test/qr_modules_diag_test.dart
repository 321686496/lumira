import 'package:flutter_test/flutter_test.dart';
import 'package:qr/qr.dart';

void main() {
  test('compute qr module count for various data lengths', () {
    // 模拟不同长度的 base64url 链接数据
    final samples = <String, int>{
      '短名': 445,
      '长名(30字符中文)': 600,
      '超长名+多标签': 750,
    };
    samples.forEach((label, len) {
      final data = 'lumira://tpl/' + 'A' * (len - 'lumira://tpl/'.length);
      final qr = QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.L);
      // ignore: avoid_print
      print('$label: dataLen=${data.length} modules=${qr.moduleCount}');
    });
    final testData = 'lumira://tpl/' + 'A' * (445 - 'lumira://tpl/'.length);
    final qr = QrCode.fromData(data: testData, errorCorrectLevel: QrErrorCorrectLevel.L);
    // ignore: avoid_print
    print('445B: modules=${qr.moduleCount}');
  });
}
