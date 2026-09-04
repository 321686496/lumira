#version 460 core
#include <flutter/runtime_effect.glsl>

// 取景器实时美颜统一算法 shader（OHOS/Android 真视图层单 pass）：
//   锐化(亮度域死区 Unsharp) → 颗粒(预置 tile+亮度幅度) → 磨皮(频率分离+YCbCr肤色+结构门控) → 暗角(解析式)。
// 数值语义与 OHOS C++ bake / iOS 原生预览 / Dart bake 一致（颜色按 0..1，阈值/幅度相应折算）。
// 色彩矩阵不在本 shader —— 矩阵仍由外层 ColorFiltered 叠加，避免改变既有调色行为。
//
// 输入：
//   uSize       framebuffer 尺寸（FlutterFragCoord 归一化用）
//   uFrameSize  被捕获帧的像素尺寸（颗粒 1 像素/texel 的密度基准）
//   uSharpen/uVignette/uSmooth/uGrain  0..1 强度（0=关闭对应效果，走直通）
//   uTexture    已叠加色彩矩阵的取景器帧
//   uNoise      128×128 预置颗粒 tile（单通道灰度，进程一次构建）

uniform vec2 uSize;
uniform vec2 uFrameSize;
uniform float uSharpen;
uniform float uVignette;
uniform float uSmooth;
uniform float uGrain;
uniform sampler2D uTexture;
uniform sampler2D uNoise;

out vec4 fragColor;

float ss_step(float e0, float e1, float x) {
  float t = clamp((x - e0) / (e1 - e0), 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 tsp = uFrameSize;
  vec2 texel = 1.0 / uFrameSize;
  vec3 rgb = texture(uTexture, uv).rgb;
  const vec3 l = vec3(0.299, 0.587, 0.114);

  // 1) 锐化：亮度域死区 Unsharp（4 邻域均值）
  if (uSharpen > 0.0) {
    vec2 cp = clamp(uv, texel, vec2(1.0) - texel);
    float l0 = dot(rgb, l);
    float mn = ( dot(texture(uTexture, cp + vec2(0.0, -1.0) * texel).rgb, l)
               + dot(texture(uTexture, cp + vec2(0.0,  1.0) * texel).rgb, l)
               + dot(texture(uTexture, cp + vec2(-1.0, 0.0) * texel).rgb, l)
               + dot(texture(uTexture, cp + vec2( 1.0, 0.0) * texel).rgb, l) ) * 0.25;
    float diff = l0 - mn;
    float thr = 1.0 / 255.0;
    float amnt = 0.0;
    if (diff > thr) amnt = uSharpen * (diff - thr);
    else if (diff < -thr) amnt = uSharpen * (diff + thr);
    float edge = ss_step(1.0 / 255.0, 2.5 / 255.0, abs(diff));
    rgb += amnt * edge;
  }

  // 2) 颗粒：预置 tile 双线性 + 幅度随亮度（1 像素/texel，与成片一致密度）
  if (uGrain > 0.0) {
    vec2 fpx = uv * uFrameSize;
    vec2 ntex = vec2(mod(fpx.x + 13.0, 128.0), mod(fpx.y + 29.0, 128.0));
    float g = texture(uNoise, ntex / 128.0).r; // 纹理线性过滤 → 双线性
    float luma = dot(rgb, l);
    float ls = mix(0.35, 1.0, ss_step(0.05, 0.85, luma));
    float amp = uGrain * (24.0 / 255.0) * ls;
    rgb += (g * 2.0 - 1.0) * amp;
  }

  // 3) 磨皮：频率分离 + YCbCr 肤色 + 结构门控（5-tap 十字低通近似，不整图模糊）
  if (uSmooth > 0.0) {
    vec2 cp = clamp(uv, texel, vec2(1.0) - texel);
    vec3 sU = texture(uTexture, cp + vec2(0.0, -1.0) * texel).rgb;
    vec3 sD = texture(uTexture, cp + vec2(0.0,  1.0) * texel).rgb;
    vec3 sL = texture(uTexture, cp + vec2(-1.0, 0.0) * texel).rgb;
    vec3 sR = texture(uTexture, cp + vec2( 1.0, 0.0) * texel).rgb;
    vec3 base = (rgb * 4.0 + sU + sD + sL + sR) / 8.0;
    vec3 det = rgb - base;
    float margin = max(max(abs(det.r), abs(det.g)), abs(det.b));
    float y  = dot(rgb, l);
    float cb = (-0.168736 * rgb.r - 0.331264 * rgb.g + 0.5 * rgb.b) + (128.0 / 255.0);
    float cr = ( 0.5 * rgb.r - 0.418688 * rgb.g - 0.081312 * rgb.b) + (128.0 / 255.0);
    float skin = ss_step( 40.0 / 255.0,  60.0 / 255.0, y) * (1.0 - ss_step(250.0 / 255.0, 255.0 / 255.0, y))
               * ss_step(128.0 / 255.0, 140.0 / 255.0, cr) * (1.0 - ss_step(172.0 / 255.0, 186.0 / 255.0, cr))
               * ss_step( 70.0 / 255.0,  85.0 / 255.0, cb) * (1.0 - ss_step(120.0 / 255.0, 132.0 / 255.0, cb));
    float edgeLow = (6.0 + uSmooth * 6.0) / 255.0;
    float edgeHigh = edgeLow * 2.5;
    float sc = ss_step(edgeLow, edgeHigh, margin);
    float baseRemove = 0.50 * uSmooth + 0.04;
    float removal = clamp(baseRemove * skin * (1.0 - sc), 0.0, 1.0);
    rgb = base + det * (1.0 - removal);
  }

  // 4) 暗角：单一解析式（中心不变、边缘渐变，与成片逐像素一致）
  if (uVignette > 0.0) {
    vec2 ph = uv * 2.0 - 1.0; // -1..1
    float dn = length(ph) * 0.70710678;
    float ff = 1.0 - uVignette * ss_step(0.45, 1.0, dn);
    rgb *= ff;
  }

  fragColor = vec4(clamp(rgb, 0.0, 1.0), 1.0);
}