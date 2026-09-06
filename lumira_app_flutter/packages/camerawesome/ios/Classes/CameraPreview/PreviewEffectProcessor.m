//
//  PreviewEffectProcessor.m
//  camerawesome
//
//  iOS 取景器逐帧效果处理器实现。详见 PreviewEffectProcessor.h 注释。
//

#import "PreviewEffectProcessor.h"
#import <Metal/Metal.h>

// 统一效果内核：在一遍内完成 锐化(亮度死区Unsharp)→颗粒(tile+亮度)→磨皮(频率分离+肤色掩膜+结构门控)→暗角。
// 数值语义与 OHOS C++ bake（photo_processor.cpp）及预览 FragmentShader 一致（颜色按 0..1，阈值/幅度相应折算）。
//
// 坐标体系（2026-09-06 重写，吸取两次失败教训）：
//   - 所有 sample() 一律经 samplerTransform(s, destCoord()±offset) 取「sampler 像素坐标」。
//     9c0355a1 曾直接 sample(image, destCoord())，真机 DAG 带变换（clean aperture/方向元数据）时
//     采样越界 → 全黑回退（ecfd0dde），故采样必须走 samplerTransform。
//   - 所有几何归一（暗角径向、颗粒分块、邻域钳制）改用 destCoord() 相对「显式传入的输出 extent」
//     （vec4 outExtent = origin.x, origin.y, width, height）计算像素坐标/UV：
//     destCoord() 必然落在输出 extent 内，归一结果数学上封闭，不依赖 samplerSize（此前
//     samplerSize 与 samplerTransform 可能不一致 → 暗角整图变暗、颗粒采样错位）。
//     该数学与 OHOS preview_fx.cpp 的 vQuad/vUV·uSize 逐项等价。
//   - applyWithExtent 必须带 ROI 回调（此前 roiCallback:nil 是 1:1 假设）：
//     · image（index 0）：锐化邻域 ±1 输出像素 → 回调对输出 rect 外扩 2px；
//     · noise（index 1）：内核在任意输出位置都可能采样 [0,128)² → 回调恒返回噪声 tile 全 extent
//       （此前 1:1 假设下，输出区域一旦不在 (0,0,128,128) 附近，噪声输入区域为空 →
//        sample 返回黑 → rgb += (0×2−1)×amp → 取景器整体压暗且无颗粒纹理，即本 Bug）；
//     · blur（index 2）：1:1 采样 → 返回原 rect。
//
// 数值语义对齐（颜色按 0..1，阈值/幅度相应折算，与 OHOS C++ bake/预览 FragmentShader 一致）：
//   - 锐化：diff=luma−4邻域均值，死区 thr=0.75/255，amnt=a×(diff±thr)，乘 smoothstep(0.75/255,2.25/255,|diff|)
//   - 颗粒：128×128 预置 tile 双线性采样（固定 offset 13/128,29/128），幅度=grains×24/255×mix(0.35,1.0,smoothstep(0.05,0.85,luma))
//   - 磨皮（频率分离）：低频底 base=blur sampler（applyParams 里 CIGaussianBlur 预渲染的矩阵后整图高斯，
//     经 samplerTransform(blur, destCoord()) 采样——旧代码直接 sample(blur, destCoord()) 把工作坐标
//     当 sampler 坐标，DAG 带变换时取到黑 → 磨皮区域被压暗），
//     detail=rgb−base，out=base+detail×(1−removal)，removal=baseRemove×肤色概率×(1−结构门控)，
//     曲线与成片 SkinSmoother/photo_processor.cpp 一致（baseRemove=0.5s+0.04，edge=(6+6s)..×2.5）
//   - 暗角：factor=1−vigS×smoothstep(0.45,1.0,dn)，dn=length(归一径向)/√2
static NSString *const kPreviewBeautyKernelString = @" \n"
  "kernel vec4 previewBeauty(sampler image, sampler noise, sampler blur, vec4 outExtent, float sharpenA, float vigS, float smoothS, float grainOn) {\n"
  "  vec2 dc = destCoord();\n"
  "  vec2 px = dc - outExtent.xy;\n"    // 输出空间像素坐标 [0,w)×[0,h)
  "  vec2 sz = outExtent.zw;\n"
  "  vec4 c = sample(image, samplerTransform(image, dc));\n"
  "  vec3 rgb = c.rgb;\n"
  "  const vec3 lum = vec3(0.299, 0.587, 0.114);\n"
  "\n"
  "  // 1) 锐化：亮度域死区 Unsharp（邻域 = 输出像素 ±1，同样经 samplerTransform）\n"
  "  if (sharpenA > 0.0) {\n"
  "    vec2 dcC = clamp(dc, outExtent.xy + vec2(1.0), outExtent.xy + sz - vec2(1.0));\n"
  "    float l0 = dot(rgb, lum);\n"
  "    float mn = ( dot(sample(image, samplerTransform(image, dcC + vec2(0.0,-1.0))).rgb, lum)\n"
  "               + dot(sample(image, samplerTransform(image, dcC + vec2(0.0, 1.0))).rgb, lum)\n"
  "               + dot(sample(image, samplerTransform(image, dcC + vec2(-1.0,0.0))).rgb, lum)\n"
  "               + dot(sample(image, samplerTransform(image, dcC + vec2( 1.0,0.0))).rgb, lum) ) * 0.25;\n"
  "    float diff = l0 - mn;\n"
  "    float thr = 0.75/255.0;\n"
  "    float amnt = 0.0;\n"
  "    if (diff > thr) amnt = sharpenA * (diff - thr);\n"
  "    else if (diff < -thr) amnt = sharpenA * (diff + thr);\n"
  "    float edge = smoothstep(0.75/255.0, 2.25/255.0, abs(diff));\n"
  "    rgb += amnt * edge;\n"
  "  }\n"
  "\n"
  "  // 2) 颗粒：预计算 tile + 幅度随亮度（分块用输出像素坐标，与 OHOS 一致）\n"
  "  if (grainOn > 0.0) {\n"
  "    vec2 nuv = vec2( fract(px.x * (1.0/128.0) + (13.0/128.0)), fract(px.y * (1.0/128.0) + (29.0/128.0)) ) * 128.0;\n"
  "    float g = sample(noise, nuv).r;              // 0..1，双线性\n"
  "    float ls = mix(0.35, 1.0, smoothstep(0.05, 0.85, dot(rgb, lum)));\n"
  "    float amp = grainOn * (24.0/255.0) * ls;\n"
  "    rgb += (g*2.0 - 1.0) * amp;\n"
  "  }\n"
  "\n"
  "  // 3) 磨皮（频率分离）：低频底=blur（矩阵后整图高斯，applyParams 预渲染），\n"
  "  // detail=rgb−base；YCbCr 肤色掩膜（放宽区间）+ 结构门控。\n"
  "  if (smoothS > 0.0) {\n"
  "    vec3 base = sample(blur, samplerTransform(blur, dc)).rgb;\n"
  "    vec3 det = rgb - base;\n"
  "    float margin = max(max(abs(det.r), abs(det.g)), abs(det.b));\n"
  "    float y  = dot(rgb, lum);\n"
  "    float cb = (-0.168736*rgb.r - 0.331264*rgb.g + 0.5*rgb.b) + (128.0/255.0);\n"
  "    float cr = ( 0.5*rgb.r - 0.418688*rgb.g - 0.081312*rgb.b) + (128.0/255.0);\n"
  "    float skin = smoothstep(40.0/255.0, 60.0/255.0, y) * (1.0 - smoothstep(250.0/255.0, 255.0/255.0, y))\n"
  "               * smoothstep(128.0/255.0, 140.0/255.0, cr) * (1.0 - smoothstep(172.0/255.0, 186.0/255.0, cr))\n"
  "               * smoothstep( 70.0/255.0,  85.0/255.0, cb) * (1.0 - smoothstep(120.0/255.0, 132.0/255.0, cb));\n"
  "    float edgeLow = (6.0 + smoothS*6.0) / 255.0;\n"
  "    float edgeHigh = edgeLow * 2.5;\n"
  "    float sc = smoothstep(edgeLow, edgeHigh, margin);\n"
  "    float baseRemove = 0.50*smoothS + 0.04;\n"
  "    float removal = clamp(baseRemove * skin * (1.0 - sc), 0.0, 1.0);\n"
  "    rgb = base + det * (1.0 - removal);\n"
  "  }\n"
  "\n"
  "  // 4) 暗角：uv 归一径向（与 OHOS vUV 公式逐项一致，中心不动、边缘压暗）\n"
  "  if (vigS > 0.0) {\n"
  "    vec2 uv = px / sz;\n"
  "    vec2 d2 = vec2(2.0*uv.x - 1.0, 2.0*uv.y - 1.0);\n"
  "    float dn = length(d2) * 0.70710678;\n"
  "    float ff = 1.0 - vigS * smoothstep(0.45, 1.0, dn);\n"
  "    rgb *= ff;\n"
  "  }\n"
  "\n"
  "  return vec4(rgb, c.a);\n"
  "}\n";

