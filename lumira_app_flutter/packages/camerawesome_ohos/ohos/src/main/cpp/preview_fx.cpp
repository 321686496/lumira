/**
 * preview_fx NAPI 原生模块（libpreview_fx.so）— OHOS 取景器实时特效 GPU 管线
 *
 * 触发背景：磨皮/锐化/颗粒/暗角等细节参数此前在 OHOS 取景器中无任何实时效果
 * （Dart 层 ColorFiltered 仅覆盖色彩矩阵；曾被试过的 toImage 读回方案因单帧数百
 * 毫秒而停用）。本模块仿照 iOS PreviewEffectProcessor，在原生侧把「相机预览流 →
 * OpenGL ES 着色器 → Flutter Texture」整链下沉：
 *
 *   相机 PreviewOutput ──写入──▶ OH_NativeImage（消费端，OES 外部纹理）
 *                                     │ 每帧回调唤醒渲染线程
 *                                     ▼
 *                        渲染线程：UpdateSurfaceImage → 效果链着色器
 *                                     │（色彩矩阵→锐化→颗粒→磨皮→暗角，
 *                                     │  数值语义与 iOS 预览内核/photo_processor.cpp 一致）
 *                                     ▼
 *                 EGL 窗口表面（OH_NativeWindow_CreateNativeWindowFromSurfaceId
 *                              从 Flutter 纹理 surfaceId 还原的 NativeWindow）
 *                                     ▼
 *                         Flutter 引擎合成显示（WYSIWYG）
 *
 * 导出给 ArkTS（CameraState.ets）的三个函数：
 *   createPreviewFx(flutterSurfaceId: number, width: number, height: number,
 *                   texWidth: number, texHeight: number): number
 *     创建管线（EGL 上下文、着色器、NativeImage、渲染线程）。
 *     width/height 为输出窗口（Flutter 纹理 surface）几何——竖屏拍摄时应传
 *     「交换后的」预览档位宽高，与 Dart 侧 Texture widget 纵横比一致（同
 *     getEffectivPreviewSize 的交换规则），否则画面被拉伸；texWidth/texHeight
 *     为相机预览缓冲宽高（效果内核的像素基准）。
 *     返回相机侧消费 surfaceId（供 createPreviewOutput 使用）；失败返回 0。
 *   updatePreviewFxParams(hasMatrix: boolean, matrix: Float64Array(20) | null,
 *                         vignette: number, smooth: number,
 *                         sharpen: number, grain: number): void
 *     更新效果参数（vignette/smooth/sharpen/grain 为 0..100 原始强度，
 *     模块内部按规格同一曲线折算：锐化 a=v/100×1.2，其余 v/100）。
 *   destroyPreviewFx(): void — 停渲染线程并释放全部资源。
 *
 * 线程模型：全部 GL/NativeImage/EGL 资源都创建、使用、销毁于渲染线程
 * （OH_NativeImage 系列为非线程安全接口，必须单线程访问）；ArkTS 线程只做
 * 参数写入（互斥锁保护）与生命周期控制。帧到达回调（BufferQueue 线程触发）
 * 仅置原子标志 + 唤醒条件变量，不触碰 GL。
 *
 * 注：本文件注释中不使用嵌套块注释（项目规范）。
 */
#include "napi/native_api.h"
#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>
#include <native_image/native_image.h>
#include <native_window/external_window.h>
#include <native_buffer/buffer_common.h>
#include <hilog/log.h>
#include <atomic>
#include <chrono>
#include <cmath>
#include <condition_variable>
#include <cstring>
#include <mutex>
#include <thread>

#define FX_LOG(fmt, ...) OH_LOG_INFO(LOG_APP, "[preview_fx] " fmt, ##__VA_ARGS__)
#define FX_ERR(fmt, ...) OH_LOG_ERROR(LOG_APP, "[preview_fx] " fmt, ##__VA_ARGS__)

// ── 效果参数（渲染线程每帧快照使用）────────────────────────────────
struct FxParams {
  bool hasMatrix;
  float mR0[4];   // 色彩矩阵第 0 行（Flutter ColorFilter 20 元素布局）
  float mR1[4];   // 第 1 行
  float mR2[4];   // 第 2 行
  float bias[3];  // 偏移列（m4/m9/m14，按 0..255 语义 → 着色器内 /255）
  float sharpen;  // 0..6.0（已折算）
  float smooth;   // 0..1
  float vignette; // 0..1
  float grain;    // 0..1
};

// ── 管线全局状态（单实例：应用同一时刻只有一个活动取景器）──────────
namespace {
struct Pipeline {
  // 生命周期（ArkTS 线程写、渲染线程读）
  std::thread renderThread;
  std::atomic<bool> running{false};
  std::atomic<bool> ready{false};
  std::atomic<bool> initFailed{false};
  std::mutex wakeMtx;
  std::condition_variable wakeCv;
  std::condition_variable readyCv;

  // 帧到达（BufferQueue 回调线程写、渲染线程消费；合并丢弃积压）
  std::atomic<bool> framePending{false};
  // 帧到达计数（追帧用）：UpdateSurfaceImage 为 FIFO 语义——每次调用
  // 只把最老的一帧取入纹理；若 HAL 一次压入多帧或渲染线程被短暂抢占，
  // 不追帧会一直显示「队列深度-1」帧前的旧画面（取景器恒定延迟来源之一）。
  std::atomic<int> pendingCount{0};

  // 延迟诊断（仅渲染线程访问；节流打印）
  uint64_t diagFrames = 0;
  std::chrono::steady_clock::time_point diagLastFrame{};

  // 效果参数（ArkTS 线程写、渲染线程读）
  std::mutex paramMtx;
  FxParams params{};

