import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/checkin/widgets/checkin_poster_styles.dart';
import 'package:lumira_app_flutter/features/profile/widgets/collection_poster_styles.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_common.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_registry.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_types.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/template_poster_styles.dart';

/// 诊断：自动扫描所有海报样式，找出「底部文字下方出现 ≥2 条金色边框线」的样式。
void main() {
  final data = PosterStyleData(
    ratio: PosterRatio.ratio34,
    title: '晨光人像',
    category: '人像写真 · 摄影模板',
    qrData: 'lumira://tpl/diag',
    qrHint: '长按识别 · 查看完整模板',
    qrSub: '打开如画，拍出同款',
    shareText: '分享文案占位',
    authorName: '',
    note: '每一次快门，都是与光相遇的瞬间。',
    dateText: '2026.09.17',
    place: '杭州 · 西湖',
    rating: 4.5,
    photoBuilder: (w, h) =>
        Container(width: w, height: h, color: const Color(0xFFCCCCCC)),
  );

  final styles = <String, PosterStyle>{
    for (final s in templatePosterStyles()) 'template/${s.id}': s,
    for (final s in checkinPosterStyles()) 'checkin/${s.id}': s,
    for (final s in collectionPosterStyles()) 'collection/${s.id}': s,
  };

  for (final entry in styles.entries) {
    testWidgets('scan ${entry.key}', (tester) async {
      final result = await _scan(tester, entry.value.builder(data));
      if (result != null) {
        debugPrint('*** ${entry.key}: $result');
      } else {
        debugPrint('--- ${entry.key}: OK (1 line below bottom text)');
      }
    });
  }
}

/// 返回 null = 正常；返回字符串 = 底部文字下方有 ≥2 条金线，描述具体情况。
Future<String?> _scan(WidgetTester tester, Widget poster) async {
  final posterKey = GlobalKey();
  await tester.binding.setSurfaceSize(const Size(300, 800));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(child: RepaintBoundary(key: posterKey, child: poster)),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final lines = <Map<String, Object>>[];
  final root = tester.renderObject(find.byKey(posterKey));
  void visit(RenderObject node) {
    if (node is RenderDecoratedBox) {
      final pos = node.localToGlobal(Offset.zero);
      final deco = node.decoration;
      if (deco is BoxDecoration && deco.border is Border) {
        final b = deco.border! as Border;
        if (b.bottom != BorderSide.none) {
          lines.add({
            'kind': 'LINE',
            'y': pos.dy + node.size.height - b.bottom.width,
            'color': b.bottom.color.toString(),
          });
        }
      } else if (deco is BoxDecoration &&
          deco.color != null &&
          node.size.height <= 3 &&
          node.size.width >= 10) {
        // 细线色块：高 ≤3px 的实色盒子（如 Container(height:1,color:金)）
        lines.add({
          'kind': 'LINE',
          'y': pos.dy,
          'color': deco.color.toString(),
        });
      }
    } else if (node is RenderParagraph) {
      final text = node.text.toPlainText().trim();
      if (text.isEmpty) return;
      final pos = node.localToGlobal(Offset.zero);
      lines.add({
        'kind': 'TEXT',
        'y': pos.dy + node.size.height,
        'text': text.length > 16 ? text.substring(0, 16) : text,
      });
    }
    node.visitChildren(visit);
  }

  visit(root);
  final texts = lines.where((l) => l['kind'] == 'TEXT').toList();
  if (texts.isEmpty) return null;
  texts.sort((a, b) => (a['y'] as double).compareTo(b['y'] as double));
  final bottomTextY = texts.last['y'] as double;

  final below = lines
      .where((l) =>
          l['kind'] == 'LINE' &&
          (l['y'] as double) >= bottomTextY - 0.01)
      .toList();
  if (below.isEmpty) return null;
  below.sort((a, b) => (a['y'] as double).compareTo(b['y'] as double));
  final desc = below.map((l) => 'y=${(l['y'] as double).toStringAsFixed(1)} ${l['color']}').join(' | ');
  return '底部文字 "${texts.last['text']}" bottom=${bottomTextY.toStringAsFixed(1)} 下方有 ${below.length} 条线: $desc';
}
