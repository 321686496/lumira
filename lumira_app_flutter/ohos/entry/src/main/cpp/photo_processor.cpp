/**
 * photo_processor NAPI 原生模块（libphoto_processor.so）
 *
 * 触发背景：OHOS 后处理里「色彩矩阵 + 前置镜像 + R/B 复原 + 边缘自适应锐化」在
 * ArkTS 里是逐像素循环（170 万像素实测 ~5s，JIT/AOT 均无法进 800ms 目标）。
 * 解码/编码继续走系统 ImageSource/ImagePacker 硬管线，从 C++ 侧返回处理后的
 * RGBA 缓冲，全程保持与旧 ArkTS 逐像素实现一致的数值语义，避免颜色/清晰度漂移。
 *
 * 导出给 ArkTS 的两个函数：
 *   processRgba(rgba: Uint8Array, width: number, height: number,
 *                matrix: Float64Array(20), sharpen: number, mirror: boolean,
 *                smooth: number (0-100 磨皮强度，0=关闭),
 *                vignette: number (0-100 暗角强度，0=关闭),
 *                grain: number (0-100 颗粒强度，0=关闭)) : ArrayBuffer
 *   swapRgba(rgba: Uint8Array, byteLen: number) : void   // 原地 R/B 对调（水印用）
 *
 * 磨皮（smooth>0）：用「频率分离削细节 + 肤色掩膜 + 结构门控」在【全分辨率】RGBA 缓冲上做
 * 自然磨皮（保留肤质）。关键设计：低频底图 base 先在降采样分辨率逐个块求平均 + 高斯模糊，
 * 再双线性升采样回全分辨率作为低频保底；随后逐像素 out = 原图 − detail×removal（detail=原图−base），
 * removal=baseRemove×肤色概率×(1−结构门控)。平坦肤区把毛孔/瑕疵这类高频颗粒磨掉，非肤色/强结构
 * （五官/轮廓/背景）removal≈0 原样保留 → 只磨细粒、不碰结构、脸不变糊。数值语义与三条管线一致。
 * 字节序注意：processRgba 的回传缓冲采用 [B,G,R,A] 次序（补偿硬件 R/B 对调怪癖），
 * 磨皮 pass 必须按此布局处理，gaussianBlur / 肤色概率 / 结构门控逻辑保持一致。
 */
#include "napi/native_api.h"
#include <cstring>
#include <cmath>
#include <cstdlib>
#include <cstdint>

// ── 平滑步进（smoothstep，与 Dart SkinSmoother 一致）──
static inline double ss(double x, double e0, double e1) {
  double t = (x - e0) / (e1 - e0);
  if (t < 0.0) t = 0.0; else if (t > 1.0) t = 1.0;
  return t * t * (3.0 - 2.0 * t);
}

// ── YCbCr 肤色概率 0..1（BT.601，与 Dart SkinSmoother 区间一致）──
// 入参为实际的 r/g/b 0-255。字节序由调用方保证按实际颜色传参。
// 区间为放宽版（Cb[70,132]、Cr[128,186]、亮度[40,250]）：较窄盒（Cb[77,127]/Cr[133,173]）
// 会漏掉阴影/暗光/深层/偏色皮肤 → 大块皮肤磨不到，表现为"只局部糊、没整体磨皮效果"。
static inline double skinWeight(double r, double g, double b) {
  const double y  = 0.299 * r + 0.587 * g + 0.114 * b;
  const double cb = (-0.168736 * r - 0.331264 * g + 0.5 * b) + 128.0;
  const double cr = (0.5 * r - 0.418688 * g - 0.081312 * b) + 128.0;
  const double yw  = ss(y, 40, 60) * (1.0 - ss(y, 250, 255));
  const double crw = ss(cr, 128, 140) * (1.0 - ss(cr, 172, 186));
  const double cbw = ss(cb, 70, 85) * (1.0 - ss(cb, 120, 132));
  return yw * crw * cbw;
}

