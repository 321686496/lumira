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
 *                matrix: Float64Array(20), sharpen: number, mirror: boolean) : ArrayBuffer
 *   swapRgba(rgba: Uint8Array, byteLen: number) : void   // 原地 R/B 对调（水印用）
 */
#include "napi/native_api.h"
#include <cstring>
#include <cmath>
#include <cstdlib>

// 由 ArkTS 侧执行，匹配旧实现：mirror 取源、矩阵、R/B 复原写回（R/B 复原为补偿
// createPixelMap(RGBA_8888) + ImagePacker 把缓冲 R/B 解释对调的硬件怪癖）
static napi_value ProcessRgba(napi_env env, napi_callback_info info) {
  size_t argc = 6;
  napi_value argv[6];
  napi_status status = napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  if (status != napi_ok || argc < 6) {
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
  uint8_t* final = out;
  if (sharpen > 0) {
    double a = (double)sharpen / 100.0;
    if (a > 1.0) a = 1.0;
    const double edgeThr = 4.0;
    uint8_t* conv = (uint8_t*)malloc(outLen);
    if (!conv) {
      free(out);
      return nullptr;
    }
    for (int oy = 0; oy < height; ++oy) {
      const int y0 = oy > 0 ? oy - 1 : oy;
      const int y1 = oy < height - 1 ? oy + 1 : oy;
      const uint32_t crow = ((uint32_t)oy * (uint32_t)width) << 2;
      for (int ox = 0; ox < width; ++ox) {
        const int x0 = ox > 0 ? ox - 1 : ox;
        const int x1 = ox < width - 1 ? ox + 1 : ox;
        const size_t ci = crow + ((size_t)ox << 2);
        const size_t ui = ((size_t)y0 * (size_t)width + (size_t)ox) << 2;
        const size_t dic = ((size_t)y1 * (size_t)width + (size_t)ox) << 2;
        const size_t li = ((size_t)oy * (size_t)width + (size_t)x0) << 2;
        const size_t ri = ((size_t)oy * (size_t)width + (size_t)x1) << 2;
        for (int ch = 0; ch < 3; ++ch) {
          const double c0 = out[ci + ch];
          const double mm = (out[ui + ch] + out[dic + ch] + out[li + ch] + out[ri + ch]) * 0.25;
          const double diff = c0 - mm;
          double v = c0;
          if (diff > edgeThr) {
            v = c0 + a * (diff - edgeThr);
          } else if (diff < -edgeThr) {
            v = c0 + a * (diff + edgeThr);
          }
          if (v > 255) v = 255; else if (v < 0) v = 0;
          conv[ci + ch] = (uint8_t)llround(v);
        }
        conv[ci + 3] = 255;
      }
    }
    free(out);
    final = conv;
  }

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