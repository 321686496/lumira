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
      // 运营位统一品牌渐变背景：不带模板封面
      expect(item.hasCover, isFalse);
    });
  });
}