// ── 字节值 clamp（0-255）──
static inline uint8_t bc(double v) {
  if (v > 255.0) v = 255.0;
  else if (v < 0.0) v = 0.0;
  return (uint8_t)llround(v);
}

// ── 分离式高斯模糊（作用于 RGBA，仅平滑 RGB，不碰 A）──
// rgba / dst 同尺寸。radius：2..8。σ = radius/2。
static void gaussianBlurRgba(const uint8_t* rgba, int w, int h, int radius, uint8_t* dst) {
  const int k = 2 * radius + 1;
  const double sigma = radius / 2.0;
  double* wgt = (double*)malloc((size_t)k * sizeof(double));
  if (!wgt) { memcpy(dst, rgba, (size_t)w * (size_t)h * 4); return; }
  double sw = 0.0;
  for (int i = -radius; i <= radius; i++) {
    const double v = std::exp(-(double)(i * i) / (2.0 * sigma * sigma));
    wgt[i + radius] = v; sw += v;
  }
  for (int i = 0; i < k; i++) wgt[i] /= sw;

  const size_t stride = (size_t)w * 4;
  uint8_t* tmp = (uint8_t*)malloc((size_t)w * (size_t)h * 4);
  if (!tmp) { free(wgt); memcpy(dst, rgba, (size_t)w * (size_t)h * 4); return; }

  // 水平 pass rgba -> tmp
  for (int y = 0; y < h; y++) {
    const uint8_t* row = rgba + (size_t)y * stride;
    uint8_t* orow = tmp + (size_t)y * stride;
    for (int x = 0; x < w; x++) {
      double r = 0, g = 0, b = 0;
      for (int i = -radius; i <= radius; i++) {
        int xi = x + i; if (xi < 0) xi = 0; else if (xi >= w) xi = w - 1;
        const uint8_t* p = row + (size_t)xi * 4;
        const double wt = wgt[i + radius];
        r += p[0] * wt;  // B
        g += p[1] * wt;  // G
        b += p[2] * wt;  // R
      }
      uint8_t* o = orow + (size_t)x * 4;
      o[0] = bc(r);
      o[1] = bc(g);
      o[2] = bc(b);
    }
  }
  // 垂直 pass tmp -> dst
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      double r = 0, g = 0, b = 0;
      for (int i = -radius; i <= radius; i++) {
        int yi = y + i; if (yi < 0) yi = 0; else if (yi >= h) yi = h - 1;
        const uint8_t* p = tmp + (size_t)yi * stride + (size_t)x * 4;
        const double wt = wgt[i + radius];
        r += p[0] * wt;
        g += p[1] * wt;
        b += p[2] * wt;
      }
      uint8_t* o = dst + (size_t)y * stride + (size_t)x * 4;
      o[0] = bc(r);
      o[1] = bc(g);
      o[2] = bc(b);
    }
  }
  free(wgt);
  free(tmp);
}

// ── 盒平均降采样 RGBA（src(w,h) → dst(dw,dh)，仅 RGB，不碰 A）──
// 每个 dst 像素取源上对应矩形块内 RGB 平均值。
static void downscaleRgba(const uint8_t* src, int sw, int sh, int dw, int dh, uint8_t* dst) {
  for (int dy = 0; dy < dh; dy++) {
    int y0 = (int)((double)dy * sh / dh);
    int y1 = (int)((double)(dy + 1) * sh / dh);
    if (y1 <= y0) y1 = y0 + 1; if (y1 > sh) y1 = sh;
    for (int dx = 0; dx < dw; dx++) {
      int x0 = (int)((double)dx * sw / dw);
      int x1 = (int)((double)(dx + 1) * sw / dw);
      if (x1 <= x0) x1 = x0 + 1; if (x1 > sw) x1 = sw;
      long r = 0, g = 0, b = 0; int n = 0;
      for (int y = y0; y < y1; y++) {
        for (int x = x0; x < x1; x++) {
          const uint8_t* p = src + ((size_t)y * sw + x) * 4;
          r += p[0]; g += p[1]; b += p[2]; n++;
        }
      }
      uint8_t* o = dst + ((size_t)dy * dw + dx) * 4;
      o[0] = (uint8_t)(r / n); o[1] = (uint8_t)(g / n); o[2] = (uint8_t)(b / n);
    }
  }
}