@interface PreviewEffectProcessor () {
  dispatch_queue_t _gpuQueue;
  CIContext *_ciContext;
  CGColorSpaceRef _workingColorSpace; // 自持有
  CIKernel *_beautyKernel;   // 统一锐化/颗粒/磨皮/暗角内核（进程一次）
  CIImage *_noiseTile;       // 预计算 128×128 颗粒 tile（一次性，消除逐帧随机）

  BOOL _active;
  PreviewEffectsParams _params;

  // 发布给光栅线程的最新成帧。每帧渲染都分配一块全新缓冲并发布，
  // 所有权一次性转移给复制的持有方（Flutter 引擎显示后释放），因此
  // 不做缓冲复用——复用会导致引擎仍在显示时被后续帧覆写（画面花屏）。
  _Atomic(CVPixelBufferRef) _publishedBuffer;
  // 忙碌标志：上一帧还在渲染时丢弃新帧，避免队列积压。
  _Atomic(bool) _busy;
}
@end

@implementation PreviewEffectProcessor

- (instancetype)init {
  self = [super init];
  if (self) {
    _gpuQueue = dispatch_queue_create("camerawesome.preview_effects.gpu", DISPATCH_QUEUE_SERIAL);
    // 【色彩空间根因修复】工作色域显式设为 γ 编码的 deviceRGB：
    // CIContext options:nil 的默认工作色域是 linear sRGB，导致
    //   1) CIColorMatrix 把为 γ 空间设计的对比度矩阵（枢轴 0.5）作用到 linear 值上
    //      → 对比度拉满时 mid-gray(linear 0.214) 被大幅推离枢轴 → 效果夸张
    //      （OHOS GL/Dart 成片均在 γ 空间字节上运算，故 OHOS 正常、iOS 异常）；
    //   2) 内核的 0..255 折算阈值（锐化死区、YCbCr 肤色区间）拿到 linear 值，语义错位。
    // working == output == deviceRGB（近似 sRGB γ）后整条链路零转换，字节直进直出，
    // 与 OHOS preview_fx（texture2D 返回 sRGB 字节）/ Dart 成片（ui.ColorFilter.matrix）
    // 的 γ 空间语义完全对齐。
    _workingColorSpace = CGColorSpaceCreateDeviceRGB();
    NSDictionary *contextOptions = @{
      (id)kCIContextWorkingColorSpace : (__bridge id)_workingColorSpace,
      (id)kCIContextOutputColorSpace : (__bridge id)_workingColorSpace,
    };
    id<MTLDevice> metalDevice = MTLCreateSystemDefaultDevice();
    if (metalDevice != nil) {
      _ciContext = [CIContext contextWithMTLDevice:metalDevice options:contextOptions];
    }
    if (_ciContext == nil) {
      _ciContext = [CIContext contextWithOptions:contextOptions];
    }
    _beautyKernel = [CIKernel kernelWithString:kPreviewBeautyKernelString];
    _noiseTile = [self makeNoiseTile];
    atomic_init(&_publishedBuffer, NULL);
    atomic_init(&_busy, false);
    _active = NO;
  }
  return self;
}