  // 以下全部仅渲染线程访问
  OH_NativeImage* nativeImage = nullptr;
  OHNativeWindow* targetWindow = nullptr;
  EGLDisplay display = EGL_NO_DISPLAY;
  EGLContext context = EGL_NO_CONTEXT;
  EGLSurface surface = EGL_NO_SURFACE;
  GLuint program = 0;
  // 磨皮频率分离：低频底图 pass（相机纹理→1/3 分辨率 FBO 高斯），主 pass 采样
  GLuint blurProgram = 0;
  GLuint blurFbo = 0;
  GLuint blurTex = 0;
  uint32_t blurWidth = 0;   // FBO 宽（输出窗口几何 1/3）
  uint32_t blurHeight = 0;  // FBO 高
  GLint buTransform = -1;   // blur program 的变换矩阵
  GLint buHasMatrix = -1, buMRow0 = -1, buMRow1 = -1, buMRow2 = -1, buBias = -1;
  GLint buBlurStep = -1;
  GLint aPosBlur = -1;
  GLuint vbo = 0;
  GLuint oesTex = 0;
  GLuint noiseTex = 0;
  GLint uMRow0 = -1, uMRow1 = -1, uMRow2 = -1, uBias = -1;
  GLint uHasMatrix = -1, uSharpen = -1, uSmooth = -1, uVig = -1, uGrain = -1;
  GLint uTexel = -1, uSize = -1;
  GLint uTransform = -1;  // OH_NativeImage 变换矩阵（旋转+翻转）
  uint64_t targetSurfaceId = 0;  // ArkTS 线程在启动前写入
  uint64_t cameraSurfaceId = 0;  // 渲染线程初始化后写入
  uint32_t width = 0;    // 输出窗口宽（竖屏时为交换后的预览宽）
  uint32_t height = 0;   // 输出窗口高
  uint32_t texWidth = 0;   // 相机缓冲宽（效果内核 texel/尺寸基准）
  uint32_t texHeight = 0;  // 相机缓冲高
};
Pipeline g;

// ── 着色器源码 ──────────────────────────────────────────────────────
// 顶点：全屏矩形，采样位置由 OH_NativeImage_GetTransformMatrixV2 返回的
// 变换矩阵决定（与 Flutter 引擎直写路径同一约定：矩阵把「传统 GL 纹理坐标
// 列向量 (s,t,0,1)」映射为缓冲的正确采样位置，已含 GL Y 翻转与相机预览
// 旋转——相机 setPreviewRotation 经 buffer transform 元数据传入。约定同
// Android SurfaceTexture.getTransformMatrix，OHOS NativeImage 为同构 API）。
// 不应用该矩阵时竖屏画面呈传感器横向且被拉伸（本 bug 已修复）。
const char* kVertexShader =
    "attribute vec2 aPos;\n"
    "uniform mat4 uTransformMatrix;\n"
    "varying vec2 vUV;\n"    // 相机纹理空间（含旋转/翻转）
    "varying vec2 vQuad;\n"  // 输出 quad 空间（0..1，变换前）—— 磨皮低频底图采样
    "void main() {\n"
    "  vec2 uv = vec2(aPos.x * 0.5 + 0.5, aPos.y * 0.5 + 0.5);\n"
    "  vQuad = uv;\n"
    "  vUV = (uTransformMatrix * vec4(uv, 0.0, 1.0)).xy;\n"
    "  gl_Position = vec4(aPos, 0.0, 1.0);\n"
    "}\n";

// 片元：色彩矩阵 → 锐化(亮度死区Unsharp) → 颗粒(128tile+亮度) →
// 磨皮(频率分离+YCbCr肤色+结构门控) → 暗角(解析径向)。
// 数值语义与 iOS PreviewEffectProcessor.m 的 previewBeauty 内核逐行对齐
//（iOS 侧注释即本内核的语义源）；磨皮为频率分离（低频底图由独立 blur pass
//  预渲染到 uBlur），removal/门控曲线与成片 photo_processor.cpp smoothSkin 一致。
//
// 2026-09-05 矩阵采样一致性修复：色彩矩阵（含亮度/清晰度）
// 必须应用于【每一个采样点】（中心/锐化邻域/磨皮邻域）——
// fetchRGB()。之前仅中心像素套矩阵、邻域采原始纹理，导致亮度/清晰度非零
// 时锐化的 diff=中心(矩阵后)-邻域(原始) 带全图系统性偏置，再被锐化
// ×6 倍加到每个像素 → 取景器整体过白/过黑（成片因先整图套矩阵
// 再锐化而不受影响）。iOS 侧 CIColorMatrix 先于内核运行，故无此 bug。
const char* kFragmentShader =
    "#extension GL_OES_EGL_image_external : require\n"
    "precision mediump float;\n"
    "uniform samplerExternalOES uCamera;\n"
    "uniform sampler2D uNoise;\n"
    "uniform sampler2D uBlur;\n"    // 磨皮低频底图（blur pass FBO，窗口几何 1/3 分辨率）
    "uniform vec4 uMRow0;\n"     // 色彩矩阵行 0（含常量项位）
    "uniform vec4 uMRow1;\n"    // 行 1
    "uniform vec4 uMRow2;\n"    // 行 2
    "uniform vec3 uBias;\n"     // 偏移列（已 /255）
    "uniform float uHasMatrix;\n"
    "uniform vec2 uTexel;\n"    // 1/宽, 1/高
    "uniform vec2 uSize;\n"     // 宽, 高（像素）
    "uniform float uSharpen;\n" // 0..6.0
    "uniform float uVig;\n"     // 0..1
    "uniform float uSmooth;\n"  // 0..1
    "uniform float uGrain;\n"   // 0..1
    "varying vec2 vUV;\n"
    "varying vec2 vQuad;\n"  // 输出 quad 坐标（磨皮低频底图采样）
    "const vec3 LUM = vec3(0.299, 0.587, 0.114);\n"
    "vec3 fetchRGB(vec2 uv) {\n"
    "  vec3 c = texture2D(uCamera, uv).rgb;\n"
    "  if (uHasMatrix > 0.5) {\n"
    "    vec4 rgba = vec4(c, 1.0);\n"
    "    c = vec3(dot(uMRow0, rgba), dot(uMRow1, rgba), dot(uMRow2, rgba)) + uBias;\n"
    "  }\n"
    "  return c;\n"
    "}\n"
    "float sampLuma(vec2 uv) {\n"
    "  return dot(fetchRGB(uv), LUM);\n"
    "}\n"
    "void main() {\n"
    "  vec3 rgb = fetchRGB(vUV);\n"
    "  vec2 cp = clamp(vUV, uTexel, vec2(1.0) - uTexel);\n"
    "  // 1) 锐化：亮度域死区 Unsharp（4 邻域均值，死区 0.75/255，边缘门控 0.75..2.25/255）\n"
    "  if (uSharpen > 0.0) {\n"
    "    float l0 = dot(rgb, LUM);\n"
    "    float mn = (sampLuma(cp + vec2(0.0, -uTexel.y))\n"
    "              + sampLuma(cp + vec2(0.0,  uTexel.y))\n"
    "              + sampLuma(cp + vec2(-uTexel.x, 0.0))\n"
    "              + sampLuma(cp + vec2( uTexel.x, 0.0))) * 0.25;\n"
    "    float diff = l0 - mn;\n"
    "    float thr = 0.75 / 255.0;\n"
    "    float amnt = 0.0;\n"
    "    if (diff > thr) { amnt = uSharpen * (diff - thr); }\n"
    "    else if (diff < -thr) { amnt = uSharpen * (diff + thr); }\n"
    "    float edge = smoothstep(0.75 / 255.0, 2.25 / 255.0, abs(diff));\n"
    "    rgb += amnt * edge;\n"
    "  }\n"
    "  // 2) 颗粒：预置 128x128 tile 双线性 + 幅度随亮度（与成片/预览三端同分布）\n"
    "  if (uGrain > 0.0) {\n"
    "    vec2 nuv = vec2(fract(vUV.x * (uSize.x / 128.0) + (13.0 / 128.0)),\n"
    "                   fract(vUV.y * (uSize.y / 128.0) + (29.0 / 128.0)));\n"
    "    float g = texture2D(uNoise, nuv).r;\n"
    "    float ls = mix(0.35, 1.0, smoothstep(0.05, 0.85, dot(rgb, LUM)));\n"
    "    float amp = uGrain * (24.0 / 255.0) * ls;\n"
    "    rgb += (g * 2.0 - 1.0) * amp;\n"
    "  }\n"
    "  // 3) 磨皮（频率分离）：低频底 base=uBlur（blur pass 预渲染的 1/3 分辨率\n"
    "  // 高斯，矩阵后语义），detail=rgb-base；YCbCr 肤色掩膜（放宽区间）+\n"
    "  // 结构门控 → out=base+detail*(1-removal)。曲线与成片 smoothSkin/\n"
    "  // photo_processor.cpp 一致（baseRemove=0.5s+0.04，edge=(6+6s)..2.5x）。\n"
    "  if (uSmooth > 0.0) {\n"
    "    vec3 base = texture2D(uBlur, vQuad).rgb;\n"
    "    vec3 det = rgb - base;\n"
    "    float margin = max(max(abs(det.r), abs(det.g)), abs(det.b));\n"
    "    float y  = dot(rgb, LUM);\n"
    "    float cb = (-0.168736 * rgb.r - 0.331264 * rgb.g + 0.5 * rgb.b) + (128.0 / 255.0);\n"
    "    float cr = ( 0.5 * rgb.r - 0.418688 * rgb.g - 0.081312 * rgb.b) + (128.0 / 255.0);\n"
    "    float skin = smoothstep(40.0 / 255.0, 60.0 / 255.0, y) * (1.0 - smoothstep(250.0 / 255.0, 255.0 / 255.0, y))\n"
    "               * smoothstep(128.0 / 255.0, 140.0 / 255.0, cr) * (1.0 - smoothstep(172.0 / 255.0, 186.0 / 255.0, cr))\n"
    "               * smoothstep( 70.0 / 255.0,  85.0 / 255.0, cb) * (1.0 - smoothstep(120.0 / 255.0, 132.0 / 255.0, cb));\n"
    "    float edgeLow = (6.0 + uSmooth * 6.0) / 255.0;\n"
    "    float edgeHigh = edgeLow * 2.5;\n"
    "    float sc = smoothstep(edgeLow, edgeHigh, margin);\n"
    "    float baseRemove = 0.50 * uSmooth + 0.04;\n"
    "    float removal = clamp(baseRemove * skin * (1.0 - sc), 0.0, 1.0);\n"
    "    rgb = base + det * (1.0 - removal);\n"
    "  }\n"
    "  // 4) 暗角：解析径向（预览==成片逐像素一致）\n"
    "  if (uVig > 0.0) {\n"
    "    vec2 d2 = vec2((2.0 * vUV.x - 1.0), (2.0 * vUV.y - 1.0));\n"
    "    float dn = length(d2) * 0.70710678;\n"
    "    float ff = 1.0 - uVig * smoothstep(0.45, 1.0, dn);\n"
    "    rgb *= ff;\n"
    "  }\n"
    "  gl_FragColor = vec4(clamp(rgb, 0.0, 1.0), 1.0);\n"
    "}\n";

// 磨皮低频底图 pass 片元：相机 OES 纹理 → 3x3 高斯（tap 间距随强度扩大），
// 每 tap 经 fetchRGB 应用色彩矩阵（与主 pass 同语义，保证 base 与 rgb 同色彩
// 空间——矩阵只影响色彩不影响频段，磨皮差值计算才无系统性偏置）。渲染到
// 1/3 窗口分辨率的 FBO；主 pass 以 vQuad 双线性采样回全分辨率（双线性升采样
// 本身即一次低通，与成片「降采样→模糊→双线性升采样」的频率分离等价）。
const char* kBlurFragmentShader =
    "#extension GL_OES_EGL_image_external : require\n"
    "precision mediump float;\n"
    "uniform samplerExternalOES uCamera;\n"
    "uniform vec4 uMRow0;\n"
    "uniform vec4 uMRow1;\n"
    "uniform vec4 uMRow2;\n"
    "uniform vec3 uBias;\n"
    "uniform float uHasMatrix;\n"
    "uniform vec2 uBlurStep;\n"  // tap 间距（相机纹理空间 uv）
    "varying vec2 vUV;\n"
    "vec3 fetchRGB(vec2 uv) {\n"
    "  vec3 c = texture2D(uCamera, uv).rgb;\n"
    "  if (uHasMatrix > 0.5) {\n"
    "    vec4 rgba = vec4(c, 1.0);\n"
    "    c = vec3(dot(uMRow0, rgba), dot(uMRow1, rgba), dot(uMRow2, rgba)) + uBias;\n"
    "  }\n"
    "  return c;\n"
    "}\n"
    "void main() {\n"
    "  vec2 s = uBlurStep;\n"
    "  vec3 c = fetchRGB(vUV) * 4.0;\n"
    "  c += fetchRGB(vUV + vec2(-s.x, -s.y));\n"
    "  c += fetchRGB(vUV + vec2( 0.0, -s.y)) * 2.0;\n"
    "  c += fetchRGB(vUV + vec2( s.x, -s.y));\n"
    "  c += fetchRGB(vUV + vec2(-s.x,  0.0)) * 2.0;\n"
    "  c += fetchRGB(vUV + vec2( s.x,  0.0)) * 2.0;\n"
    "  c += fetchRGB(vUV + vec2(-s.x,  s.y));\n"
    "  c += fetchRGB(vUV + vec2( 0.0,  s.y)) * 2.0;\n"
    "  c += fetchRGB(vUV + vec2( s.x,  s.y));\n"
    "  gl_FragColor = vec4(c / 16.0, 1.0);\n"
    "}\n";

// 帧到达回调（BufferQueue 线程）：仅置标志并唤醒渲染线程（合并积压帧）。
void OnFrameAvailable(void* /*context*/) {
  g.pendingCount.fetch_add(1, std::memory_order_release);
  g.framePending.store(true, std::memory_order_release);
  g.wakeCv.notify_one();
}

GLuint CompileShader(GLenum type, const char* src) {
  GLuint sh = glCreateShader(type);
  glShaderSource(sh, 1, &src, nullptr);
  glCompileShader(sh);
  GLint ok = GL_FALSE;
  glGetShaderiv(sh, GL_COMPILE_STATUS, &ok);
  if (ok != GL_TRUE) {
    char log[1024];
    GLsizei len = 0;
    glGetShaderInfoLog(sh, sizeof(log), &len, log);
    FX_ERR("shader compile failed: %{public}s", log);
    glDeleteShader(sh);
    return 0;
  }
  return sh;
}

// 预计算 128x128 单通道颗粒 tile（固定 LCG 种子，与 iOS makeNoiseTile/
// photo_processor.cpp 同分布）。
GLuint MakeNoiseTexture() {
  const GLsizei tex = 128;
  uint8_t buf[128 * 128];
  uint32_t seed = 0x85EBCA6Bu;
  for (size_t i = 0; i < sizeof(buf); ++i) {
    seed = seed * 1664525u + 1013904223u;
    const double rnd = (double)((seed >> 8) & 0xFFFFu) * (1.0 / 65535.0);
    buf[i] = (uint8_t)llround(rnd * 255.0);
  }
  GLuint id = 0;
  glGenTextures(1, &id);
  glBindTexture(GL_TEXTURE_2D, id);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, tex, tex, 0, GL_LUMINANCE,
               GL_UNSIGNED_BYTE, buf);
  return id;
}

