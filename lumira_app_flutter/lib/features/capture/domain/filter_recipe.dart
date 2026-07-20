// lib/features/capture/domain/filter_recipe.dart
import 'dart:math' show cos, sin;
import 'dart:ui' show ColorFilter;
import 'photo_template.dart';

/// Identity matrix (no change)
final List<double> _identityMatrix = [
  1, 0, 0, 0, 0, // R
  0, 1, 0, 0, 0, // G
  0, 0, 1, 0, 0, // B
  0, 0, 0, 1, 0, // A
];

/// Multiply two 5x4 ColorMatrices (List<double> of length 20).
/// Matrices are treated as affine transforms in homogeneous coordinates
/// (extended to 5x5 with last row [0,0,0,0,1]).
List<double> _multiplyMatrices(List<double> a, List<double> b) {
  // Extend to 5x5: add [0, 0, 0, 0, 1] as the 5th row
  final aExt = [...a, 0, 0, 0, 0, 1]; // 25 elements
  final bExt = [...b, 0, 0, 0, 0, 1]; // 25 elements

  final result = List<double>.filled(25, 0);
  for (int i = 0; i < 5; i++) {
    for (int j = 0; j < 5; j++) {
      double sum = 0;
      for (int k = 0; k < 5; k++) {
        sum += aExt[i * 5 + k] * bExt[k * 5 + j];
      }
      result[i * 5 + j] = sum;
    }
  }

  // Return top 4 rows (20 elements)
  return result.sublist(0, 20);
}

