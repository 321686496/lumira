#version 460 core
#include <flutter/runtime_effect.glsl>

// Minimal detail preview path: sharpen + skin smooth only. Used when the full
// detail shader is unavailable or when grain/vignette/stretch are inactive.
uniform vec2 uSize;
uniform vec2 uFrameSize;
uniform float uSharpenA;
uniform float uSmooth;
uniform sampler2D uTexture;

out vec4 fragColor;

float ss_step(float e0, float e1, float x) {
  float t = clamp((x - e0) / (e1 - e0), 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  const vec3 L = vec3(0.299, 0.587, 0.114);
  vec2 texel = 1.0 / uFrameSize;
  vec3 rgb = texture(uTexture, uv).rgb;
  vec2 cp = clamp(uv, texel, vec2(1.0) - texel);

  if (uSharpenA != 0.0) {
    float l0 = dot(rgb, L);
    float mn = (dot(texture(uTexture, cp + vec2(0.0, -texel.y)).rgb, L)
              + dot(texture(uTexture, cp + vec2(0.0, texel.y)).rgb, L)
              + dot(texture(uTexture, cp + vec2(-texel.x, 0.0)).rgb, L)
              + dot(texture(uTexture, cp + vec2(texel.x, 0.0)).rgb, L)) * 0.25;
    float diff = l0 - mn;
    const float thr = 0.75 / 255.0;
    float amnt = 0.0;
    if (diff > thr) amnt = uSharpenA * (diff - thr);
    else if (diff < -thr) amnt = uSharpenA * (diff + thr);
    float edge = ss_step(0.75 / 255.0, 2.25 / 255.0, abs(diff));
    rgb += amnt * edge;
  }

  if (uSmooth > 0.0) {
    float frameLong = max(uFrameSize.x, uFrameSize.y);
    float sigma = (9.0 + 15.0 * uSmooth) * frameLong / 1280.0;
    float d = max(sigma * 0.5, 1.0);
    vec3 base = vec3(0.0);
    float wSum = 0.0;
    for (int i = -5; i <= 5; i++) {
      float w = exp(-float(i * i) / 8.0);
      base += texture(uTexture, cp + vec2(float(i) * d, 0.0) * texel).rgb * w;
      wSum += w;
    }
    for (int i = -5; i <= 5; i++) {
      float w = exp(-float(i * i) / 8.0);
      base += texture(uTexture, cp + vec2(0.0, float(i) * d) * texel).rgb * w;
      wSum += w;
    }
    base /= wSum;
    vec3 det = rgb - base;
    float margin = max(max(abs(det.r), abs(det.g)), abs(det.b));
    float y = dot(rgb, L);
    float cb = (-0.168736 * rgb.r - 0.331264 * rgb.g + 0.5 * rgb.b) + 0.5;
    float cr = (0.5 * rgb.r - 0.418688 * rgb.g - 0.081312 * rgb.b) + 0.5;
    float skin =
      ss_step(40.0 / 255.0, 60.0 / 255.0, y) *
      (1.0 - ss_step(250.0 / 255.0, 255.0 / 255.0, y)) *
      ss_step(128.0 / 255.0, 140.0 / 255.0, cr) *
      (1.0 - ss_step(172.0 / 255.0, 186.0 / 255.0, cr)) *
      ss_step(70.0 / 255.0, 85.0 / 255.0, cb) *
      (1.0 - ss_step(120.0 / 255.0, 132.0 / 255.0, cb));
    float edgeLow = (6.0 + uSmooth * 6.0) / 255.0;
    float sc = ss_step(edgeLow, edgeLow * 2.5, margin);
    float removal = clamp((0.50 * uSmooth + 0.04) * skin * (1.0 - sc), 0.0, 1.0);
    rgb = base + det * (1.0 - removal);
  }

  fragColor = vec4(clamp(rgb, 0.0, 1.0), 1.0);
}
