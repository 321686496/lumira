#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uStrength;
uniform sampler2D uTexture;

out vec4 fragColor;

float ss_step(float edge0, float edge1, float x) {
  float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

// 频率分离低频底图：11 稀疏 tap 十字高斯（tap 间距 σ/2，线性采样近似，覆盖 ±2.5σ）。
// σ = (9+15s)×longSide/1280 —— 与取景器（iOS CIGaussianBlur σ=9+15s @1280 长边
// 工作分辨率）及 CPU SkinSmoother（÷3 降采样大 σ 高斯 + 升采样）同视觉尺度。
// 此前 radius=2+3s 的 9-tap 小核（σ≈1.3..3.3）比取景器弱 5~10 倍 → 成片磨皮
// 观感「只是面部糊了一下」（2026-09-07 成片磨皮质量修复）。
// 间距 d=σ/2 时权重 exp(-(i·d)²/(2σ²)) = exp(-i²/8)，与 σ 无关。
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  float longSide = max(uSize.x, uSize.y);
  float sigma = (9.0 + 15.0 * uStrength) * longSide / 1280.0;
  float d = max(sigma * 0.5, 1.0);
  vec2 texel = 1.0 / uSize;
  vec3 base = vec3(0.0);
  float wSum = 0.0;
  for (int i = -5; i <= 5; i++) {
    float w = exp(-float(i * i) / 8.0);
    base += texture(uTexture, uv + vec2(float(i) * d, 0.0) * texel).rgb * w;
    wSum += w;
  }
  for (int i = -5; i <= 5; i++) {
    float w = exp(-float(i * i) / 8.0);
    base += texture(uTexture, uv + vec2(0.0, float(i) * d) * texel).rgb * w;
    wSum += w;
  }
  base /= wSum;

  vec4 src = texture(uTexture, uv);
  vec3 detail = src.rgb - base.rgb;
  float margin = max(max(abs(detail.r), abs(detail.g)), abs(detail.b));

  // YCbCr 肤色概率（BT.601，soft 区间 —— 与 skin_smoother.dart:_skinWeight 对等）
  float y  = 0.299 * src.r + 0.587 * src.g + 0.114 * src.b;
  float cb = (-0.168736 * src.r - 0.331264 * src.g + 0.5 * src.b) + 0.5;
  float cr = (0.5 * src.r - 0.418688 * src.g - 0.081312 * src.b) + 0.5;
  float yW   = ss_step(40.0 / 255.0, 60.0 / 255.0, y) * (1.0 - ss_step(250.0 / 255.0, 255.0 / 255.0, y));
  float crW  = ss_step(128.0 / 255.0, 140.0 / 255.0, cr) * (1.0 - ss_step(172.0 / 255.0, 186.0 / 255.0, cr));
  float cbW  = ss_step(70.0 / 255.0, 85.0 / 255.0, cb)  * (1.0 - ss_step(120.0 / 255.0, 132.0 / 255.0, cb));
  float skin = yW * crW * cbW;

  float baseRemove = 0.50 * uStrength + 0.04;
  float edgeLow  = 6.0 + 6.0 * uStrength;
  float edgeHigh = edgeLow * 2.5;
  float structure = ss_step(edgeLow, edgeHigh, margin);
  float removal = clamp(baseRemove * skin * (1.0 - structure), 0.0, 1.0);

  vec3 outC = base.rgb + detail.rgb * (1.0 - removal);
  fragColor = vec4(outC, src.a);
}