// 渲染线程主循环：完成全部 GL 资源创建 → 逐帧渲染 → 退出时统一释放。
void RenderThreadMain() {
  do {
    // ── EGL 初始化 ──
    g.display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (g.display == EGL_NO_DISPLAY) {
      FX_ERR("eglGetDisplay failed");
      break;
    }
    if (!eglInitialize(g.display, nullptr, nullptr)) {
      FX_ERR("eglInitialize failed: 0x%{public}x", eglGetError());
      g.display = EGL_NO_DISPLAY;
      break;
    }
    const EGLint cfgAttribs[] = {
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
        EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
        EGL_NONE
    };
    EGLConfig config = nullptr;
    EGLint numConfigs = 0;
    if (!eglChooseConfig(g.display, cfgAttribs, &config, 1, &numConfigs) ||
        numConfigs < 1) {
      FX_ERR("eglChooseConfig failed: 0x%{public}x", eglGetError());
      break;
    }
    const EGLint ctxAttribs[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
    g.context = eglCreateContext(g.display, config, EGL_NO_CONTEXT, ctxAttribs);
    if (g.context == EGL_NO_CONTEXT) {
      FX_ERR("eglCreateContext failed: 0x%{public}x", eglGetError());
      g.context = EGL_NO_CONTEXT;
      break;
    }

    // ── 目标窗口：从 Flutter 纹理 surfaceId 还原 NativeWindow ──
    if (OH_NativeWindow_CreateNativeWindowFromSurfaceId(g.targetSurfaceId,
                                                        &g.targetWindow) != 0 ||
        g.targetWindow == nullptr) {
      FX_ERR("CreateNativeWindowFromSurfaceId(%{public}llu) failed",
             (unsigned long long)g.targetSurfaceId);
      g.targetWindow = nullptr;
      break;
    }
    // 缓冲几何/格式对齐预览档位（与相机直写路径等价：相机写 NV12、EGL 写 RGBA，
    // 引擎侧消费端按外部纹理采样两种格式均可正确合成）。
    OH_NativeWindow_NativeWindowHandleOpt(g.targetWindow, SET_BUFFER_GEOMETRY,
                                          (int32_t)g.width, (int32_t)g.height);
    OH_NativeWindow_NativeWindowHandleOpt(
        g.targetWindow, SET_FORMAT, NATIVEBUFFER_PIXEL_FMT_RGBA_8888);

    g.surface = eglCreateWindowSurface(g.display, config,
                                       (EGLNativeWindowType)g.targetWindow,
                                       nullptr);
    if (g.surface == EGL_NO_SURFACE) {
      FX_ERR("eglCreateWindowSurface failed: 0x%{public}x", eglGetError());
      g.surface = EGL_NO_SURFACE;
      break;
    }
    if (!eglMakeCurrent(g.display, g.surface, g.surface, g.context)) {
      FX_ERR("eglMakeCurrent failed: 0x%{public}x", eglGetError());
      break;
    }

    // ── 着色器/纹理/VBO ──
    GLuint vs = CompileShader(GL_VERTEX_SHADER, kVertexShader);
    GLuint fs = CompileShader(GL_FRAGMENT_SHADER, kFragmentShader);
    if (vs == 0 || fs == 0) {
      if (vs != 0) glDeleteShader(vs);
      if (fs != 0) glDeleteShader(fs);
      break;
    }
    g.program = glCreateProgram();
    glAttachShader(g.program, vs);
    glAttachShader(g.program, fs);
    glLinkProgram(g.program);
    glDeleteShader(vs);
    glDeleteShader(fs);
    GLint linked = GL_FALSE;
    glGetProgramiv(g.program, GL_LINK_STATUS, &linked);
    if (linked != GL_TRUE) {
      char log[1024];
      GLsizei len = 0;
      glGetProgramInfoLog(g.program, sizeof(log), &len, log);
      FX_ERR("program link failed: %{public}s", log);
      break;
    }

    // 全屏矩形（两个三角形）
    const GLfloat quad[] = {
        -1.0f, -1.0f,  1.0f, -1.0f, -1.0f, 1.0f,
        -1.0f,  1.0f,  1.0f, -1.0f,  1.0f, 1.0f,
    };
    glGenBuffers(1, &g.vbo);
    glBindBuffer(GL_ARRAY_BUFFER, g.vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quad), quad, GL_STATIC_DRAW);

    // 相机消费端：OES 外部纹理 + OH_NativeImage
    glGenTextures(1, &g.oesTex);
    glBindTexture(GL_TEXTURE_EXTERNAL_OES, g.oesTex);
    glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    g.nativeImage = OH_NativeImage_Create(g.oesTex, GL_TEXTURE_EXTERNAL_OES);
    if (g.nativeImage == nullptr) {
      FX_ERR("OH_NativeImage_Create failed");
      break;
    }
    if (OH_NativeImage_GetSurfaceId(g.nativeImage, &g.cameraSurfaceId) != 0) {
      FX_ERR("OH_NativeImage_GetSurfaceId failed");
      break;
    }
    OH_OnFrameAvailableListener listener;
    listener.context = nullptr;
    listener.onFrameAvailable = OnFrameAvailable;
    OH_NativeImage_SetOnFrameAvailableListener(g.nativeImage, listener);

    g.noiseTex = MakeNoiseTexture();

    // 变换矩阵初值：单位阵（首帧矩阵获取失败时的兜底，随后逐帧覆盖）。
    const GLfloat kIdentity[16] = {
        1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 1.0f,
    };

    // ── 磨皮低频底图 pass 资源（blur program + 1/3 窗口分辨率 FBO）──
    // 任一环节失败即删除全部 blur 资源并保持 blurProgram=0：渲染循环
    // 届时会把主 pass 的 uSmooth 按 0 传递（磨皮分支不执行），安全降级。
    do {
      GLuint bvs = CompileShader(GL_VERTEX_SHADER, kVertexShader);
      GLuint bfs = CompileShader(GL_FRAGMENT_SHADER, kBlurFragmentShader);
      if (bvs == 0 || bfs == 0) {
        if (bvs != 0) glDeleteShader(bvs);
        if (bfs != 0) glDeleteShader(bfs);
        FX_ERR("blur shader compile failed (磨皮底图 pass 降级关闭)");
        break;
      }
      g.blurProgram = glCreateProgram();
      glAttachShader(g.blurProgram, bvs);
      glAttachShader(g.blurProgram, bfs);
      glLinkProgram(g.blurProgram);
      glDeleteShader(bvs);
      glDeleteShader(bfs);
      GLint linked = GL_FALSE;
      glGetProgramiv(g.blurProgram, GL_LINK_STATUS, &linked);
      if (linked != GL_TRUE) {
        char log[1024];
        GLsizei len = 0;
        glGetProgramInfoLog(g.blurProgram, sizeof(log), &len, log);
        FX_ERR("blur program link failed: %{public}s", log);
        glDeleteProgram(g.blurProgram);
        g.blurProgram = 0;
        break;
      }

      g.blurWidth = g.width / 3;   if (g.blurWidth < 1) g.blurWidth = 1;
      g.blurHeight = g.height / 3; if (g.blurHeight < 1) g.blurHeight = 1;
      glGenTextures(1, &g.blurTex);
      glBindTexture(GL_TEXTURE_2D, g.blurTex);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)g.blurWidth,
                   (GLsizei)g.blurHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
      glGenFramebuffers(1, &g.blurFbo);
      glBindFramebuffer(GL_FRAMEBUFFER, g.blurFbo);
      glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                            GL_TEXTURE_2D, g.blurTex, 0);
      if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        FX_ERR("blur FBO incomplete (磨皮底图 pass 降级关闭)");
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glDeleteFramebuffers(1, &g.blurFbo);
        g.blurFbo = 0;
        glDeleteTextures(1, &g.blurTex);
        g.blurTex = 0;
        glDeleteProgram(g.blurProgram);
        g.blurProgram = 0;
        break;
      }
      glBindFramebuffer(GL_FRAMEBUFFER, 0);

      glUseProgram(g.blurProgram);
      g.buTransform = glGetUniformLocation(g.blurProgram, "uTransformMatrix");
      g.buHasMatrix = glGetUniformLocation(g.blurProgram, "uHasMatrix");
      g.buMRow0 = glGetUniformLocation(g.blurProgram, "uMRow0");
      g.buMRow1 = glGetUniformLocation(g.blurProgram, "uMRow1");
      g.buMRow2 = glGetUniformLocation(g.blurProgram, "uMRow2");
      g.buBias = glGetUniformLocation(g.blurProgram, "uBias");
      g.buBlurStep = glGetUniformLocation(g.blurProgram, "uBlurStep");
      g.aPosBlur = glGetAttribLocation(g.blurProgram, "aPos");
      glUniform1i(glGetUniformLocation(g.blurProgram, "uCamera"), 0);
      // 变换矩阵初值：单位阵（同主 program 兜底，随后逐帧覆盖）。
      glUniformMatrix4fv(g.buTransform, 1, GL_FALSE, kIdentity);
      glUseProgram(g.program);
      FX_LOG("blur pass ready %{public}ux%{public}u", g.blurWidth, g.blurHeight);
    } while (false);

    // Uniform 位置
    glUseProgram(g.program);
    g.uMRow0 = glGetUniformLocation(g.program, "uMRow0");
    g.uMRow1 = glGetUniformLocation(g.program, "uMRow1");
    g.uMRow2 = glGetUniformLocation(g.program, "uMRow2");
    g.uBias = glGetUniformLocation(g.program, "uBias");
    g.uHasMatrix = glGetUniformLocation(g.program, "uHasMatrix");
    g.uTexel = glGetUniformLocation(g.program, "uTexel");
    g.uSize = glGetUniformLocation(g.program, "uSize");
    g.uSharpen = glGetUniformLocation(g.program, "uSharpen");
    g.uSmooth = glGetUniformLocation(g.program, "uSmooth");
    g.uVig = glGetUniformLocation(g.program, "uVig");
    g.uGrain = glGetUniformLocation(g.program, "uGrain");
    g.uTransform = glGetUniformLocation(g.program, "uTransformMatrix");
    const GLint aPos = glGetAttribLocation(g.program, "aPos");

    // 静态 uniform（纹理单元绑定 + 网格尺寸）。注意：vUV 位于相机纹理空间，
    // texel/尺寸基准必须是相机缓冲宽高（而非输出窗口），与效果内核像素语义一致。
    glUniform1i(glGetUniformLocation(g.program, "uCamera"), 0);
    glUniform1i(glGetUniformLocation(g.program, "uNoise"), 1);
    glUniform1i(glGetUniformLocation(g.program, "uBlur"), 2);
    glUniform2f(g.uTexel, 1.0f / (float)g.texWidth, 1.0f / (float)g.texHeight);
    glUniform2f(g.uSize, (float)g.texWidth, (float)g.texHeight);
    glUniformMatrix4fv(g.uTransform, 1, GL_FALSE, kIdentity);

    glDisable(GL_BLEND);
    glViewport(0, 0, (GLsizei)g.width, (GLsizei)g.height);

    FX_LOG("pipeline ready %{public}ux%{public}u cameraSurface=%{public}llu",
           g.width, g.height, (unsigned long long)g.cameraSurfaceId);
    g.ready.store(true);
    g.readyCv.notify_all();

    // ── 渲染循环 ──
    bool transformLogged = false;
    while (g.running.load(std::memory_order_acquire)) {
      std::unique_lock<std::mutex> lk(g.wakeMtx);
      g.wakeCv.wait(lk, [] {
        return g.framePending.load(std::memory_order_acquire) ||
               !g.running.load(std::memory_order_relaxed);
      });
      const bool hasFrame = g.framePending.load(std::memory_order_acquire);
      g.framePending.store(false, std::memory_order_release);
      lk.unlock();
      if (!g.running.load(std::memory_order_acquire)) break;
      if (!hasFrame) continue;

      const auto tWake = std::chrono::steady_clock::now();

      // 追帧到最新相机帧：按到达计数连做多次 UpdateSurfaceImage
      // （FIFO 逐次推进），最终留在 OES 纹理里的就是最新一帧。
      // 防御上限 8：异常风暴时止损，不做无谓空转。
      int toDrain = g.pendingCount.exchange(0, std::memory_order_acquire);
      if (toDrain < 1) toDrain = 1;
      if (toDrain > 8) toDrain = 8;
      bool acquired = false;
      for (int i = 0; i < toDrain; ++i) {
        if (OH_NativeImage_UpdateSurfaceImage(g.nativeImage) != 0) break;
        acquired = true;
      }
      if (!acquired) {
        continue;
      }
      const auto tAcquired = std::chrono::steady_clock::now();

      // 参数快照
      FxParams p;
      {
        std::lock_guard<std::mutex> pl(g.paramMtx);
        p = g.params;
      }

      // 变换矩阵：含相机预览旋转（buffer transform 元数据）与 GL 翻转约定。
      // 逐帧刷新（矩阵可能随流重启/旋转变化）；获取失败或矩阵非法（m[15]=0）
      // 时保留上一帧矩阵（主/blur 两个 program 各自的 uniform 槽位）。
      // 首帧打印矩阵便于真机诊断方向问题。
      float tm[16];
      bool tmOk = false;
      if (OH_NativeImage_GetTransformMatrixV2(g.nativeImage, tm) == 0 &&
          tm[15] != 0.0f) {
        tmOk = true;
        if (!transformLogged) {
          transformLogged = true;
          FX_LOG("transform matrix [%{public}.3f %{public}.3f %{public}.3f %{public}.3f | "
                 "%{public}.3f %{public}.3f %{public}.3f %{public}.3f | "
                 "%{public}.3f %{public}.3f %{public}.3f %{public}.3f | "
                 "%{public}.3f %{public}.3f %{public}.3f %{public}.3f]",
                 tm[0], tm[1], tm[2], tm[3], tm[4], tm[5], tm[6], tm[7],
                 tm[8], tm[9], tm[10], tm[11], tm[12], tm[13], tm[14], tm[15]);
        }
      }

      // ── 磨皮低频底图 pass（smooth>0 时）：相机纹理 → 1/3 分辨率 FBO
      //    （3x3 高斯，tap 间距随强度扩大）。tap 间距以相机缓冲全分辨率像素
      //    为单位（3+5s px）：与成片「降采样1/3+高斯radius2..5」的低频频段
      //    在预览分辨率下等效对齐；各向同性核在旋转坐标下性质不变。
      const bool blurReady = (g.blurProgram != 0 && g.blurFbo != 0);
      const float smoothEff = blurReady ? p.smooth : 0.0f;
      if (p.smooth > 0.0f && blurReady) {
        glUseProgram(g.blurProgram);
        if (tmOk) glUniformMatrix4fv(g.buTransform, 1, GL_FALSE, tm);
        // 防御：blurTex 上一帧仍绑在纹理单元 2（主 pass 采样用），此处即将
        // 作为 FBO 颜色附件被写入——先解绑，杜绝部分驱动把「绑定在采样单元
        // 的附件纹理」判为 framebuffer feedback loop。
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, 0);
        glActiveTexture(GL_TEXTURE0);
        glBindFramebuffer(GL_FRAMEBUFFER, g.blurFbo);
        glViewport(0, 0, (GLsizei)g.blurWidth, (GLsizei)g.blurHeight);
        glBindBuffer(GL_ARRAY_BUFFER, g.vbo);
        glEnableVertexAttribArray((GLuint)g.aPosBlur);
        glVertexAttribPointer((GLuint)g.aPosBlur, 2, GL_FLOAT, GL_FALSE, 0, nullptr);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_EXTERNAL_OES, g.oesTex);
        glUniform1f(g.buHasMatrix, p.hasMatrix ? 1.0f : 0.0f);
        glUniform4fv(g.buMRow0, 1, p.mR0);
        glUniform4fv(g.buMRow1, 1, p.mR1);
        glUniform4fv(g.buMRow2, 1, p.mR2);
        glUniform3fv(g.buBias, 1, p.bias);
        const float blurSpacing = 3.0f + 5.0f * p.smooth;
        glUniform2f(g.buBlurStep, blurSpacing / (float)g.texWidth,
                   blurSpacing / (float)g.texHeight);
        glDrawArrays(GL_TRIANGLES, 0, 6);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glViewport(0, 0, (GLsizei)g.width, (GLsizei)g.height);
      }

      glUseProgram(g.program);
      if (tmOk) glUniformMatrix4fv(g.uTransform, 1, GL_FALSE, tm);

      // 顶点属性（每帧重绑，状态机简单可靠）
      glBindBuffer(GL_ARRAY_BUFFER, g.vbo);
      glEnableVertexAttribArray((GLuint)aPos);
      glVertexAttribPointer((GLuint)aPos, 2, GL_FLOAT, GL_FALSE, 0, nullptr);

      // 纹理单元
      glActiveTexture(GL_TEXTURE0);
      glBindTexture(GL_TEXTURE_EXTERNAL_OES, g.oesTex);
      glActiveTexture(GL_TEXTURE1);
      glBindTexture(GL_TEXTURE_2D, g.noiseTex);
      glActiveTexture(GL_TEXTURE2);
      glBindTexture(GL_TEXTURE_2D, g.blurTex);

      // 参数 uniform
      glUniform1f(g.uHasMatrix, p.hasMatrix ? 1.0f : 0.0f);
      glUniform4fv(g.uMRow0, 1, p.mR0);
      glUniform4fv(g.uMRow1, 1, p.mR1);
      glUniform4fv(g.uMRow2, 1, p.mR2);
      glUniform3fv(g.uBias, 1, p.bias);
      glUniform1f(g.uSharpen, p.sharpen);
      glUniform1f(g.uSmooth, smoothEff);
      glUniform1f(g.uVig, p.vignette);
      glUniform1f(g.uGrain, p.grain);

      glDrawArrays(GL_TRIANGLES, 0, 6);
      eglSwapBuffers(g.display, g.surface);
      const auto tSwapped = std::chrono::steady_clock::now();

      // —— 延迟诊断（节流：每 90 帧一次 ≈ 3s @30fps）——
      // bufAgeMs：所显示帧的拍摄时刻距现在（相机出流+管线总延迟的直接读数）；
      // drain：本次追帧数（>1 说明队列有积压/HAL 预压）；
      // acqMs/swapMs：本线程开销；interval：帧间隔（推算有效预览 fps）。
      ++g.diagFrames;
      if (g.diagFrames % 90 == 1) {
        const int64_t bufTs = OH_NativeImage_GetTimestamp(g.nativeImage);
        const double bufAgeMs =
            bufTs > 0
                ? std::chrono::duration<double, std::milli>(
                      tAcquired.time_since_epoch() - std::chrono::nanoseconds(bufTs)).count()
                : -1.0;
        const double acqMs =
            std::chrono::duration<double, std::milli>(tAcquired - tWake).count();
        const double swapMs =
            std::chrono::duration<double, std::milli>(tSwapped - tAcquired).count();
        const double intervalMs =
            g.diagLastFrame.time_since_epoch().count() > 0
                ? std::chrono::duration<double, std::milli>(tWake - g.diagLastFrame).count()
                : -1.0;
        g.diagLastFrame = tWake;
        FX_LOG("latency: bufAge=%{public}.1fms drain=%{public}d acq=%{public}.1fms "
               "swap=%{public}.1fms interval=%{public}.1fms (fps~%{public}.1f)",
               bufAgeMs, toDrain, acqMs, swapMs, intervalMs,
               intervalMs > 0 ? 1000.0 / intervalMs : 0.0);
      } else {
        g.diagLastFrame = tWake;
      }
    }

    // ── 资源释放（渲染线程）──
    if (g.nativeImage != nullptr) {
      OH_NativeImage_Destroy(&g.nativeImage);
      g.nativeImage = nullptr;
    }
    if (g.blurFbo != 0) {
      glDeleteFramebuffers(1, &g.blurFbo);
      g.blurFbo = 0;
    }
    if (g.blurTex != 0) {
      glDeleteTextures(1, &g.blurTex);
      g.blurTex = 0;
    }
    if (g.blurProgram != 0) {
      glDeleteProgram(g.blurProgram);
      g.blurProgram = 0;
    }
    if (g.noiseTex != 0) {
      glDeleteTextures(1, &g.noiseTex);
      g.noiseTex = 0;
    }
    if (g.oesTex != 0) {
      glDeleteTextures(1, &g.oesTex);
      g.oesTex = 0;
    }
    if (g.vbo != 0) {
      glDeleteBuffers(1, &g.vbo);
      g.vbo = 0;
    }
    if (g.program != 0) {
      glDeleteProgram(g.program);
      g.program = 0;
    }
    if (g.display != EGL_NO_DISPLAY) {
      eglMakeCurrent(g.display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
      if (g.surface != EGL_NO_SURFACE) {
        eglDestroySurface(g.display, g.surface);
        g.surface = EGL_NO_SURFACE;
      }
      eglDestroyContext(g.display, g.context);
      g.context = EGL_NO_CONTEXT;
      eglTerminate(g.display);
      g.display = EGL_NO_DISPLAY;
    }
    if (g.targetWindow != nullptr) {
      OH_NativeWindow_DestroyNativeWindow(g.targetWindow);
      g.targetWindow = nullptr;
    }
    g.cameraSurfaceId = 0;
    FX_LOG("pipeline destroyed");
    return;
  } while (false);

  // ── 初始化失败路径：标记失败 + 尽力清理已建资源 ──
  FX_ERR("pipeline init failed");
  if (g.nativeImage != nullptr) {
    OH_NativeImage_Destroy(&g.nativeImage);
    g.nativeImage = nullptr;
  }
  if (g.blurFbo != 0 || g.blurTex != 0 || g.blurProgram != 0) {
    if (g.blurFbo != 0) { glDeleteFramebuffers(1, &g.blurFbo); g.blurFbo = 0; }
    if (g.blurTex != 0) { glDeleteTextures(1, &g.blurTex); g.blurTex = 0; }
    if (g.blurProgram != 0) { glDeleteProgram(g.blurProgram); g.blurProgram = 0; }
  }
  if (g.noiseTex != 0 || g.oesTex != 0 || g.vbo != 0 || g.program != 0) {
    if (g.noiseTex != 0) { glDeleteTextures(1, &g.noiseTex); g.noiseTex = 0; }
    if (g.oesTex != 0) { glDeleteTextures(1, &g.oesTex); g.oesTex = 0; }
    if (g.vbo != 0) { glDeleteBuffers(1, &g.vbo); g.vbo = 0; }
    if (g.program != 0) { glDeleteProgram(g.program); g.program = 0; }
  }
  if (g.display != EGL_NO_DISPLAY) {
    eglMakeCurrent(g.display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    if (g.surface != EGL_NO_SURFACE) {
      eglDestroySurface(g.display, g.surface);
      g.surface = EGL_NO_SURFACE;
    }
    if (g.context != EGL_NO_CONTEXT) {
      eglDestroyContext(g.display, g.context);
      g.context = EGL_NO_CONTEXT;
    }
    eglTerminate(g.display);
    g.display = EGL_NO_DISPLAY;
  }
  if (g.targetWindow != nullptr) {
    OH_NativeWindow_DestroyNativeWindow(g.targetWindow);
    g.targetWindow = nullptr;
  }
  g.cameraSurfaceId = 0;
  g.initFailed.store(true);
  g.ready.store(true);
  g.readyCv.notify_all();
}
} // namespace

