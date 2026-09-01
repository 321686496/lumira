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

// 邻域低频采样：以 strength 决定采样半径（对应 CPU radius 2..5）
float lowPassRadius() { return 2.0 + 3.0 * uStrength; }

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  float radius = lowPassRadius();
  // 4 方向 4 采样的低成本低频近似（可后续调权，匹配 CPU 高斯视觉）
  vec2 texel = 1.0 / uSize;
  vec4 base = texture(uTexture, uv) * 0.0;
  float wSum = 0.0;
  for (int i = -4; i <= 4; i++) {
    float w = exp(-float(i * i) / (2.0 * radius * radius));
    vec2 off = vec2(float(i), 0.0) * texel;
    base += texture(uTexture, uv + off) * w;
    wSum += w;
  }
  for (int i = -4; i <= 4; i++) {
    float w = exp(-float(i * i) / (2.0 * radius * radius));
    vec2 off = vec2(0.0, float(i)) * texel;
    base += texture(uTexture, uv + off) * w;
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