- (BOOL)active {
  return _active;
}

- (void)dealloc {
#if !__has_feature(objc_arc)
  [super dealloc];
#endif
}

#pragma mark - Parameters

- (void)updateEffects:(PreviewEffectsParams)params {
  dispatch_async(_gpuQueue, ^{
    BOOL wasActive = self->_active;
    self->_params = params;
    self->_active = params.hasMatrix || params.hasVignette || params.hasSmooth
                  || params.hasSharpen || params.hasGrain;
    // 效果全部关闭时立即清残留成帧（render: 停用路径亦兜底每帧清理）。
    if (wasActive && !self->_active) {
      CVPixelBufferRef stale = atomic_exchange(&self->_publishedBuffer, NULL);
      if (stale != NULL) CFRelease(stale);
    }
  });
}

#pragma mark - Render

- (void)render:(CVPixelBufferRef _Nonnull)input {
  if (input == NULL) return;
  if (!_active) {
    // 直通：不投递 GPU，取景器直接用原始帧。同时清掉残留成帧——
    // copyDisplayBuffer 已改为「非消费式」：成帧会被反复返回直到新帧发布，
    // 停用后若不清，取景器将一直显示最后一张处理帧（画面冻结）。
    dispatch_async(_gpuQueue, ^{
      CVPixelBufferRef stale = atomic_exchange(&self->_publishedBuffer, NULL);
      if (stale != NULL) CFRelease(stale);
    });
    return;
  }

  // 忙碌则丢弃本帧（保持队列不积压、帧率平滑；显示保持上一帧）。
  bool expected = false;
  if (!atomic_compare_exchange_strong(&_busy, &expected, true)) {
    return;
  }
  CFRetain(input);
  dispatch_async(_gpuQueue, ^{
    @autoreleasepool {
      CVPixelBufferRef src = (CVPixelBufferRef)CFAutorelease(input);
      [self renderSync:src];
    }
    atomic_store(&self->_busy, false);
  });
}