// ── NAPI 导出 ─────────────────────────────────────────────────────

// createPreviewFx(flutterSurfaceId, width, height, texWidth, texHeight)
//   → cameraSurfaceId（0=失败）。width/height 为输出窗口几何（竖屏时应传交换
//   后的预览宽高）；texWidth/texHeight 为相机缓冲宽高。
static napi_value CreatePreviewFx(napi_env env, napi_callback_info info) {
  size_t argc = 5;
  napi_value args[5];
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  if (argc < 5) {
    napi_throw_type_error(env, nullptr, "createPreviewFx requires 5 args");
    return nullptr;
  }
  double surfaceId = 0;
  uint32_t w = 0, h = 0, tw = 0, th = 0;
  napi_get_value_double(env, args[0], &surfaceId);
  napi_get_value_uint32(env, args[1], &w);
  napi_get_value_uint32(env, args[2], &h);
  napi_get_value_uint32(env, args[3], &tw);
  napi_get_value_uint32(env, args[4], &th);
  if (surfaceId <= 0 || w == 0 || h == 0 || tw == 0 || th == 0) {
    FX_ERR("createPreviewFx invalid args surface=%{public}f w=%{public}u h=%{public}u "
           "tw=%{public}u th=%{public}u", surfaceId, w, h, tw, th);
    napi_value zero;
    napi_create_uint32(env, 0, &zero);
    return zero;
  }
  if (g.running.load(std::memory_order_relaxed)) {
    // 已有实例：先同步销毁（防御重复初始化，如快速重建相机的竞态）。
    g.running.store(false, std::memory_order_release);
    g.wakeCv.notify_all();
    if (g.renderThread.joinable()) {
      g.renderThread.join();
    }
  }

  g.framePending.store(false, std::memory_order_release);
  g.initFailed.store(false);
  g.ready.store(false);
  g.targetSurfaceId = (uint64_t)surfaceId;
  g.cameraSurfaceId = 0;
  g.width = w;
  g.height = h;
  g.texWidth = tw;
  g.texHeight = th;
  {
    std::lock_guard<std::mutex> pl(g.paramMtx);
    g.params = FxParams{};
  }
  g.running.store(true, std::memory_order_release);
  g.renderThread = std::thread(RenderThreadMain);

  // 等待管线就绪（上限 2s：EGL/着色器初始化通常 <100ms）
  std::unique_lock<std::mutex> lk(g.wakeMtx);
  const bool ok = g.readyCv.wait_for(lk, std::chrono::seconds(2),
                                     [] { return g.ready.load(); });
  lk.unlock();
  if (!ok || g.initFailed.load() || g.cameraSurfaceId == 0) {
    // 初始化失败：回收线程。
    g.running.store(false, std::memory_order_release);
    g.wakeCv.notify_all();
    if (g.renderThread.joinable()) {
      g.renderThread.join();
    }
    FX_ERR("createPreviewFx init failed (timeout=%{public}d)", (int)(!ok));
    napi_value zero;
    napi_create_uint32(env, 0, &zero);
    return zero;
  }
  napi_value out;
  // surfaceId 为 uint64，JS Number 可安全表示到 2^53，用 double 传回。
  napi_create_double(env, (double)g.cameraSurfaceId, &out);
  return out;
}

