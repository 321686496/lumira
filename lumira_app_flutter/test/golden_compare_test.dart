import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compare normal vs pressed goldens', (tester) async {
    final dir = Directory('test/goldens');
    final normalFile = File('${dir.path}/btn_neu_normal.png');
    final pressedFile = File('${dir.path}/btn_neu_pressed.png');
    final secondaryFile = File('${dir.path}/btn_neu_secondary.png');

    Future<ui.Image> decode(File f) async {
      final bytes = await f.readAsBytes();
      return await tester.binding.runAsync(
          () => decodeImageFromList(bytes)) as ui.Image;
    }

    final normal = await decode(normalFile);
    final pressed = await decode(pressedFile);
    final secondary = await decode(secondaryFile);
    debugPrint('[cmp] sizes: normal=${normal.width}x${normal.height} pressed=${pressed.width}x${pressed.height} secondary=${secondary.width}x${secondary.height}');

    Future<List<Color>> pixels(ui.Image img) async {
      final data = await tester.binding.runAsync(
          () => img.toByteData(format: ui.ImageByteFormat.rawRgba));
      final out = <Color>[];
      for (var y = 0; y < img.height; y += 1) {
        for (var x = 0; x < img.width; x += 1) {
          final i = (y * img.width + x) * 4;
          out.add(Color.fromARGB(data!.getUint8(i + 3), data!.getUint8(i),
              data!.getUint8(i + 1), data!.getUint8(i + 2)));
        }
      }
      return out;
    }

    final pn = await pixels(normal);
    final pp = await pixels(pressed);
    final ps = await pixels(secondary);
    debugPrint('[cmp] normal unique=${pn.toSet().length} pressed unique=${pp.toSet().length} secondary unique=${ps.toSet().length}');

    // 统计差异像素
    var diff = 0;
    var sameBrandFill = 0;
    for (var y = 0; y < normal.height; y++) {
      for (var x = 0; x < normal.width; x++) {
        final i = y * normal.width + x;
        if (pn[i] != pp[i]) diff++;
        // 按钮中心区域（大致在图像中部）品牌填充对比
        final cy = normal.height ~/ 2;
        final cx = normal.width ~/ 2;
        if (x > cx - 20 && x < cx + 20 && y > cy - 8 && y < cy + 8) {
          if (pn[i] == pp[i]) sameBrandFill++;
        }
      }
    }
    debugPrint('[cmp] diffPixels=$diff (total=${normal.width * normal.height})');
    debugPrint('[cmp] sameBrandFillInCenter=$sameBrandFill');
    debugPrint('[cmp] normal center=${pn[normal.height ~/ 2 * normal.width + normal.width ~/ 2]}');
    debugPrint('[cmp] pressed center=${pp[normal.height ~/ 2 * normal.width + normal.width ~/ 2]}');
    debugPrint('[cmp] secondary center=${ps[normal.height ~/ 2 * normal.width + normal.width ~/ 2]}');
  });
}