// ── 双线性升采样 RGBA（src(sw,sh) → dst(dw,dh)，仅 RGB，不碰 A）──
static void upscaleRgba(const uint8_t* src, int sw, int sh, int dw, int dh, uint8_t* dst) {
  for (int dy = 0; dy < dh; dy++) {
    double fy0 = (dy + 0.5) * sh / dh - 0.5; if (fy0 < 0.0) fy0 = 0.0;
    int yi = (int)fy0; if (yi > sh - 2) yi = sh - 2; if (yi < 0) yi = 0;
    double wy = fy0 - yi;
    for (int dx = 0; dx < dw; dx++) {
      double fx0 = (dx + 0.5) * sw / dw - 0.5; if (fx0 < 0.0) fx0 = 0.0;
      int xi = (int)fx0; if (xi > sw - 2) xi = sw - 2; if (xi < 0) xi = 0;
      double wx = fx0 - xi;
      const uint8_t* p00 = src + ((size_t)yi * sw + xi) * 4;
      const uint8_t* p10 = p00 + 4;
      const uint8_t* p01 = src + ((size_t)(yi + 1) * sw + xi) * 4;
      const uint8_t* p11 = p01 + 4;
      double w00 = (1.0 - wx) * (1.0 - wy);
      double w10 = wx * (1.0 - wy);
      double w01 = (1.0 - wx) * wy;
      double w11 = wx * wy;
      for (int c = 0; c < 3; c++) {
        double v = p00[c] * w00 + p10[c] * w10 + p01[c] * w01 + p11[c] * w11;
        dst[((size_t)dy * dw + dx) * 4 + c] = bc(v);
      }
    }
  }
}