// updatePreviewFxParams(hasMatrix, matrix(Float64Array(20)|null),
//                       vignette, smooth, sharpen, grain)
// 数值语义与 iOS updateEffects 一致：matrix 为 Flutter 20 元素 ColorFilter
//（恒等时 Dart 传 null）；vignette/smooth/sharpen/grain 为 0..100 原始强度。
static napi_value UpdatePreviewFxParams(napi_env env, napi_callback_info info) {
  size_t argc = 6;
  napi_value args[6];
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  if (argc < 6) {
    napi_throw_type_error(env, nullptr, "updatePreviewFxParams requires 6 args");
    return nullptr;
  }
  if (!g.running.load(std::memory_order_relaxed)) {
    return nullptr; // 管线不存在：安静忽略（如录像模式/初始化竞态）
  }

  bool hasMatrix = false;
  napi_get_value_bool(env, args[0], &hasMatrix);

  FxParams p{};
  p.hasMatrix = hasMatrix;
  if (hasMatrix) {
    bool isTyped = false;
    napi_is_typedarray(env, args[1], &isTyped);
    if (!isTyped) {
      napi_throw_type_error(env, nullptr, "matrix must be Float64Array(20)");
      return nullptr;
    }
    void* data = nullptr;
    size_t len = 0;
    napi_get_typedarray_info(env, args[1], nullptr, &len, &data, nullptr,
                             nullptr);
    if (data == nullptr || len < 20) {
      napi_throw_type_error(env, nullptr, "matrix must have 20 elements");
      return nullptr;
    }
    const double* m = (const double*)data;
    p.mR0[0] = (float)m[0];  p.mR0[1] = (float)m[1];  p.mR0[2] = (float)m[2];  p.mR0[3] = (float)m[3];
    p.mR1[0] = (float)m[5];  p.mR1[1] = (float)m[6];  p.mR1[2] = (float)m[7];  p.mR1[3] = (float)m[8];
    p.mR2[0] = (float)m[10]; p.mR2[1] = (float)m[11]; p.mR2[2] = (float)m[12]; p.mR2[3] = (float)m[13];
    p.bias[0] = (float)m[4] / 255.0f;
    p.bias[1] = (float)m[9] / 255.0f;
    p.bias[2] = (float)m[14] / 255.0f;
  }

  double vig = 0, smooth = 0, sharpen = 0, grain = 0;
  napi_get_value_double(env, args[2], &vig);
  napi_get_value_double(env, args[3], &smooth);
  napi_get_value_double(env, args[4], &sharpen);
  napi_get_value_double(env, args[5], &grain);
  // 折算曲线与 iOS applyParams 完全一致（锐化 ×6.0 上限 6.0，其余 /100）。
  p.vignette = (float)(vig / 100.0);
  p.smooth = (float)(smooth / 100.0);
  // 强度 a=v/100×6.0（上限 6.0，四端统一）：6.0 是本管线同步前的原始值，真机
  // 观感校准点（「锐化明显可感知」）。2026-09-06 曾误回调 1.2——真机实测拉满
  // 无感（硬边缘增益仅 1-2%/255 级别，人眼不可察），恢复 6.0。与 photo_processor.cpp
  // / Dart applyPerPixelEffectsImg / iOS PreviewEffectProcessor 同步；
  // 死区(0.75)/门控(0.75,2.25)不变。
  p.sharpen = (float)(sharpen / 100.0 * 6.0);
  if (p.sharpen > 6.0f) p.sharpen = 6.0f;
  if (p.sharpen < 0.0f) p.sharpen = 0.0f;
  p.grain = (float)(grain / 100.0);

  {
    std::lock_guard<std::mutex> pl(g.paramMtx);
    g.params = p;
  }
  return nullptr;
}

// destroyPreviewFx()
static napi_value DestroyPreviewFx(napi_env env, napi_callback_info info) {
  if (g.running.load(std::memory_order_relaxed)) {
    g.running.store(false, std::memory_order_release);
    g.wakeCv.notify_all();
    if (g.renderThread.joinable()) {
      g.renderThread.join();
    }
  }
  return nullptr;
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
  napi_property_descriptor desc[] = {
      {"createPreviewFx", nullptr, CreatePreviewFx, nullptr, nullptr, nullptr,
       napi_default, nullptr},
      {"updatePreviewFxParams", nullptr, UpdatePreviewFxParams, nullptr,
       nullptr, nullptr, napi_default, nullptr},
      {"destroyPreviewFx", nullptr, DestroyPreviewFx, nullptr, nullptr,
       nullptr, napi_default, nullptr},
  };
  napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
  return exports;
}
EXTERN_C_END

static napi_module previewFxModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "preview_fx",
    .nm_priv = ((void*)0),
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterPreviewFxModule(void) {
  napi_module_register(&previewFxModule);
}