/// 在 _gpuQueue 上同步执行渲染并发布成帧。
- (void)renderSync:(CVPixelBufferRef)input {
  // 输入缓冲显式按 deviceRGB 解释（kCIImageColorSpace 覆盖缓冲自带标签）：
  // 相机 BGRA 帧若带 P3/709 标签，默认会被转换到工作色域；而 WYSIWYG 直出成片
  // （captureVideoFrameToJpegAtPath）与 Flutter 纹理显示都把同一批字节当 sRGB 直读。
  // 强制同色域解释保证「取景器效果 == 成片 == 字节级一致」，杜绝隐藏转换。
  CIImage *image = [CIImage imageWithCVPixelBuffer:input
                                          options:@{(id)kCIImageColorSpace : (__bridge id)_workingColorSpace}];
  if (image == NULL) return;

  CGFloat w = CVPixelBufferGetWidth(input);
  CGFloat h = CVPixelBufferGetHeight(input);
  CGFloat longSide = MAX(w, h);

  CIImage *result = [self applyParams:image longSide:longSide];

  // 每帧分配全新输出缓冲（所有权随发布转移，不复用，避免引擎仍显示时被覆写）。
  CVPixelBufferRef outBuf = NULL;
  NSDictionary *attrs = @{
    (id)kCVPixelBufferIOSurfacePropertiesKey : @{},
    (id)kCVPixelBufferCGImageCompatibilityKey : @NO,
    (id)kCVPixelBufferCGBitmapContextCompatibilityKey : @NO,
  };
  if (CVPixelBufferCreate(kCFAllocatorDefault, (size_t)w, (size_t)h, kCVPixelFormatType_32BGRA,
                          (__bridge CFDictionaryRef)attrs, &outBuf) != kCVReturnSuccess ||
      outBuf == NULL) {
    return;
  }

  [_ciContext render:result toCVPixelBuffer:outBuf bounds:[result extent] colorSpace:_workingColorSpace];

  // 原子发布新成帧（取走并释放旧帧）。
  CVPixelBufferRef old = atomic_exchange_explicit(&_publishedBuffer, outBuf, memory_order_release);
  if (old != NULL) CFRelease(old);
}

