//
//  PreviewEffectProcessor.m
//  camerawesome
//
//  iOS 取景器逐帧效果处理器实现。详见 PreviewEffectProcessor.h 注释。
//

#import "PreviewEffectProcessor.h"

// 统一效果内核：在一遍内完成 锐化(亮度死区Unsharp)→颗粒(tile+亮度)→磨皮(频率分离+肤色掩膜+结构门控)→暗角。
// 数值语义与 OHOS C++ bake（photo_processor.cpp）及预览 FragmentShader 一致（颜色按 0..1，阈值/幅度相应折算）：
//   - 锐化：diff=luma−4邻域均值，死区 thr=1/255，amnt=a×(diff±thr)，乘 smoothstep(1/255,2.5/255,|diff|)
//   - 颗粒：128×128 预置 tile 双线性采样（固定 offset 13/128,29/128），幅度=grains×24/255×mix(0.35,1.0,smoothstep(0.05,0.85,luma))
//   - 磨皮：YCbCr 肤色概率(BT.601, 0..255 区间折算 0..1) × 结构门控，out=base+detail×(1−removal)
//   - 暗角：factor=1−vigS×smoothstep(0.45,1.0,dn)，dn=length(归一径向)/√2
static NSString *const kPreviewBeautyKernelString = @" \n"
  "kernel vec4 previewBeauty(sampler image, sampler noise, float sharpenA, float vigS, float smoothS, float grainOn) {\n"
  "  vec2 p = samplerTransform(image, destCoord());\n"
  "  vec2 tsp = samplerSize(image);\n"
  "  vec4 c = sample(image, p);\n"
  "  vec3 rgb = c.rgb;\n"
  "  const vec3 lum = vec3(0.299, 0.587, 0.114);\n"
  "  vec2 cp = clamp(p, vec2(1.0), tsp - vec2(1.0));\n"
  "\n"
  "  // 1) 锐化：亮度域死区 Unsharp\n"
  "  float l0 = dot(rgb, lum);\n"
  "  float mn = ( dot(sample(image, cp+vec2(0.0,-1.0)).rgb, lum)\n"
  "             + dot(sample(image, cp+vec2(0.0, 1.0)).rgb, lum)\n"
  "             + dot(sample(image, cp+vec2(-1.0,0.0)).rgb, lum)\n"
  "             + dot(sample(image, cp+vec2( 1.0,0.0)).rgb, lum) ) * 0.25;\n"
  "  float diff = l0 - mn;\n"
  "  float thr = 1.0/255.0;\n"
  "  float amnt = 0.0;\n"
  "  if (diff > thr) amnt = sharpenA * (diff - thr);\n"
  "  else if (diff < -thr) amnt = sharpenA * (diff + thr);\n"
  "  float edge = smoothstep(1.0/255.0, 2.5/255.0, abs(diff));\n"
  "  rgb += amnt * edge;\n"
  "\n"
  "  // 2) 颗粒：预计算 tile + 幅度随亮度（杜绝每帧 CIRandomGenerator 的滞后）\n"
  "  if (grainOn > 0.0) {\n"
  "    vec2 nuv = vec2( fract(p.x * (1.0/128.0) + (13.0/128.0)), fract(p.y * (1.0/128.0) + (29.0/128.0)) ) * 128.0;\n"
  "    float g = sample(noise, nuv).r;              // 0..1，双线性\n"
  "    float ls = mix(0.35, 1.0, smoothstep(0.05, 0.85, dot(rgb, lum)));\n"
  "    float amp = grainOn * (24.0/255.0) * ls;\n"
  "    rgb += (g*2.0 - 1.0) * amp;\n"
  "  }\n"
  "\n"
  "  // 3) 磨皮：频率分离 + YCbCr 肤色 + 结构门控（5-tap 低通近似，不整图模糊）\n"
  "  if (smoothS > 0.0) {\n"
  "    vec3 sU = sample(image, cp+vec2(0.0,-1.0)).rgb;\n"
  "    vec3 sD = sample(image, cp+vec2(0.0, 1.0)).rgb;\n"
  "    vec3 sL = sample(image, cp+vec2(-1.0,0.0)).rgb;\n"
  "    vec3 sR = sample(image, cp+vec2( 1.0,0.0)).rgb;\n"
  "    vec3 base = (rgb*4.0 + sU + sD + sL + sR) / 8.0;\n"
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
  "  // 4) 暗角：单一解析式（预览==成片逐像素一致）\n"
  "  if (vigS > 0.0) {\n"
  "    vec2 d2 = vec2((2.0*p.x - tsp.x)/tsp.x, (2.0*p.y - tsp.y)/tsp.y);\n"
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
  CIColorSpace _workingColorSpace; // 自持有
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
    id<MTLDevice> metalDevice = MTLCreateSystemDefaultDevice();
    if (metalDevice != nil) {
      _ciContext = [CIContext contextWithMTLDevice:metalDevice options:nil];
    }
    if (_ciContext == nil) {
      _ciContext = [CIContext contextWithOptions:nil];
    }
    _workingColorSpace = CGColorSpaceCreateDeviceRGB();
    _beautyKernel = [CIKernel kernelWithString:kPreviewBeautyKernelString];
    _noiseTile = [self makeNoiseTile];
    atomic_init(&_publishedBuffer, NULL);
    atomic_init(&_busy, false);
    _poolIndex = 0;
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
    self->_params = params;
    self->_active = params.hasMatrix || params.hasVignette || params.hasSmooth
                  || params.hasSharpen || params.hasGrain;
  });
}

#pragma mark - Render

- (void)render:(CVPixelBufferRef _Nonnull)input {
  if (input == NULL) return;
  if (!_active) return; // 直通：不投递 GPU，取景器直接用原始帧

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
  CIImage *image = [CIImage imageWithCVPixelBuffer:input];
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
  double sharpenA = (_params.hasSharpen && _params.sharpen > 0) ? fmin(_params.sharpen / 100.0, 1.2) : 0.0;
  double vigS     = (_params.hasVignette && _params.vignette > 0) ? _params.vignette / 100.0 : 0.0;
  double smoothS  = (_params.hasSmooth && _params.smooth > 0) ? _params.smooth / 100.0 : 0.0;
  double grainS   = (_params.hasGrain && _params.grain > 0) ? _params.grain / 100.0 : 0.0;

  if ((sharpenA > 0 || vigS > 0 || smoothS > 0 || grainS > 0) && _beautyKernel) {
    CIImage *noise = _noiseTile ?: result;
    result = [_beautyKernel applyWithExtent:input.extent roiCallback:nil
                                   arguments:@[ result, noise,
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
  CVPixelBufferRef buf = atomic_exchange(&_publishedBuffer, NULL);
  if (buf == NULL) return NULL;
  // 取得所有权，调用方负责 CFRelease。
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