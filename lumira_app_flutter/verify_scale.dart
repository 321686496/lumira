import 'dart:math' as math;

void main() {
  print('======== 场景1：横屏JPEG 4032x3024，竖屏设备，全屏比例 ========');
  const srcW = 4032.0, srcH = 3024.0;
  const isPortrait = true;
  const targetRatio = 9.0 / 19.5;
  const maxDim = 1280.0;
  final outH = maxDim, outW = maxDim * targetRatio;
  print('src ${srcW}x$srcH → out ${outW.toStringAsFixed(1)}x$outH');
  verify(srcW, srcH, outW, outH, isPortrait);

  print('');
  print('======== 场景2：横屏JPEG 4032x3024，竖屏设备，4:3 比例 ========');
  const t2 = 3.0 / 4.0; // 竖屏 4:3 → 宽:高=3:4
  final outH2 = maxDim.toDouble();
  final outW2 = outH2 * t2; // 960
  print('src ${srcW}x$srcH → out ${outW2.toStringAsFixed(1)}x$outH2');
  verify(srcW, srcH, outW2, outH2, isPortrait);

  print('');
  print('======== 场景3：横屏JPEG 4032x3024，竖屏设备，1:1 比例 ========');
  const outW3 = 1080.0, outH3 = 1080.0;
  print('src ${srcW}x$srcH → out ${outW3}x$outH3');
  verify(srcW, srcH, outW3, outH3, isPortrait);
}

void verify(double srcW, double srcH, double outW, double outH, bool isPortrait) {
  final jpegIsLandscape = srcW > srcH;
  final needRotate = (isPortrait && jpegIsLandscape) || (!isPortrait && !jpegIsLandscape);
  final swapDims = needRotate; // alignRotation==90 or 270

  // A) 旧写法：max(outW/srcW, outH/srcH)，不管 swapDims
  final sOld = math.max(outW / srcW, outH / srcH);
  // B) dart_photo_pipeline quickProcess 修复前的写法：swapDims 时交换 outW/outH 做分母
  final sDartOld = swapDims
      ? math.max(outH / srcW, outW / srcH)
      : math.max(outW / srcW, outH / srcH);
  // C) 当前修复：swapDims 时 (outW/srcH, outH/srcW)
  final sNew = swapDims
      ? math.max(outW / srcH, outH / srcW)
      : math.max(outW / srcW, outH / srcH);

  print('needRotate=$needRotate');
  for (final entry in {
    'A旧BUG (max(outW/srcW,outH/srcH))': sOld,
    'B修复前dart (swap outW/outH再除,分母不交换)': sDartOld,
    'C修复后 (swap分母, outW/srcH, outH/srcW)': sNew,
  }.entries) {
    final s = entry.value;
    final rotatedW = swapDims ? srcH * s : srcW * s;
    final rotatedH = swapDims ? srcW * s : srcH * s;
    final xOK = rotatedW >= outW - 0.01;
    final yOK = rotatedH >= outH - 0.01;
    final sx = outW / rotatedW;
    final sy = outH / rotatedH;
    final ratioChange = sx / sy;
    print('  ${entry.key}:');
    print('    s=$s → 旋转后图像: ${rotatedW.toStringAsFixed(1)}x${rotatedH.toStringAsFixed(1)}');
    print('    vs画布: ${outW.toStringAsFixed(1)}x$outH → X:${xOK?"✓":"❌(${sx.toStringAsFixed(2)}x)"} Y:${yOK?"✓":"❌(${sy.toStringAsFixed(2)}x)"}');
    // 拉伸比例 = (outW/rotatedW) / (outH/rotatedH)，偏离 1 越多说明拉伸越严重
    if (!xOK || !yOK) {
      print('    ❌ 内容被拉伸: ratio-change=${ratioChange.toStringAsFixed(3)}x (偏离1越多越严重)');
    } else if ((ratioChange - 1.0).abs() > 0.01) {
      print('    ⚠️  内容比例被改变（非均匀填充）: ratio-change=${ratioChange.toStringAsFixed(3)}x');
    } else {
      print('    ✓ 正确：均匀缩放，覆盖画布，无拉伸');
    }
  }
}