/// 组装完整效果链（顺序与成片统一：矩阵 → 锐化 → 颗粒 → 磨皮 → 暗角）。
- (CIImage *)applyParams:(CIImage *)input longSide:(CGFloat)longSide {
  CIImage *result = input;

  if (_params.hasMatrix) {
    result = [self applyColorMatrix:result];
  }

  // 统一内核：锐化 + 颗粒 + 磨皮 + 暗角 单 pass（无空间效果时直通，零 GPU 开销）。
  // 强度回到规格 a = v/100×1.2（上限 1.2）。此前被全局提到 ×6.0 造成真机「效果太重」，
  // 现与 Dart applyPerPixelEffectsImg / OHOS C++ photo_processor.cpp / preview_fx.cpp
  // 三端同步回调到规格；死区 0.75、门控 (0.75,2.25) 不变，保证预览==成片==双端。
  double sharpenA = (_params.hasSharpen && _params.sharpen > 0) ? fmin(_params.sharpen / 100.0 * 1.2, 1.2) : 0.0;
  double vigS     = (_params.hasVignette && _params.vignette > 0) ? _params.vignette / 100.0 : 0.0;
  double smoothS  = (_params.hasSmooth && _params.smooth > 0) ? _params.smooth / 100.0 : 0.0;
  double grainS   = (_params.hasGrain && _params.grain > 0) ? _params.grain / 100.0 : 0.0;
  // 噪声 tile 构建失败（malloc 失败的病态路径）时禁用颗粒，避免采样未定义区域。
  if (_noiseTile == nil) grainS = 0.0;

  // 磨皮频率分离的低频底图（base）：矩阵后整图高斯（CIGaussianBlur，GPU）。
  // clamp 防边缘透黑、crop 回原 extent 与 destCoord() 对齐。
  // σ 随强度 9..24px（预览像素）——OHOS 的低频底在 1/3 分辨率 FBO 里做高斯再
  // 双线性升采样回全分辨率（升采样本身即一次低通），其等效低频核在全预览分辨率
  // 约 3 倍于「3..8px」；原 σ 在 iOS 全分辨取景器上只滤掉高频细节，base≈rgb，
  // 磨皮不可感知（真机反馈「磨皮没效果」）。removal/门控曲线仍与成片严格一致。
  CIImage *blurImg = nil;
  if (smoothS > 0) {
    const CGFloat sigma = 9.0 + 15.0 * smoothS;
    CIImage *clamped = [result imageByClampingToExtent];
    CIImage *blurred = [clamped imageByApplyingFilter:@"CIGaussianBlur"
                                withInputParameters:@{ @"inputRadius": @(sigma) }];
    blurImg = [blurred imageByCroppingToRect:result.extent];
  }

  if ((sharpenA > 0 || vigS > 0 || smoothS > 0 || grainS > 0) && _beautyKernel) {
    const CGRect extent = input.extent;
    const BOOL hasNoise = (_noiseTile != nil);
    CIImage *noise = _noiseTile ?: result;
    const CGRect noiseExtent = hasNoise ? _noiseTile.extent : CGRectNull;
    // blur 缺席时传 result 自身（smoothS==0 不进磨皮分支，参数占位而已）。
    // outExtent（vec4 = origin.x/origin.y/width/height）：内核用它把 destCoord()
    // 归一为输出像素坐标/UV（几何基准唯一可信来源，与 OHOS vUV·uSize 等价）。
    // ROI 回调（此前 roiCallback:nil 的 1:1 假设是取景器压暗的根因之一）：
    //   index 0（image）：锐化邻域 ±1 输出像素 → 外扩 2px 覆盖邻域采样；
    //   index 1（noise）：任意输出位置都可能采样 [0,128)² → 恒返回噪声 tile 全 extent，
    //                     否则输出区域不在 tile 附近时噪声输入区域为空 → 采样返回黑
    //                     → rgb += (0×2−1)×amp → 整图压暗且无颗粒纹理；
    //   index 2（blur）：1:1 采样 → 返回原 rect。
    result = [_beautyKernel applyWithExtent:extent
                                 roiCallback:^CGRect(int index, CGRect rect) {
                                   if (index == 0) return CGRectInset(rect, -2.0, -2.0);
                                   if (index == 1) {
                                     // tile 缺失时 noise 参数退化为 result（grainS 已被置 0，
                                     // 内核不会采样它），按 1:1+外扩 返回安全区域。
                                     return hasNoise ? noiseExtent : CGRectInset(rect, -2.0, -2.0);
                                   }
                                   return rect;
                                 }
                                   arguments:@[ result, noise, blurImg ?: result,
                                                [CIVector vectorWithCGRect:extent],
                                                @(sharpenA), @(vigS), @(smoothS), @(grainS) ]];
  }

  return result;
}

