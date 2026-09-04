//
//  PreviewEffectProcessor.m
//  camerawesome
//
//  iOS 取景器逐帧效果处理器实现。详见 PreviewEffectProcessor.h 注释。
//

#import "PreviewEffectProcessor.h"

@interface PreviewEffectProcessor () {
  dispatch_queue_t _gpuQueue;
  CIContext *_ciContext;
  CIColorSpace _workingColorSpace; // 自持有

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

/// 组装完整效果链（顺序与成片 image 包管线一致：矩阵 → 暗角 → 磨皮 → 锐化 → 颗粒）。
- (CIImage *)applyParams:(CIImage *)input longSide:(CGFloat)longSide {
  CIImage *result = input;

  if (_params.hasMatrix) {
    result = [self applyColorMatrix:result];
  }

  if (_params.hasVignette && _params.vignette > 0) {
    // 匹配 Dart 暗角：径向、边缘压暗，强度 = vignette/100 * 0.5。
    CGFloat intensity = (_params.vignette / 100.0) * 0.8;
    CGFloat radius = longSide * 0.6;
    result = [result imageByApplyingFilter:@"CIVignette"
                   withInputParameters:@{ @"inputIntensity": @(intensity),
                                          @"inputRadius": @(radius) }];
  }

  if (_params.hasSmooth && _params.smooth > 0) {
    result = [self applyBeautySmooth:result];
  }

  if (_params.hasSharpen && _params.sharpen > 0) {
    CGFloat s = _params.sharpen / 100.0;
    CGFloat radius = 0.8 + s * 3.0;
    CGFloat intensity = 0.4 + s * 1.1;
    result = [result imageByApplyingFilter:@"CIUnsharpMask"
                   withInputParameters:@{ @"inputRadius": @(radius),
                                          @"inputIntensity": @(intensity) }];
  }

  if (_params.hasGrain && _params.grain > 0) {
    result = [self applyGrain:result];
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

/// 磨皮（保边）：整图高斯模糊，用「与原始差异的逆」作为软掩码叠回，
/// 平坦区域取模糊（磨皮）、边缘取原图（保持锐利），与成片 skin_smooth 语义一致。
- (CIImage *)applyBeautySmooth:(CIImage *)image {
  CGFloat strength = _params.smooth / 100.0;
  CGFloat blurRadius = 1.5 + strength * 6.0; // 满档 ~7.5px

  CIImage *blur = [image imageByApplyingGaussianBlur:@(blurRadius)];
  CIImage *edgeDiff = [image imageByApplyingFilter:@"CIDifferenceBlendMode"
                              withInputParameters:@{ @"inputBackgroundImage": blur }];
  // 边缘（差异大）→黑，平坦（差异小）→白；再轻度模糊羽化掩码边界。
  CIImage *edgeInverted = [edgeDiff imageByApplyingFilter:@"CIColorInvert"];
  CIImage *mask = [edgeInverted imageByApplyingGaussianBlur:@(blurRadius * 0.6)];

  // BlendWithMask: 掩码黑→前景(原图/锐)，掩码白→背景(模糊)。平坦区域取模糊。
  return [blur imageByApplyingFilter:@"CIBlendWithMask"
                  withInputParameters:@{ @"inputBackgroundImage": image,
                                         @"inputMaskImage": mask }];
}

/// 颗粒：随机噪声压暗透明度后 source-over 复合（近似胶片颗粒，暗部更明显）。
- (CIImage *)applyGrain:(CIImage *)image {
  CGFloat amount = (_params.grain / 100.0) * 0.12;
  CIImage *randomGen = [CIFilter filterWithName:@"CIRandomGenerator"].outputImage;
  // 灰度化并压低 alpha，形成「高斯噪声覆盖层」。
  CIImage *gray = [randomGen imageByApplyingFilter:@"CIColorControls"
                             withInputParameters:@{ @"inputSaturation": @(0.0),
                                                    @"inputContrast": @(1.6),
                                                    @"inputBrightness": @(0.0) }];
  CIImage *noiseLayer = [gray imageByApplyingFilter:@"CIColorMatrix"
                               withInputParameters:@{ @"inputRVector": [CIVector vectorWithX:1 Y:0 Z:0 W:0],
                                                      @"inputGVector": [CIVector vectorWithX:0 Y:1 Z:0 W:0],
                                                      @"inputBVector": [CIVector vectorWithX:0 Y:0 Z:1 W:0],
                                                      @"inputAVector": [CIVector vectorWithX:0 Y:0 Z:0 W:amount] }];
  return [noiseLayer imageByCompositingOverImage:image];
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