/// Brightness matrix: brightness(1 + v/100) in CSS
/// v: -100 ~ 100 (0 = no change)
List<double> _brightnessMatrix(double v) {
  final factor = 1 + v / 100;
  return [
    factor, 0, 0, 0, 0,
    0, factor, 0, 0, 0,
    0, 0, factor, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// Contrast matrix: contrast(1 + v/100) in CSS
/// v: -100 ~ 100 (0 = no change)
List<double> _contrastMatrix(double v) {
  final c = 1 + v / 100;
  final t = (1 - c) / 2; // translate so 0.5 gray stays at 0.5
  return [
    c, 0, 0, 0, t * 255,
    0, c, 0, 0, t * 255,
    0, 0, c, 0, t * 255,
    0, 0, 0, 1, 0,
  ];
}

/// Saturation matrix: saturate(1 + v/100) in CSS
/// v: -100 ~ 100 (0 = no change, -100 = grayscale, +100 = double saturation)
List<double> _saturationMatrix(double v) {
  final s = 1 + v / 100;
  // Standard luminance weights: R*0.3086, G*0.6094, B*0.0820
  final lumR = 0.3086, lumG = 0.6094, lumB = 0.0820;
  final sr = (1 - s) * lumR;
  final sg = (1 - s) * lumG;
  final sb = (1 - s) * lumB;
  return [
    s + sr, sr, sr, 0, 0,
    sg, s + sg, sg, 0, 0,
    sb, sb, s + sb, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// Temperature matrix (warm/cool): approximates sepia + hue-rotate for warm,
/// hue-rotate + desaturate for cool.
/// v: -100 ~ 100 (positive = warm, negative = cool)
List<double> _temperatureMatrix(double v) {
  if (v == 0) return List.from(_identityMatrix);
  if (v > 0) {
    // Warm: increase R, decrease B slightly
    final t = v / 100;
    final rBoost = t * 0.2;
    final bReduce = t * 0.1;
    final satBoost = t * 0.1;
    return [
      1 + rBoost, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1 - bReduce, 0, 0,
      0, 0, 0, 1, 0,
    ];
  } else {
    // Cool: decrease R, increase B slightly
    final t = -v / 100;
    final rReduce = t * 0.1;
    final bBoost = t * 0.2;
    return [
      1 - rReduce, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1 + bBoost, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }
}

/// Tint matrix (hue-rotate approximation)
/// v: -100 ~ 100 (maps to -90° ~ 90° hue rotation, approximated as R/G/B shift)
List<double> _tintMatrix(double v) {
  if (v == 0) return List.from(_identityMatrix);
  // Approximate hue-rotate with a simple channel shift
  final angle = v * 0.9 * (3.14159 / 180); // to radians
  final cosA = cos(angle);
  final sinA = sin(angle);
  // Simplified hue rotation matrix (approximation)
  return [
    0.213 + cosA * 0.787 - sinA * 0.213, 0.715 - cosA * 0.715 - sinA * 0.715, 0.072 - cosA * 0.072 + sinA * 0.928, 0, 0,
    0.213 - cosA * 0.213 + sinA * 0.143, 0.715 + cosA * 0.285 + sinA * 0.140, 0.072 - cosA * 0.072 - sinA * 0.283, 0, 0,
    0.213 - cosA * 0.213 - sinA * 0.787, 0.715 - cosA * 0.715 + sinA * 0.715, 0.072 + cosA * 0.928 + sinA * 0.072, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// EV (exposure compensation) → brightness
/// ev: -3 ~ +3 → brightness 0.0 ~ 2.0 (1 + ev/3)
List<double> _evMatrix(double ev) {
  final factor = 1 + ev / 3;
  return [
    factor, 0, 0, 0, 0,
    0, factor, 0, 0, 0,
    0, 0, factor, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// Grayscale matrix: grayscale(1) in CSS
final List<double> _grayscaleMatrix = [
  0.3086, 0.6094, 0.0820, 0, 0,
  0.3086, 0.6094, 0.0820, 0, 0,
  0.3086, 0.6094, 0.0820, 0, 0,
  0, 0, 0, 1, 0,
];

/// Sepia matrix: sepia(t) where t is 0~1
List<double> _sepiaMatrix(double t) {
  // CSS sepia matrix (interpolated by t)
  final identity = List.from(_identityMatrix);
  final sepia = [
    0.393, 0.769, 0.189, 0, 0,
    0.349, 0.686, 0.168, 0, 0,
    0.272, 0.534, 0.131, 0, 0,
    0, 0, 0, 1, 0,
  ];
  // Lerp between identity and sepia by t
  return List.generate(20, (i) => identity[i] * (1 - t) + sepia[i] * t);
}

/// ISO effect: ISO > 200 adds slight brightness boost
List<double> _isoMatrix(int iso) {
  if (iso <= 200) return List.from(_identityMatrix);
  final boost = (iso - 200) / 6400 * 0.3;
  return _brightnessMatrix(boost * 100);
}

// ─── System Filters ───

/// System filter matrices (approximations of the CSS filter strings from filterRecipe.ts)
/// Each matches SYSTEM_FILTERS in the TS source.
///
/// Composition order: for CSS `A(x) B(y) C(z)` (A applied first, C last), the
/// matrix is `C * B * A` — last-applied filter is LEFTMOST.
List<double> composeSystemFilterMatrix(String name) {
  switch (name) {
    case 'none':
      return List.from(_identityMatrix);
    case 'vivid':
      // contrast(1.1) saturate(1.25) brightness(1.02) → B·S·C
      return _multiplyMatrices(
        _brightnessMatrix(2),
        _multiplyMatrices(_saturationMatrix(25), _contrastMatrix(10)),
      );
    case 'vivid_warm':
      // sepia(0.15) saturate(1.2) contrast(1.08) brightness(1.03) hue-rotate(-5deg) → Tint·B·C·S·Sepia
      return _multiplyMatrices(
        _tintMatrix(-5.5), // -5deg ≈ -5.5 in our -100~100 scale
        _multiplyMatrices(
          _brightnessMatrix(3),
          _multiplyMatrices(
            _contrastMatrix(8),
            _multiplyMatrices(_saturationMatrix(20), _sepiaMatrix(0.15)),
          ),
        ),
      );
    case 'vivid_cool':
      // saturate(1.15) contrast(1.08) brightness(1.02) hue-rotate(8deg) → Tint·B·C·S
      return _multiplyMatrices(
        _tintMatrix(8.8),
        _multiplyMatrices(
          _brightnessMatrix(2),
          _multiplyMatrices(_contrastMatrix(8), _saturationMatrix(15)),
        ),
      );
    case 'mono':
      // grayscale(1) contrast(1.05) → C·Grayscale
      return _multiplyMatrices(_contrastMatrix(5), _grayscaleMatrix);
    case 'silver':
      // grayscale(1) sepia(0.2) contrast(0.95) brightness(1.08) → B·C·Sepia·Grayscale
      return _multiplyMatrices(
        _brightnessMatrix(8),
        _multiplyMatrices(
          _contrastMatrix(-5),
          _multiplyMatrices(_sepiaMatrix(0.2), _grayscaleMatrix),
        ),
      );
    case 'noir':
      // grayscale(1) contrast(1.3) brightness(0.95) → B·C·Grayscale
      return _multiplyMatrices(
        _brightnessMatrix(-5),
        _multiplyMatrices(_contrastMatrix(30), _grayscaleMatrix),
      );
    default:
      return List.from(_identityMatrix);
  }
}

/// Returns a ColorFilter for a system filter name.
ColorFilter fromSystemFilter(String name) {
  return ColorFilter.matrix(composeSystemFilterMatrix(name));
}

// ─── LUT Presets ───

/// LUT preset matrices (approximations of the CSS filter strings from filterRecipe.ts)
/// Each matches LUT_FILTERS in the TS source (16 presets + 'none').
///
/// Composition order: for CSS `A(x) B(y) C(z)` (A applied first, C last), the
/// matrix is `C * B * A` — last-applied filter is LEFTMOST.
List<double> composeLutMatrix(String name) {
  switch (name) {
    case 'none':
      return List.from(_identityMatrix);
    case 'cinematic':
      // contrast(1.15) saturate(0.9) hue-rotate(-8deg) brightness(0.97) → B·Tint·S·C
      return _multiplyMatrices(
        _brightnessMatrix(-3),
        _multiplyMatrices(
          _tintMatrix(-8.8),
          _multiplyMatrices(_saturationMatrix(-10), _contrastMatrix(15)),
        ),
      );
    case 'vintage':
      // sepia(0.35) contrast(1.1) brightness(1.05) saturate(0.85) → Sat·B·C·Sepia
      return _multiplyMatrices(
        _saturationMatrix(-15),
        _multiplyMatrices(
          _brightnessMatrix(5),
          _multiplyMatrices(_contrastMatrix(10), _sepiaMatrix(0.35)),
        ),
      );
    case 'bw':
      // grayscale(1) contrast(1.1) → C·Grayscale
      return _multiplyMatrices(_contrastMatrix(10), _grayscaleMatrix);
    case 'warm_film':
      // sepia(0.2) saturate(1.15) brightness(1.03) hue-rotate(-5deg) → Tint·B·S·Sepia
      return _multiplyMatrices(
        _tintMatrix(-5.5),
        _multiplyMatrices(
          _brightnessMatrix(3),
          _multiplyMatrices(_saturationMatrix(15), _sepiaMatrix(0.2)),
        ),
      );
    case 'cool_film':
      // saturate(0.9) brightness(0.98) hue-rotate(8deg) → Tint·B·S
      return _multiplyMatrices(
        _tintMatrix(8.8),
        _multiplyMatrices(_brightnessMatrix(-2), _saturationMatrix(-10)),
      );
    case 'pastel':
      // contrast(0.92) saturate(0.85) brightness(1.08) → B·S·C
      return _multiplyMatrices(
        _brightnessMatrix(8),
        _multiplyMatrices(_saturationMatrix(-15), _contrastMatrix(-8)),
      );
    case 'fuji':
      // saturate(1.2) contrast(1.05) hue-rotate(-3deg) brightness(1.02) → B·Tint·C·S
      return _multiplyMatrices(
        _brightnessMatrix(2),
        _multiplyMatrices(
          _tintMatrix(-3.3),
          _multiplyMatrices(_contrastMatrix(5), _saturationMatrix(20)),
        ),
      );
    case 'portrait':
      // saturate(1.05) contrast(1.05) brightness(1.03) sepia(0.05) → Sepia·B·C·S
      return _multiplyMatrices(
        _sepiaMatrix(0.05),
        _multiplyMatrices(
          _brightnessMatrix(3),
          _multiplyMatrices(_contrastMatrix(5), _saturationMatrix(5)),
        ),
      );
    case 'japanese':
      // saturate(0.85) contrast(0.92) brightness(1.1) hue-rotate(3deg) → Tint·B·C·S
      return _multiplyMatrices(
        _tintMatrix(3.3),
        _multiplyMatrices(
          _brightnessMatrix(10),
          _multiplyMatrices(_contrastMatrix(-8), _saturationMatrix(-15)),
        ),
      );
    case 'cyberpunk':
      // saturate(1.4) contrast(1.2) hue-rotate(-15deg) brightness(0.95) → B·Tint·C·S
      return _multiplyMatrices(
        _brightnessMatrix(-5),
        _multiplyMatrices(
          _tintMatrix(-16.5),
          _multiplyMatrices(_contrastMatrix(20), _saturationMatrix(40)),
        ),
      );
    case 'sepia_classic':
      // sepia(0.7) contrast(1.05) brightness(1.02) → B·C·Sepia
      return _multiplyMatrices(
        _brightnessMatrix(2),
        _multiplyMatrices(_contrastMatrix(5), _sepiaMatrix(0.7)),
      );
    case 'mist':
      // contrast(0.88) brightness(1.12) saturate(0.9) → S·B·C
      return _multiplyMatrices(
        _saturationMatrix(-10),
        _multiplyMatrices(_brightnessMatrix(12), _contrastMatrix(-12)),
      );
    case 'rouge':
      // sepia(0.2) saturate(1.1) hue-rotate(-10deg) brightness(1.02) → B·Tint·S·Sepia
      return _multiplyMatrices(
        _brightnessMatrix(2),
        _multiplyMatrices(
          _tintMatrix(-11),
          _multiplyMatrices(_saturationMatrix(10), _sepiaMatrix(0.2)),
        ),
      );
    case 'twilight':
      // saturate(1.15) hue-rotate(15deg) contrast(1.05) brightness(0.95) → B·C·Tint·S
      return _multiplyMatrices(
        _brightnessMatrix(-5),
        _multiplyMatrices(
          _contrastMatrix(5),
          _multiplyMatrices(_tintMatrix(16.5), _saturationMatrix(15)),
        ),
      );
    case 'cyan':
      // saturate(1.1) hue-rotate(20deg) contrast(1.05) brightness(1.02) → B·C·Tint·S
      return _multiplyMatrices(
        _brightnessMatrix(2),
        _multiplyMatrices(
          _contrastMatrix(5),
          _multiplyMatrices(_tintMatrix(22), _saturationMatrix(10)),
        ),
      );
    default:
      return List.from(_identityMatrix);
  }
}

/// Returns a ColorFilter approximating a LUT preset.
ColorFilter approximateLut(String lutName) {
  return ColorFilter.matrix(composeLutMatrix(lutName));
}

// ─── Combined PostProcess → ColorFilter ───

/// Composes the raw 5×4 ColorMatrix (List<double> of length 20) for a
/// PostProcess. Exposed so tests can verify numeric matrix values.
///
/// Composition order matches the CSS filter-string order from
/// filterRecipe.ts `buildCssFilter`: brightness → contrast → saturation →
/// temperature → tint → highlights/shadows/blackPoint → clarity → vibrance →
/// brilliance → systemFilter → LUT. In matrix terms the LAST-applied filter is
/// LEFTMOST (outer), so each subsequent adjustment is prepended to the left.
List<double> composePostProcessMatrix(PostProcess process) {
  final color = process.color;

  // Base color: brightness applied first (rightmost), tint applied last (leftmost)
  var matrix = _brightnessMatrix(color.brightness);
  matrix = _multiplyMatrices(_contrastMatrix(color.contrast), matrix);
  matrix = _multiplyMatrices(_saturationMatrix(color.saturation), matrix);
  matrix = _multiplyMatrices(_temperatureMatrix(color.temperature), matrix);
  matrix = _multiplyMatrices(_tintMatrix(color.tint), matrix);

  // Highlights, shadows, blackPoint (approximate via brightness/contrast)
  // Applied after base color in CSS order → prepended to the left.
  if (color.highlights != null && color.highlights != 0) {
    matrix = _multiplyMatrices(_brightnessMatrix(color.highlights! / 3), matrix);
  }
  if (color.shadows != null && color.shadows != 0) {
    matrix = _multiplyMatrices(_brightnessMatrix(color.shadows! / 2.5), matrix);
    matrix = _multiplyMatrices(_contrastMatrix(-color.shadows! / 4), matrix);
  }
  if (color.blackPoint != null && color.blackPoint != 0) {
    matrix = _multiplyMatrices(_contrastMatrix(color.blackPoint! / 2), matrix);
  }

  // Clarity (mid-tone contrast)
  if (color.clarity != null && color.clarity != 0) {
    matrix = _multiplyMatrices(_contrastMatrix(color.clarity! / 2), matrix);
  }

  // Vibrance (approximate as saturation)
  if (color.vibrance != null && color.vibrance != 0) {
    matrix = _multiplyMatrices(_saturationMatrix(color.vibrance! / 1.5), matrix);
  }

  // Brilliance (brightness + saturation)
  if (color.brilliance != null && color.brilliance != 0) {
    matrix = _multiplyMatrices(_brightnessMatrix(color.brilliance! / 3), matrix);
    matrix = _multiplyMatrices(_saturationMatrix(color.brilliance! / 2), matrix);
  }

  // System filter (applied before LUT in CSS order → prepended before LUT)
  if (process.systemFilter != null && process.systemFilter != 'none') {
    matrix = _multiplyMatrices(composeSystemFilterMatrix(process.systemFilter!), matrix);
  }

  // LUT preset (applied last in CSS order → leftmost)
  if (process.lut != 'none') {
    matrix = _multiplyMatrices(composeLutMatrix(process.lut), matrix);
  }

  return matrix;
}

/// Builds a combined ColorFilter from PostProcess parameters for camera preview.
/// Corresponds to uni-app's buildCssFilter() but returns a ColorFilter instead of a CSS string.
ColorFilter fromPostProcess(PostProcess process) {
  return ColorFilter.matrix(composePostProcessMatrix(process));
}

// ─── Display Labels ───

/// Returns the display name for a LUT preset.
String lutLabel(String lutName) {
  const map = {
    'none': '原图',
    'cinematic': '电影感',
    'vintage': '复古胶片',
    'bw': '黑白',
    'warm_film': '暖色胶片',
    'cool_film': '冷色胶片',
    'pastel': '柔色',
    'fuji': '富士感',
    'portrait': '人像',
    'japanese': '日系',
    'cyberpunk': '赛博朋克',
    'sepia_classic': '褐调',
    'mist': '薄雾',
    'rouge': '胭脂',
    'twilight': '暮光',
    'cyan': '青调',
  };
  return map[lutName] ?? '原图';
}

/// Returns the display name for a system filter.
String systemFilterLabel(String name) {
  const map = {
    'none': '原图',
    'vivid': '鲜明',
    'vivid_warm': '鲜暖色',
    'vivid_cool': '鲜冷色',
    'mono': '单色',
    'silver': '银色调',
    'noir': '黑白',
  };
  return map[name] ?? '原图';
}