/// 应用 Flutter 20 元素色彩矩阵 → CIColorMatrix。
- (CIImage *)applyColorMatrix:(CIImage *)image {
  const double *m = _params.matrix;
  CIVector *r = [CIVector vectorWithX:m[0] Y:m[1] Z:m[2] W:m[3]];
  CIVector *g = [CIVector vectorWithX:m[5] Y:m[6] Z:m[7] W:m[8]];
  CIVector *b = [CIVector vectorWithX:m[10] Y:m[11] Z:m[12] W:m[13]];
  CIVector *a = [CIVector vectorWithX:m[15] Y:m[16] Z:m[17] W:m[18]];
  // Flutter 的 offset 列按 0..255 表示，CIColorMatrix 的 bias 按 0..1 表示。
  CIVector *bias = [CIVector vectorWithX:m[4]/255.0 Y:m[9]/255.0 Z:m[14]/255.0 W:m[19]/255.0];
  return [image imageByApplyingFilter:@"CIColorMatrix"
                  withInputParameters:@{ @"inputRVector": r,
                                         @"inputGVector": g,
                                         @"inputBVector": b,
                                         @"inputAVector": a,
                                         @"inputBiasVector": bias }];
}

/// 预计算 128×128 单通道颗粒 tile（固定 LCG 种子，与 OHOS C++/预览 shader 同分布）。
/// 每进程构建一次并复用，替代逐帧 CIRandomGenerator → 消灭取景器卡顿，且离线复用。
- (CIImage *)makeNoiseTile {
  const size_t tex = 128;
  const size_t bytes = tex * tex;
  uint8_t *buf = (uint8_t *)malloc(bytes);
  if (!buf) return nil;
  uint32_t seed = 0x85EBCA6Bu;
  for (size_t i = 0; i < bytes; ++i) {
    seed = seed * 1664525u + 1013904223u;
    const double rnd = (double)((seed >> 8) & 0xFFFFu) * (1.0 / 65535.0); // 0..1
    buf[i] = (uint8_t)llround(rnd * 255.0);
  }
  CGColorSpaceRef cs = CGColorSpaceCreateDeviceGray();
  CIImage *img = [CIImage imageWithBitmapData:[NSData dataWithBytesNoCopy:buf length:bytes freeWhenDone:YES]
                                     bytesPerRow:tex
                                            size:CGSizeMake(tex, tex)
                                          format:kCIFormatR8
                                      colorSpace:cs];
  CGColorSpaceRelease(cs);
  return img;
}

#pragma mark - Display buffer

- (CVPixelBufferRef _Nullable)copyDisplayBuffer {
  // 【非消费式读取】光栅线程每帧（显示刷新率 60-120Hz）都会调用本方法，而成帧
  // 发布率仅为相机帧率（≤30Hz）。若消费式取走（换空），两次发布之间会返回 NULL，
  // 调用方（CameraPreview.copyPixelBuffer）将回落到「未处理的原始帧」→ 处理帧/
  // 原始帧逐帧交替显示 = 取景器闪烁（清晰度等强对比效果下尤其明显）。
  // 改为：原子取走所有权 → 为引擎 retain 一份 → 原子放回；若期间发布了新成帧
  // （放回失败），释放本次取走的所有权（新帧保留在槽内，引擎那份 retain 仍有效）。
  CVPixelBufferRef buf = atomic_exchange(&_publishedBuffer, NULL);
  if (buf == NULL) return NULL;
  CFRetain(buf);
  CVPixelBufferRef expected = NULL;
  if (!atomic_compare_exchange_strong(&_publishedBuffer, &expected, buf)) {
    CFRelease(buf);
  }
  return buf;
}

- (void)flush {
  dispatch_sync(_gpuQueue, ^{
    CVPixelBufferRef pub = atomic_exchange(&self->_publishedBuffer, NULL);
    if (pub != NULL) CFRelease(pub);
  });
}

- (void)dispose {
  dispatch_sync(_gpuQueue, ^{
    CVPixelBufferRef pub = atomic_exchange(&self->_publishedBuffer, NULL);
    if (pub != NULL) CFRelease(pub);
    if (self->_workingColorSpace != NULL) {
      CFRelease(self->_workingColorSpace);
      self->_workingColorSpace = NULL;
    }
    self->_ciContext = nil;
  });
}

@end