// ── 磨皮（频率分离削细节·自然保留肤质），原地修改 rgba（[B,G,R,A] 布局）──
// 与 Dart SkinSmoother 数值语义完全一致（保低频结构、削高频毛孔、结构门控保护五官）。
// 低频底图在降采样分辨率模糊再升采样回全分辨率 → 计算量比全分辨率模糊降一个数量级。
// out = original − detail × removal：
//   - removal = baseRemove × 肤色概率 × (1 − 结构门控)，结构门控=smoothstep(|detail|)
//   - 平坦肤区 → removal≈baseRemove×skin（磨掉毛孔），removal≤0.6 → 保留肤质不塑料
//   - 强结构/五官边缘 → 门控→1，removal→0，细节全留（锐利）
//   - 非肤色 → skin→0，removal→0 → 像素原样（100% 保留）
static void smoothSkin(uint8_t* rgba, int w, int h, int strengthInt) {
  if (strengthInt <= 0) return;
  double strength = (double)strengthInt / 100.0;
  if (strength > 1.0) strength = 1.0;
  if (strength <= 0.01) return;

  const double downFactor = 3.0;
  int dw = (int)llround(w / downFactor); if (dw < 1) dw = 1;
  int dh = (int)llround(h / downFactor); if (dh < 1) dh = 1;

  uint8_t* small = (uint8_t*)malloc((size_t)dw * (size_t)dh * 4);
  uint8_t* lowSm = (uint8_t*)malloc((size_t)dw * (size_t)dh * 4);
  uint8_t* base  = (uint8_t*)malloc((size_t)w * (size_t)h * 4);
  if (!small || !lowSm || !base) {
    if (small) free(small);
    if (lowSm) free(lowSm);
    if (base) free(base);
    return;
  }

  downscaleRgba(rgba, w, h, dw, dh, small);
  // 低频半径 2..5（降采样后尺寸）：只去掉高频毛孔，保留低频明暗结构。
  int radius = (int)llround(2.0 + strength * 3.0);
  if (radius < 2) radius = 2; if (radius > 5) radius = 5;
  gaussianBlurRgba(small, dw, dh, radius, lowSm);
  upscaleRgba(lowSm, dw, dh, w, h, base);
  free(small);
  free(lowSm);

  const double baseRemove = 0.50 * strength + 0.04; // 0.04..0.54（自然向，保留肤质不塑料）
  const double edgeLow = 6.0 + strength * 6.0; // 结构阈值下限
  const double edgeHigh = edgeLow * 2.5; // 结构阈值上限（更灵敏，强保护五官边缘/肩部）

  const size_t nPix = (size_t)w * (size_t)h;
  for (size_t i = 0; i < nPix; i++) {
    const uint8_t* p = rgba + i * 4;
    const uint8_t* b = base + i * 4;
    // 布局 [B,G,R,A]：实际 B=p[0]，G=p[1]，R=p[2]
    const double r = p[2], g = p[1], bl = p[0];
    const double br = b[2], bg = b[1], bb = b[0];
    const double dr = std::fabs(r - br);
    const double dg = std::fabs(g - bg);
    const double db = std::fabs(bl - bb);
    double margin = dr; if (dg > margin) margin = dg; if (db > margin) margin = db;

    const double skin = skinWeight(r, g, bl);
    const double t = (margin - edgeLow) / (edgeHigh - edgeLow);
    double sc = t; if (sc < 0.0) sc = 0.0; else if (sc > 1.0) sc = 1.0;
    sc = sc * sc * (3.0 - 2.0 * sc); // smoothstep 结构门控

    double removal = baseRemove * skin * (1.0 - sc);
    if (removal > 1.0) removal = 1.0; else if (removal < 0.0) removal = 0.0;
    if (removal <= 0.001) continue; // 非肤色 / 强结构 → 原样保留

    const double keep = 1.0 - removal;
    uint8_t* o = rgba + i * 4;
    o[0] = (uint8_t)llround(bb + (bl - bb) * keep); // B = base + detail×keep
    o[1] = (uint8_t)llround(bg + (g  - bg) * keep); // G
    o[2] = (uint8_t)llround(br + (r  - br) * keep); // R
  }
  free(base);
}

// ── 暗角（径向边缘压暗，[B,G,R,A] 布局，原地修改）──
// 中心不压、越靠边越暗，factor = 1 − s·smoothstep(dn, e0, e1)。
// 归一径向距离 dn：中心 0、对角顶点 ~1（除以 sqrt(2)）。幂等叠加在色彩矩阵之后。
static void applyVignette(uint8_t* rgba, int w, int h, int strength) {
  if (strength <= 0) return;
  double s = (double)strength / 100.0; if (s > 1.0) s = 1.0;
  const double e0 = 0.45, e1 = 1.0;            // 暗角起止区间（归一径向）
  const double invMax = 1.0 / std::sqrt(2.0);  // 对角归一化
  const double hw = w * 0.5, hh = h * 0.5;
  for (int oy = 0; oy < h; ++oy) {
    const double dy = (oy + 0.5 - hh) / hh;    // -1..1
    for (int ox = 0; ox < w; ++ox) {
      const double dx = (ox + 0.5 - hw) / hw;  // -1..1
      const double dn = std::sqrt(dx * dx + dy * dy) * invMax; // 0..~1
      double t = (dn - e0) / (e1 - e0);
      if (t < 0.0) t = 0.0; else if (t > 1.0) t = 1.0;
      const double factor = 1.0 - s * (t * t * (3.0 - 2.0 * t)); // 1-s·smoothstep
      uint8_t* p = rgba + ((size_t)oy * (size_t)w + (size_t)ox) * 4;
      p[0] = (uint8_t)llround(p[0] * factor); // B
      p[1] = (uint8_t)llround(p[1] * factor); // G
      p[2] = (uint8_t)llround(p[2] * factor); // R
    }
  }
}

