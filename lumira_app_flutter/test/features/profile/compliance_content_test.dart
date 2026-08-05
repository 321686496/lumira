import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/profile/data/compliance_content.dart';

void main() {
  group('ComplianceDocs', () {
    test('用户协议非空且包含关键章节', () {
      expect(ComplianceDocs.agreement, isNotEmpty);
      expect(ComplianceDocs.agreementUpdatedAt, isNotEmpty);
      final titles = ComplianceDocs.agreement.map((s) => s.title).toList();
      expect(titles, contains('服务内容'));
      expect(titles, contains('知识产权'));
    });

    test('隐私政策非空且包含关键章节', () {
      expect(ComplianceDocs.privacy, isNotEmpty);
      expect(ComplianceDocs.privacyUpdatedAt, isNotEmpty);
      final titles = ComplianceDocs.privacy.map((s) => s.title).toList();
      expect(titles, contains('我们收集的信息'));
      expect(titles, contains('未成年人保护'));
    });

    test('个人信息清单与SDK目录包含键值行与列表项', () {
      expect(ComplianceDocs.sdk, isNotEmpty);
      expect(ComplianceDocs.sdkUpdatedAt, isNotEmpty);
      final sections = ComplianceDocs.sdk;
      final hasKV = sections.any((s) => s.blocks.any((b) => b is ComplianceKVRow));
      final hasListItem = sections.any((s) => s.blocks.any((b) => b is ComplianceListItem));
      expect(hasKV, isTrue);
      expect(hasListItem, isTrue);
    });

    test('每个 section 的 blocks 均为受支持的类型', () {
      for (final doc in [ComplianceDocs.agreement, ComplianceDocs.privacy, ComplianceDocs.sdk]) {
        for (final section in doc) {
          for (final block in section.blocks) {
            expect(
              block is ComplianceParagraph ||
                  block is ComplianceKVRow ||
                  block is ComplianceListItem,
              isTrue,
              reason: 'unexpected block ${block.runtimeType}',
            );
          }
        }
      }
    });
  });
}
