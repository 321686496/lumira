import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/home/data/home_mock_data.dart';
import 'package:lumira_app_flutter/features/home/data/operation_banners.dart';

void main() {
  group('matchOperationBanner', () {
    test('老用户未绑定邀请码 → 邀请运营位', () {
      final op = matchOperationBanner(
        isNewUser: false,
        inputs: const OperationUserInputs(hasBoundInviter: false),
      );
      expect(op, isNotNull);
      expect(op!.id, 'op_invite');
      expect(op.route, '/invite');
      expect(op.tag, '邀请有礼');
    });

    test('新用户不满足邀请条件（即使未绑定）', () {
      final op = matchOperationBanner(
        isNewUser: true,
        inputs: const OperationUserInputs(hasBoundInviter: false),
      );
      expect(op, isNull);
    });

    test('已绑定邀请 + 有积分余额 → 积分运营位', () {
      final op = matchOperationBanner(
        isNewUser: false,
        inputs: const OperationUserInputs(
          hasBoundInviter: true,
          pointsBalance: 30,
        ),
      );
      expect(op!.id, 'op_points');
      expect(op.route, '/points/wallet');
    });

    test('存在未解锁付费模板 → 上新运营位', () {
      final op = matchOperationBanner(
        isNewUser: false,
        inputs: const OperationUserInputs(hasLockedTemplate: true),
      );
      expect(op!.id, 'op_unlock');
      expect(op.route, '/templates/unlock');
    });

    test('多条件同时满足 → 按目录顺序取第一条（邀请优先）', () {
      final op = matchOperationBanner(
        isNewUser: false,
        inputs: const OperationUserInputs(
          hasBoundInviter: false,
          pointsBalance: 30,
          hasLockedTemplate: true,
        ),
      );
      expect(op!.id, 'op_invite');
    });

    test('状态未知（null，离线拉取失败）→ 全部条件不成立', () {
      final op = matchOperationBanner(
        isNewUser: false,
        inputs: const OperationUserInputs(),
      );
      expect(op, isNull);
    });
  });

  group('operationBannerToItem', () {
    test('转为 operation 类型 Banner，trackingId 与路由正确', () {
      final item = operationBannerToItem(kOperationBanners.first);
      expect(item.type, BannerType.operation);
      expect(item.trackingId, 'op_invite');
      expect(item.route, '/invite');
      expect(item.tag, '邀请有礼');
      expect(item.title, isNotEmpty);
      expect(item.subtitle, isNotEmpty);
      // 静态目录无配图：不带封面（品牌渐变背景）
      expect(item.hasCover, isFalse);
    });

    test('带配图的运营条目 → cover 传递 imageUrl（卡片右侧 contain 显示）', () {
      const banner = OperationBanner(
        id: 'op_img',
        title: 't',
        subtitle: 's',
        tag: 'tag',
        route: '/invite',
        condition: OperationCondition.nonNewUserNotInvited,
        imageUrl: 'https://lumira.iwtle.top/uploads/banners/b1/image.png',
      );
      final item = operationBannerToItem(banner);
      expect(item.cover, banner.imageUrl);
      expect(item.hasCover, isTrue);
      expect(item.type, BannerType.operation);
    });

    test('route /templates/detail + templateId → 拼出模板详情跳转路由', () {
      const banner = OperationBanner(
        id: 'op_tpl',
        title: 't',
        subtitle: 's',
        tag: '上新',
        route: '/templates/detail',
        condition: OperationCondition.hasLockedTemplate,
        templateId: 'tpl_film_vintage',
      );
      final item = operationBannerToItem(banner);
      expect(item.route, '/templates/detail?templateId=tpl_film_vintage');
    });
  });

  group('operationBannerFromJson（后端下发解析）', () {
    test('合法条目解析成功', () {
      final b = operationBannerFromJson({
        'id': 'op_invite',
        'title': 't',
        'subtitle': 's',
        'tag': '邀请有礼',
        'route': '/invite',
        'condition': 'nonNewUserNotInvited',
      });
      expect(b, isNotNull);
      expect(b!.id, 'op_invite');
      expect(b.condition, OperationCondition.nonNewUserNotInvited);
    });

    test('携带 imageUrl → 解析配图', () {
      final b = operationBannerFromJson({
        'id': 'x',
        'title': 't',
        'subtitle': 's',
        'tag': 'tag',
        'route': '/invite',
        'condition': 'pointsReady',
        'imageUrl': 'https://lumira.iwtle.top/uploads/banners/b1/image.png',
      });
      expect(
          b!.imageUrl, 'https://lumira.iwtle.top/uploads/banners/b1/image.png');
    });

    test('背景图焦点缺失时回退居中且不缩放', () {
      final b = operationBannerFromJson({
        'id': 'x',
        'title': 't',
        'subtitle': 's',
        'tag': 'tag',
        'route': '/invite',
        'condition': 'pointsReady',
      });
      expect(b!.focusX, 0.5);
      expect(b.focusY, 0.5);
      expect(b.focusZoom, 1.0);
    });

    test('背景图焦点解析并裁剪非法/越界值', () {
      final b = operationBannerFromJson({
        'id': 'x',
        'title': 't',
        'subtitle': 's',
        'tag': 'tag',
        'route': '/invite',
        'condition': 'pointsReady',
        'focusX': 1.4,
        'focusY': -0.4,
        'focusZoom': 4,
      });
      expect(b!.focusX, 1.0);
      expect(b.focusY, 0.0);
      expect(b.focusZoom, 3.0);

      final invalid = operationBannerFromJson({
        'id': 'x',
        'title': 't',
        'subtitle': 's',
        'tag': 'tag',
        'route': '/invite',
        'condition': 'pointsReady',
        'focusX': 'left',
        'focusY': 'bottom',
        'focusZoom': null,
      });
      expect(invalid!.focusX, 0.5);
      expect(invalid.focusY, 0.5);
      expect(invalid.focusZoom, 1.0);
    });

    test('operationBannerToItem 传递背景焦点元数据', () {
      const banner = OperationBanner(
        id: 'op_focus',
        title: 't',
        subtitle: 's',
        tag: 'tag',
        route: '/invite',
        condition: OperationCondition.pointsReady,
        imageUrl: 'https://example.com/image.png',
        focusX: 0.2,
        focusY: 0.8,
        focusZoom: 1.5,
      );
      final item = operationBannerToItem(banner);
      expect(item.focusX, 0.2);
      expect(item.focusY, 0.8);
      expect(item.focusZoom, 1.5);
    });

    test('imageUrl 空串/缺失/非字符串 → 视为无配图', () {
      final base = {
        'id': 'x',
        'title': 't',
        'subtitle': 's',
        'tag': 'tag',
        'route': '/invite',
        'condition': 'pointsReady',
      };
      expect(
          operationBannerFromJson({...base, 'imageUrl': ''})!.imageUrl, isNull);
      expect(operationBannerFromJson(base)!.imageUrl, isNull);
      expect(
          operationBannerFromJson({...base, 'imageUrl': 42})!.imageUrl, isNull);
    });

    test('route /templates/detail 携带 templateId → 解析成功', () {
      final b = operationBannerFromJson({
        'id': 'op_tpl',
        'title': 't',
        'subtitle': 's',
        'tag': '上新',
        'route': '/templates/detail',
        'condition': 'hasLockedTemplate',
        'templateId': 'tpl_film_vintage',
      });
      expect(b, isNotNull);
      expect(b!.route, '/templates/detail');
      expect(b.templateId, 'tpl_film_vintage');
    });

    test('route /templates/detail 但缺 templateId → fail-safe 丢弃', () {
      expect(
          operationBannerFromJson({
            'id': 'x',
            'title': 't',
            'subtitle': 's',
            'tag': 'tag',
            'route': '/templates/detail',
            'condition': 'hasLockedTemplate',
          }),
          isNull);
    });

    test('route 不在白名单 → 丢弃', () {
      expect(
          operationBannerFromJson({
            'id': 'x',
            'title': 't',
            'subtitle': 's',
            'tag': 'tag',
            'route': '/nonexistent',
            'condition': 'pointsReady',
          }),
          isNull);
    });

    test('condition 非法 → 丢弃', () {
      expect(
          operationBannerFromJson({
            'id': 'x',
            'title': 't',
            'subtitle': 's',
            'tag': 'tag',
            'route': '/invite',
            'condition': 'whatever',
          }),
          isNull);
    });

    test('字段缺失 → 丢弃', () {
      expect(operationBannerFromJson({'id': 'x'}), isNull);
    });
  });

  test('matchOperationBanner 支持远端下发列表', () {
    const custom = [
      OperationBanner(
        id: 'op_x',
        title: 'x',
        subtitle: 'x',
        tag: 'x',
        route: '/invite',
        condition: OperationCondition.nonNewUserNotInvited,
      ),
    ];
    final m = matchOperationBanner(
      isNewUser: false,
      banners: custom,
      inputs: const OperationUserInputs(hasBoundInviter: false),
    );
    expect(m?.id, 'op_x');
  });

  test('远端列表为空 → 不出运营位（后台全部停用语义）', () {
    expect(
      matchOperationBanner(
        isNewUser: false,
        banners: const [],
        inputs: const OperationUserInputs(hasBoundInviter: false),
      ),
      isNull,
    );
  });
}