// ── 颗粒：预计算 128×128 白噪声 tile（每进程一次）+ 双线性 + 幅度随亮度缩放 ──
// 消除旧实现两个问题：① ±24 均匀平噪（观感差 → 无胶片感）；② 逐像素 LCG（无法被
// 预览 FragmentShader 复用，导致预览与成片颗粒不一致）。改为一次性固定种子的 128×128
// tile 表，预览 shader 与成片共用同一张表 + 固定 offset → 三端颗粒语义一致且零逐帧开销。
static const int kGrainTex = 128;
static float g_grainTile[kGrainTex * kGrainTex];
static bool g_grainInit = false;
static void ensureGrainTile() {
  if (g_grainInit) return;
  g_grainInit = true;
  uint32_t seed = 0x85EBCA6Bu; // 固定种子（与旧 LCG 同种子族，可复现）
  for (int i = 0; i < kGrainTex * kGrainTex; ++i) {
    seed = seed * 1664525u + 1013904223u;
    const double rnd = (double)((seed >> 8) & 0xFFFFu) * (1.0 / 65535.0); // 0..1
    g_grainTile[i] = (float)(rnd * 2.0 - 1.0); // -1..1
  }
}

// 灰阶 ≈ 1 像素细颗粒：uv 用 ox*invTex + 固定 offset（tile 周期性重复），双线性采样。
static void applyGrain(uint8_t* rgba, int w, int h, int strength) {
  if (strength <= 0) return;
  ensureGrainTile();
  double s = (double)strength / 100.0; if (s > 1.0) s = 1.0;
  const double kFilm = 24.0; // 峰值幅度 ±24/255（与旧满强度一致）
  const double invTex = 1.0 / (double)kGrainTex; // 1 texel/像素
  const double uOff = 13.0 * invTex, vOff = 29.0 * invTex; // 每会话固定 offset
  const size_t nPix = (size_t)w * (size_t)h;
  for (size_t i = 0; i < nPix; ++i) {
    const size_t oy = i / (size_t)w;
    const size_t ox = i - oy * (size_t)w;
    const uint8_t* p = rgba + i * 4;
    // 布局 [B,G,R,A]：R=p[2], G=p[1], B=p[0]
    const double luma = 0.299 * p[2] + 0.587 * p[1] + 0.114 * p[0]; // 0..255
    const double ln = luma / 255.0;
    double lw = (ln - 0.05) / (0.85 - 0.05);
    if (lw < 0.0) lw = 0.0; else if (lw > 1.0) lw = 1.0;
    const double lumaScale = 0.35 + 0.65 * (lw * lw * (3.0 - 2.0 * lw)); // mix(0.35,1.0,smoothstep)
    const double amp = s * kFilm * lumaScale; // 幅度随亮度增大（胶片感）

    double u = (double)ox * invTex + uOff;
    double v = (double)oy * invTex + vOff;
    u -= std::floor(u); v -= std::floor(v);
    double xp = u * kGrainTex - 0.5; int x0 = (int)std::floor(xp); double wx = xp - x0;
    double yp = v * kGrainTex - 0.5; int y0 = (int)std::floor(yp); double wy = yp - y0;
    auto wrap = [](int x) { return ((x % kGrainTex) + kGrainTex) % kGrainTex; };
    const int x1 = wrap(x0 + 1), y1 = wrap(y0 + 1);
    x0 = wrap(x0); y0 = wrap(y0);
    const double g00 = g_grainTile[(size_t)y0 * kGrainTex + x0];
    const double g10 = g_grainTile[(size_t)y0 * kGrainTex + x1];
    const double g01 = g_grainTile[(size_t)y1 * kGrainTex + x0];
    const double g11 = g_grainTile[(size_t)y1 * kGrainTex + x1];
    const double gval = g00 * (1 - wx) * (1 - wy) + g10 * wx * (1 - wy)
                      + g01 * (1 - wx) * wy + g11 * wx * wy;
    const double off = gval * amp; // [-1,1]*amp
    uint8_t* o = rgba + i * 4;
    for (int c = 0; c < 3; c++) {
      double vv = p[c] + off;
      if (vv > 255.0) vv = 255.0; else if (vv < 0.0) vv = 0.0;
      o[c] = (uint8_t)llround(vv);
    }
  }
}

