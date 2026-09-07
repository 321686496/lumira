#version 460 core
#include <flutter/runtime_effect.glsl>

// 编辑页（拍摄预览/相册）细节效果实时预览统一 shader：单 pass 完成
//   拉腿(反向映射几何) → 锐化(亮度死区 Unsharp) → 颗粒(tile+亮度幅度) →
//   磨皮(十字高斯频率分离+YCbCr肤色+结构门控) → 暗角(解析径向)。
//
// 数值语义与四端统一规格一致（dart_photo_pipeline.applyPerPixelEffectsImg /
// photo_processor.cpp / preview_fx.cpp / iOS PreviewEffectProcessor）：
//   - 锐化：a = v/100×6.0（上限 6.0，由外层折算传入 uSharpenA），
//     死区 thr=0.75/255，边缘门控 smoothstep(0.75/255, 2.25/255, |diff|)；
//   - 颗粒：预置 128×128 tile（uNoise，外层 LCG 种子 0x85EBCA6B 生成，
//     与 OHOS C++ / iOS 原生同分布），采样相位 offset (13,29)，
//     幅度 = uGrain×24/255×mix(0.35,1.0,smoothstep(0.05,0.85,luma))；
//   - 磨皮：9-tap 十字高斯低频（radius=2+3s，与 skin_smooth.frag /
//     成片 GPU 磨皮同源），肤色掩膜 YCbCr 扩展区间 + 结构门控；
//   - 暗角：factor = 1−s·smoothstep(0.45,1.0,dn)，dn=length(归一径向)/√2；
//   - 拉腿：与 applyLegStretchImg 同几何——锚点 0.60（源高），满档整体
//     高度 +20%，过渡带 0.12 smoothstep 混合，反向映射 + 双线性。
//
// 坐标约定（与 skin_smooth.frag 相同，已在真机验证）：
//   uv = FlutterFragCoord().xy / uSize，GL 原点在左下；
//   texture 采样直接用该 uv（图像 v=0 对应底行）。
//   拉腿反向映射把「输出像素 y（图像语义顶 0）」折算回源图采样 v。

uniform vec2 uSize;        // 输出画布尺寸（px）
uniform vec2 uFrameSize;   // 源图尺寸（px，效果 texel/颗粒密度基准）
uniform float uSharpenA;   // 锐化增量 a=v/100×6.0（-6..6，负=软化）
uniform float uVignette;   // 暗角增量（-1..1，负=提亮四角）
uniform float uSmooth;     // 磨皮增量（0..1，负为无效果——烘焙磨皮无法撤销）
uniform float uGrain;      // 颗粒增量（-1..1，负=反相噪声）
uniform float uLegStretch; // 拉腿增量（-1..1，负=压缩回去）
uniform sampler2D uTexture; // 源图（编辑页照片，已烘焙基线效果）
uniform sampler2D uNoise;   // 128×128 噪声 tile

out vec4 fragColor;

