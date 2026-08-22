import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/home/pages/home_page.dart'
    show sceneManageTabFor;

void main() {
  test('收藏 → tab=fav，管理 → tab=custom', () {
    expect(sceneManageTabFor('收藏'), 'fav');
    expect(sceneManageTabFor('管理'), 'custom');
  });
}