// 由 ArkTS 侧执行，匹配旧实现：mirror 取源、矩阵、R/B 复原写回（R/B 复原为补偿
// createPixelMap(RGBA_8888) + ImagePacker 把缓冲 R/B 解释对调的硬件怪癖）
static napi_value ProcessRgba(napi_env env, napi_callback_info info) {
  size_t argc = 9;
  napi_value argv[9];
  napi_status status = napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  if (status != napi_ok || argc < 9) {
    return nullptr;
  }

  // ── 输入 RGBA（uint8 typed array）──
  bool isTyped = false;
  napi_is_typedarray(env, argv[0], &isTyped);
  if (!isTyped) return nullptr;
  napi_typedarray_type srcType;
  size_t srcLen = 0;
  void* srcData = nullptr;
  napi_value srcArrBuf;
  size_t srcOffset = 0;
  status = napi_get_typedarray_info(env, argv[0], &srcType, &srcLen, &srcData, &srcArrBuf, &srcOffset);
  if (status != napi_ok || srcType != napi_uint8_array || srcData == nullptr) {
    return nullptr;
  }

  int32_t width = 0;
  int32_t height = 0;
  napi_get_value_int32(env, argv[1], &width);
  napi_get_value_int32(env, argv[2], &height);
  if (width <= 0 || height <= 0) return nullptr;
  uint64_t n = (uint64_t)width * (uint64_t)height;
  if (n * 4 != srcLen) return nullptr;

  // ── 色彩矩阵（float64，>=20）──
  bool mIsTyped = false;
  napi_is_typedarray(env, argv[3], &mIsTyped);
  if (!mIsTyped) return nullptr;
  napi_typedarray_type mType;
  size_t mLen = 0;
  void* mData = nullptr;
  napi_value mArrBuf;
  size_t mOffset = 0;
  status = napi_get_typedarray_info(env, argv[3], &mType, &mLen, &mData, &mArrBuf, &mOffset);
  if (status != napi_ok || mType != napi_float64_array || mData == nullptr || mLen < 20) {
    return nullptr;
  }
  const double* m = (const double*)mData;

  int32_t sharpen = 0;
  napi_get_value_int32(env, argv[4], &sharpen);

  bool mirror = false;
  napi_get_value_bool(env, argv[5], &mirror);

  // ── 磨皮强度（0-100，0=关闭）──
  int32_t smooth = 0;
  napi_get_value_int32(env, argv[6], &smooth);
  if (smooth < 0) smooth = 0;
  if (smooth > 100) smooth = 100;

  // ── 暗角强度（0-100，0=关闭）──
  int32_t vignette = 0;
  napi_get_value_int32(env, argv[7], &vignette);
  if (vignette < 0) vignette = 0;
  if (vignette > 100) vignette = 100;

  // ── 颗粒强度（0-100，0=关闭）──
  int32_t grain = 0;
  napi_get_value_int32(env, argv[8], &grain);
  if (grain < 0) grain = 0;
  if (grain > 100) grain = 100;

  const size_t outLen = (size_t)n * 4;
  const uint8_t* src = (const uint8_t*)srcData;

  // ── Pass 1：前置镜像 + 色彩矩阵 + R/B 复原（写入次序 [B,G,R,A]）──
  uint8_t* out = (uint8_t*)malloc(outLen);
  if (!out) return nullptr;
  for (int oy = 0; oy < height; ++oy) {
    const uint32_t rowBase = (uint32_t)oy * (uint32_t)width;
    const uint32_t dro = rowBase * 4;
    for (int ox = 0; ox < width; ++ox) {
      const uint32_t si = (rowBase + (mirror ? (uint32_t)(width - 1 - ox) : (uint32_t)ox)) * 4;
      const double r = src[si];
      const double g = src[si + 1];
      const double b = src[si + 2];

      double nr = m[0] * r + m[1] * g + m[2] * b + m[3] * 255.0 + m[4];
      double ng = m[5] * r + m[6] * g + m[7] * b + m[8] * 255.0 + m[9];
      double nb = m[10] * r + m[11] * g + m[12] * b + m[13] * 255.0 + m[14];
      if (nr < 0) nr = 0; else if (nr > 255) nr = 255;
      if (ng < 0) ng = 0; else if (ng > 255) ng = 255;
      if (nb < 0) nb = 0; else if (nb > 255) nb = 255;

      const uint32_t di = dro + (uint32_t)ox * 4;
      out[di]     = (uint8_t)llround(nb);  // 写蓝
      out[di + 1] = (uint8_t)llround(ng);  // 写绿
      out[di + 2] = (uint8_t)llround(nr);  // 写红
      out[di + 3] = 255;
    }
  }

  // ── Pass 2：边缘自适应锐化（Unsharp 死区版，仅锐化超阈值边缘，平坦区原样）──
  // 效果顺序与 Dart 慢管线（CaptureWorker）完全一致：矩阵 → 锐化 → 颗粒 → 磨皮 → 暗角
  // （clarity 已折进色彩矩阵，无需单独 pass）；这样 OHOS 原生快路径与慢管线成片视觉一致。
  uint8_t* final = out;
  if (sharpen > 0) {
    // 亮度域死区 Unsharp（与预览 FragmentShader 同一公式）：
    //   luma = 0.299R+0.587G+0.114B；lumaBlur = 4 邻域均值；
    //   diff = luma - lumaBlur；edge = smoothstep(1.0, 2.5, |diff|)；
    //   amnt = a×(diff>thr ? diff-thr : diff<-thr ? diff+thr : 0)，a=clamp(sharpen/100,0,1.2)
    // 亮度方向统一增益 → 色相不变、平坦区不放大颗粒；死区 1.0 让锐化重新咬合真实边缘。
    double a = (double)sharpen / 100.0;
    if (a > 1.2) a = 1.2; if (a < 0.0) a = 0.0;
    const double thr = 1.0;    // 死区下界（0-255 亮度差）
    const double e0 = 1.0, e1v = 2.5; // 边缘门控 smoothstep 区间
    uint8_t* conv = (uint8_t*)malloc(outLen);
    if (!conv) { free(out); return nullptr; }
    for (int oy = 0; oy < height; ++oy) {
      const int y0 = oy > 0 ? oy - 1 : oy;
      const int y1 = oy < height - 1 ? oy + 1 : oy;
      const uint32_t crow = ((uint32_t)oy * (uint32_t)width) << 2;
      for (int ox = 0; ox < width; ++ox) {
        const int x0 = ox > 0 ? ox - 1 : ox;
        const int x1 = ox < width - 1 ? ox + 1 : ox;
        const size_t ci  = crow + ((size_t)ox << 2);
        const size_t ui  = ((size_t)y0 * (size_t)width + (size_t)ox) << 2;
        const size_t dic = ((size_t)y1 * (size_t)width + (size_t)ox) << 2;
        const size_t li  = ((size_t)oy * (size_t)width + (size_t)x0) << 2;
        const size_t ri  = ((size_t)oy * (size_t)width + (size_t)x1) << 2;
        // 布局 [B,G,R,A]：R=+2, G=+1, B=+0
        const double c0 = 0.299 * out[ci + 2] + 0.587 * out[ci + 1] + 0.114 * out[ci + 0];
        const double mn = (0.299 * out[ui + 2] + 0.587 * out[ui + 1] + 0.114 * out[ui + 0]
                        + 0.299 * out[dic + 2] + 0.587 * out[dic + 1] + 0.114 * out[dic + 0]
                        + 0.299 * out[li + 2] + 0.587 * out[li + 1] + 0.114 * out[li + 0]
                        + 0.299 * out[ri + 2] + 0.587 * out[ri + 1] + 0.114 * out[ri + 0]) * 0.25;
        const double diff = c0 - mn;
        double amnt = 0.0;
        if (diff > thr) amnt = a * (diff - thr);
        else if (diff < -thr) amnt = a * (diff + thr);
        double ad = std::fabs(diff);
        double et = (ad - e0) / (e1v - e0);
        if (et < 0.0) et = 0.0; else if (et > 1.0) et = 1.0;
        const double edge = et * et * (3.0 - 2.0 * et); // 0..1
        const double gain = amnt * edge;
        for (int ch = 0; ch < 3; ++ch) {
          double v = out[ci + ch] + gain;
          if (v > 255) v = 255; else if (v < 0) v = 0;
          conv[ci + ch] = (uint8_t)llround(v);
        }
        conv[ci + 3] = 255;
      }
    }
    free(out);
    final = conv;
  }

  // ── Pass 3：颗粒（逐像素加性噪声，原地）──
  applyGrain(final, width, height, grain);

  // ── Pass 4：磨皮（肤色掩膜 + 边缘保护，原地平滑；非皮肤/强边缘保留原值）──
  if (smooth > 0) {
    smoothSkin(final, width, height, smooth);
  }

  // ── Pass 5：暗角（径向边缘压暗，原地）──
  applyVignette(final, width, height, vignette);

  napi_value resultBuf;
  void* resultData = nullptr;
  status = napi_create_arraybuffer(env, outLen, &resultData, &resultBuf);
  if (status != napi_ok || resultData == nullptr) {
    free(final);
    return nullptr;
  }
  memcpy(resultData, final, outLen);
  free(final);
  return resultBuf;
}