float ss_step(float e0, float e1, float x) {
  float t = clamp((x - e0) / (e1 - e0), 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  const vec3 L = vec3(0.299, 0.587, 0.114);
  vec2 texel = 1.0 / uFrameSize;

  // 0) 拉腿反向映射：输出图（高 hOut）像素 → 源图像素（几何与
  //    applyLegStretchImg 逐行对应：anchor=0.60h、feather=0.12）。
  float srcV = uv.y;
  if (uLegStretch != 0.0) {
    float hSrc = uFrameSize.y;
    float hOut = hSrc * (1.0 + uLegStretch * 0.20);
    // 输出图像素 y（图像语义：顶部 0），GL v 底 0 顶 1
    float yOut = (1.0 - uv.y) * hOut;
    float anchor = 0.60 * hSrc;
    float srcY;
    if (yOut <= anchor) {
      srcY = yOut;
    } else {
      float srcRegion = hSrc - anchor;
      float destRegion = hOut - anchor;
      float t = (yOut - anchor) / destRegion;
      float stretched = anchor + t * srcRegion;
      const float feather = 0.12;
      if (t < feather) {
        // 过渡带：与「不拉伸」smoothstep 混合，消除锚点硬折线
        float b = ss_step(0.0, 1.0, t / feather);
        srcY = stretched * b + yOut * (1.0 - b);
      } else {
        srcY = stretched;
      }
    }
    srcV = 1.0 - clamp(srcY / hSrc, 0.0, 1.0);
  }
  vec2 suv = vec2(uv.x, srcV);
  vec3 rgb = texture(uTexture, suv).rgb;
  vec2 cp = clamp(suv, texel, vec2(1.0) - texel);

  // 1) 锐化：亮度域死区 Unsharp（4 邻域均值，死区/门控四端统一）。
  //    a<0（增量负）→ 负增益软化，近似“低于烘焙基线”。
  if (uSharpenA != 0.0) {
    float l0 = dot(rgb, L);
    float mn = ( dot(texture(uTexture, cp + vec2(0.0, -texel.y)).rgb, L)
               + dot(texture(uTexture, cp + vec2(0.0,  texel.y)).rgb, L)
               + dot(texture(uTexture, cp + vec2(-texel.x, 0.0)).rgb, L)
               + dot(texture(uTexture, cp + vec2( texel.x, 0.0)).rgb, L) ) * 0.25;
    float diff = l0 - mn;
    float thr = 0.75 / 255.0;
    float amnt = 0.0;
    if (diff > thr) amnt = uSharpenA * (diff - thr);
    else if (diff < -thr) amnt = uSharpenA * (diff + thr);
    float edge = ss_step(0.75 / 255.0, 2.25 / 255.0, abs(diff));
    rgb += amnt * edge;
  }

  // 2) 颗粒：源坐标 × tile 周期（拉腿仅拉伸下方 40%，用源坐标保证颗粒
  //    密度与成片一致，不随拉伸区变稀）。增量负 → 反相噪声近似减颗粒。
  if (uGrain != 0.0) {
    vec2 fpx = suv * uFrameSize;
    vec2 ntex = vec2(mod(fpx.x + 13.0, 128.0), mod(fpx.y + 29.0, 128.0));
    float g = texture(uNoise, ntex / 128.0).r;
    float ls = mix(0.35, 1.0, ss_step(0.05, 0.85, dot(rgb, L)));
    float amp = uGrain * (24.0 / 255.0) * ls;
    rgb += (g * 2.0 - 1.0) * amp;
  }

  // 3) 磨皮：9-tap 十字高斯低频 + YCbCr 肤色 + 结构门控
  //    （radius=2+3s，与 skin_smooth.frag / 成片 GPU 磨皮同源）
  if (uSmooth > 0.0) {
    float radius = 2.0 + 3.0 * uSmooth;
    vec3 base = vec3(0.0);
    float wSum = 0.0;
    for (int i = -4; i <= 4; i++) {
      float w = exp(-float(i * i) / (2.0 * radius * radius));
      base += texture(uTexture, cp + vec2(float(i), 0.0) * texel).rgb * w;
      wSum += w;
    }
    for (int i = -4; i <= 4; i++) {
      float w = exp(-float(i * i) / (2.0 * radius * radius));
      base += texture(uTexture, cp + vec2(0.0, float(i)) * texel).rgb * w;
      wSum += w;
    }
    base /= wSum;
    vec3 det = rgb - base;
    float margin = max(max(abs(det.r), abs(det.g)), abs(det.b));
    float y  = dot(rgb, L);
    float cb = (-0.168736 * rgb.r - 0.331264 * rgb.g + 0.5 * rgb.b) + 0.5;
    float cr = ( 0.5 * rgb.r - 0.418688 * rgb.g - 0.081312 * rgb.b) + 0.5;
    float skin = ss_step( 40.0 / 255.0,  60.0 / 255.0, y) * (1.0 - ss_step(250.0 / 255.0, 255.0 / 255.0, y))
               * ss_step(128.0 / 255.0, 140.0 / 255.0, cr) * (1.0 - ss_step(172.0 / 255.0, 186.0 / 255.0, cr))
               * ss_step( 70.0 / 255.0,  85.0 / 255.0, cb) * (1.0 - ss_step(120.0 / 255.0, 132.0 / 255.0, cb));
    float edgeLow = (6.0 + uSmooth * 6.0) / 255.0;
    float sc = ss_step(edgeLow, edgeLow * 2.5, margin);
    float removal = clamp((0.50 * uSmooth + 0.04) * skin * (1.0 - sc), 0.0, 1.0);
    rgb = base + det * (1.0 - removal);
  }

  // 4) 暗角：输出画布解析径向（与成片 A.3 同公式）。增量负 → 提亮四角
  //    近似抵消烘焙暗角。
  if (uVignette != 0.0) {
    vec2 ph = uv * 2.0 - 1.0;
    float dn = length(ph) * 0.70710678;
    float ff = 1.0 - uVignette * ss_step(0.45, 1.0, dn);
    rgb *= ff;
  }

  fragColor = vec4(clamp(rgb, 0.0, 1.0), 1.0);
}
