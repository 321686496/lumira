import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/gallery/data/name_resolver.dart';

void main() {
  group('sceneDisplayName', () {
    test('内置场景预设 id 解析为中文名', () {
      expect(sceneDisplayName('cafe-window'), '咖啡馆');
      expect(sceneDisplayName('home-cozy'), '居家温馨');
    });

    test('拍摄预览页短 id 解析为中文名（相册落库用的就是这套 id）', () {
      expect(sceneDisplayName('home'), '居家');
      expect(sceneDisplayName('cafe'), '咖啡馆');
      expect(sceneDisplayName('street'), '街头');
      expect(sceneDisplayName('park'), '公园');
      expect(sceneDisplayName('studio'), '工作室');
      expect(sceneDisplayName('restaurant'), '餐厅');
      expect(sceneDisplayName('travel'), '旅行');
      expect(sceneDisplayName('night'), '夜景');
    });

    test('未设置场景与未知 id', () {
      expect(sceneDisplayName('uncategorized'), '未设置场景');
      expect(sceneDisplayName('not-a-scene'), 'not-a-scene');
    });
  });

  group('templateDisplayName', () {
    test('未知模板 id 回退为原 id', () {
      expect(templateDisplayName('not-a-template'), 'not-a-template');
    });
  });
}