// 原地对调 RGBA 的 R/B 通道（Uint32 位运算），供水印 encodeJpegFromRgba 解决
// createPixelMap + ImagePacker 的红蓝对调怪癖。与旧 ArkTS Uint32 循环语义一致。
static napi_value SwapRgba(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value argv[2];
  napi_status status = napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  if (status != napi_ok || argc < 2) return nullptr;

  bool isTyped = false;
  napi_is_typedarray(env, argv[0], &isTyped);
  if (!isTyped) return nullptr;
  napi_typedarray_type srcType;
  size_t srcLen = 0;
  void* srcData = nullptr;
  napi_value srcArrBuf;
  size_t srcOffset = 0;
  status = napi_get_typedarray_info(env, argv[0], &srcType, &srcLen, &srcData, &srcArrBuf, &srcOffset);
  if (status != napi_ok || srcType != napi_uint8_array || srcData == nullptr) {
    return nullptr;
  }
  int32_t byteLen = 0;
  napi_get_value_int32(env, argv[1], &byteLen);
  if (byteLen <= 0 || (size_t)byteLen > srcLen) byteLen = (int32_t)srcLen;
  const size_t nPix = (size_t)byteLen / 4;
  uint32_t* p = (uint32_t*)srcData;
  for (size_t i = 0; i < nPix; ++i) {
    const uint32_t v = p[i];
    p[i] = (v & 0xFF00FF00u) | ((v & 0x000000FFu) << 16) | ((v & 0x00FF0000u) >> 16);
  }
  return argv[0];
}

static napi_value Init(napi_env env, napi_value exports) {
  napi_property_descriptor desc[] = {
      { "processRgba", nullptr, ProcessRgba, nullptr, nullptr, nullptr, napi_default, nullptr },
      { "swapRgba", nullptr, SwapRgba, nullptr, nullptr, nullptr, napi_default, nullptr },
  };
  napi_define_properties(env, exports, 2, desc);
  return exports;
}

static napi_module photoProcessorModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "photo_processor",
    .nm_priv = nullptr,
    .reserved = { 0 },
};

extern "C" __attribute__((constructor)) void RegisterPhotoProcessorModule() {
  napi_module_register(&photoProcessorModule);
}