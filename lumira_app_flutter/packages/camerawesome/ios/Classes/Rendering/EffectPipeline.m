//
//  EffectPipeline.m
//  camerawesome
//
//  iOS 取景器实时效果管线实现（CoreImage / Metal GPU 加速）。
//
//  效果链顺序与 dart worker（SkinSmoother / applyPerPixelEffectsImg / applyVignetteImg）
//  保持一致：色彩矩阵 → 磨皮 → 清晰度 → 锐化 → 颗粒 → 暗角。
//
//  设计要点：
//  - 共享单例 + 内部 NSLock 保护参数；didOutputSampleBuffer 在主队列调用，
//    setter（Flutter 通道）同样在主队列，锁主要防将来改并发。
//  - 磨皮采用 CIColorCube 肤色查找表（skin LUT）生成肤色掩膜 + 高斯模糊的
//    柔焦近似：皮肤区用模糊结果、非皮肤区保留原图锐利细节（与成片语义一致，
//    但取景器阶段为轻量实时近似，精度以 worker 的 SkinSmoother 为准）。
//  - 性能预算：预览档分辨率下单帧 GPU ≤ 8ms。
//

#import "EffectPipeline.h"
#import <Metal/Metal.h>
#import <Accelerate/Accelerate.h>

@implementation EffectPipeline {
    CIContext *_context;
    CIFilter *_colorFilter;
    // 磨皮相关
    CIFilter *_blurFilter;       // 高斯模糊（磨皮/清晰度共用）
    CIFilter *_maskBlend;        // CIBlendWithMask（磨皮合成）
    NSData *_skinCubeData;       // 肤色查找表（CIColorCube 数据）
    CIFilter *_skinCube;         // CIColorCube → 肤色掩膜
    // 清晰度
    CIFilter *_addMode;          // CIAddBlendMode
    CIFilter *_subtractMode;     // CISubtractBlendMode
    // 锐化
    CIFilter *_sharpen;          // CISharpenLuminance
    // 颗粒
    CIFilter *_randomGen;        // CIRandomGenerator
    CIFilter *_vignette;         // CIVignette
    BOOL _initialized;
    NSLock *_lock;
}

+ (EffectPipeline *)shared {
    static EffectPipeline *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[EffectPipeline alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _lock = [[NSLock alloc] init];
        [self reset];
        _skinCubeData = [EffectPipeline _buildSkinCube16x16x16];
        _skinCube = [CIFilter filterWithName:@"CIColorCube"];
    }
    return self;
}

- (void)reset {
    [_lock lock];
    self.colorMatrix = nil;
    _smoothStrength = 0;
    _clarity = 0;
    _sharpen = 0;
    _grain = 0;
    _vignette = 0;
    [_lock unlock];
}

- (BOOL)hasEffects {
    [_lock lock];
    BOOL hasAny =
        self.colorMatrix.count == 20 || _smoothStrength > 0 || _clarity != 0 ||
        _sharpen > 0 || _grain > 0 || _vignette > 0;
    [_lock unlock];
    return hasAny;
}

/// 构建肤色查找表：输入 RGB（0..15 量化），输出 RGBA 掩膜。
/// 这里用简化的“低饱和 + 中等亮度”经验规则近似肤色，避免引入过重依赖。
/// cube 尺寸 16×16×16，每元素 RGBA(16bit) 共 16*16*16*4*2 字节。
+ (NSData *)_buildSkinCube16x16x16 {
    const int N = 16;
    size_t count = N * N * N;
    unsigned char *buf = calloc(count * 4, 1);
    if (!buf) return nil;
    for (int ir = 0; ir < N; ir++) {
        for (int ig = 0; ig < N; ig++) {
            for (int ib = 0; ib < N; ib++) {
                double r = ir / (double)(N - 1);
                double g = ig / (double)(N - 1);
                double b = ib / (double)(N - 1);
                double mx = MAX(r, MAX(g, b));
                double mn = MIN(r, MIN(g, b));
                double sat = (mx - mn);            // 0..1
                double lum = mx;                    // 0..1
                // 肤色规则：低-中饱和、中高亮度
                double skin = 0.0;
                if (lum > 0.18 && lum < 0.95 && sat > 0.03 && sat < 0.65) {
                    skin = 1.0 - MIN(1.0, (lum - 0.5) * (lum - 0.5) * 12.0 +
                                            sat * 1.4);
                    skin = MAX(0.0, MIN(1.0, skin));
                }
                size_t idx = ((ir * N + ig) * N + ib) * 4;
                // CIColorCube 16-bit 数据：每通道占两字节，big-endian（高字节在前）。
                unsigned char r16 = (unsigned char)((unsigned short)(skin * 65535.0) >> 8);
                unsigned char r8  = (unsigned char)((unsigned short)(skin * 65535.0) & 0xFF);
                unsigned char g16 = (unsigned char)((unsigned short)(skin * 65535.0) >> 8);
                unsigned char g8  = (unsigned char)((unsigned short)(skin * 65535.0) & 0xFF);
                unsigned char b16 = (unsigned char)((unsigned short)(skin * 65535.0) >> 8);
                unsigned char b8  = (unsigned char)((unsigned short)(skin * 65535.0) & 0xFF);
                unsigned char a16 = 0xFF;
                unsigned char a8  = 0xFF;
                buf[idx + 0] = r16; buf[idx + 1] = r8;
                buf[idx + 2] = g16; buf[idx + 3] = g8;
                buf[idx + 4] = b16; buf[idx + 5] = b8;
                buf[idx + 6] = a16; buf[idx + 7] = a8;
            }
        }
    }
    return [NSData dataWithBytesNoCopy:buf
                                length:count * 8
                          freeWhenDone:YES];
}

- (BOOL)ensureInitialized {
    [_lock lock];
    if (_initialized) {
        [_lock unlock];
        return YES;
    }
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    NSDictionary *opts = @{kCIContextWorkingColorSpace: (id)kCFNull,
                           kCIContextOutputColorSpace: (id)kCFNull};
    if (device != nil) {
        _context = [CIContext contextWithMTLDevice:device options:opts];
    } else {
        _context = [CIContext contextWithOptions:opts];
    }
    if (_context == nil) {
        [_lock unlock];
        return NO;
    }
    _colorFilter = [CIFilter filterWithName:@"CIColorMatrix"];
    _blurFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
    _maskBlend = [CIFilter filterWithName:@"CIBlendWithMask"];
    _addMode = [CIFilter filterWithName:@"CIAddBlendMode"];
    _subtractMode = [CIFilter filterWithName:@"CISubtractBlendMode"];
    _sharpen = [CIFilter filterWithName:@"CISharpenLuminance"];
    _randomGen = [CIFilter filterWithName:@"CIRandomGenerator"];
    _vignette = [CIFilter filterWithName:@"CIVignette"];
    _initialized = YES;
    [_lock unlock];
    return YES;
}

- (BOOL)processPixelBuffer:(CVPixelBufferRef)input toOutput:(CVPixelBufferRef)output {
    if (input == NULL || output == NULL) return NO;
    if (![self ensureInitialized]) return NO;

    [_lock lock];
    NSArray<NSNumber *> *matrix = [self.colorMatrix copy];
    int smooth = _smoothStrength;
    double clarity = _clarity;
    int sharpen = _sharpen;
    int grain = _grain;
    int vignette = _vignette;
    BOOL hasColor = (matrix.count == 20) && ![self _isIdentityMatrix:matrix];
    BOOL hasEffect = hasColor || smooth > 0 || clarity != 0 || sharpen > 0 ||
                     grain > 0 || vignette > 0;
    [_lock unlock];

    if (!hasEffect) {
        return [self _copyPixelBuffer:input toOutput:output];
    }

    @autoreleasepool {
        CIImage *image = [CIImage imageWithCVPixelBuffer:input];
        if (image == nil) return NO;

        size_t w = CVPixelBufferGetWidth(input);
        size_t h = CVPixelBufferGetHeight(input);

        // 1. 色彩矩阵
        if (hasColor) {
            [self _applyColorMatrix:matrix toImage:&image];
        }

        // 2. 磨皮（肤色掩膜柔焦）
        if (smooth > 0) {
            double radius = 1.5 + smooth / 100.0 * 4.0;
            [_blurFilter setValue:image forKey:kCIInputImageKey];
            [_blurFilter setValue:@(radius) forKey:kCIInputRadiusKey];
            CIImage *blurred = _blurFilter.outputImage;

            // 肤色掩膜：把原图经 CIColorCube 查询得到灰度掩膜（白色=皮肤）
            CIFilter *cube = _skinCube;
            [cube setValue:image forKey:kCIInputImageKey];
            [cube setValue:_skinCubeData forKey:@"inputCubeData"];
            [cube setValue:@16 forKey:@"inputCubeDimension"];
            CIImage *mask = [cube.outputImage imageBySettingAlphaOneInExtent:image.extent];

            // blend = blurred(前景) 与 image(背景) 按 mask 混合
            [_maskBlend setValue:blurred forKey:kCIInputImageKey];
            [_maskBlend setValue:image forKey:kCIInputBackgroundImageKey];
            [_maskBlend setValue:mask forKey:kCIInputMaskImageKey];
            image = _maskBlend.outputImage;
        }

        // 3. 清晰度（中频对比）：原图 + (原图-模糊)*amount*sign
        if (clarity != 0) {
            double amount = fabs(clarity) / 100.0 * 0.6;
            double sign = clarity > 0 ? 1.0 : -1.0;
            [_blurFilter setValue:image forKey:kCIInputImageKey];
            [_blurFilter setValue:@3.0 forKey:kCIInputRadiusKey];
            CIImage *blurred = _blurFilter.outputImage;

            [_subtractMode setValue:image forKey:kCIInputImageKey];
            [_subtractMode setValue:blurred forKey:kCIInputBackgroundImageKey];
            CIImage *delta = _subtractMode.outputImage;

            double s = amount * sign;
            delta = [delta imageByApplyingFilter:@"CIColorMatrix"
                              withInputParameters:@{
                                  @"inputRVector": [CIVector vectorWithX:s Y:0 Z:0 W:0],
                                  @"inputGVector": [CIVector vectorWithX:0 Y:s Z:0 W:0],
                                  @"inputBVector": [CIVector vectorWithX:0 Y:0 Z:s W:0],
                                  @"inputAVector": [CIVector vectorWithX:0 Y:0 Z:0 W:1],
                              }];
            [_addMode setValue:image forKey:kCIInputImageKey];
            [_addMode setValue:delta forKey:kCIInputBackgroundImageKey];
            image = _addMode.outputImage;
        }

        // 4. 锐化
        if (sharpen > 0) {
            double intensity = 0.2 + sharpen / 100.0 * 1.3;
            [_sharpen setValue:image forKey:kCIInputImageKey];
            [_sharpen setValue:@(intensity) forKey:kCIInputSharpnessKey];
            image = _sharpen.outputImage;
        }

        // 5. 颗粒（胶片噪点）
        if (grain > 0) {
            double intensity = grain / 100.0 * 0.05;
            CIImage *rand = _randomGen.outputImage;
            rand = [rand imageByApplyingFilter:@"CIColorMatrix"
                             withInputParameters:@{
                                 @"inputRVector": [CIVector vectorWithX:intensity Y:0 Z:0 W:0],
                                 @"inputGVector": [CIVector vectorWithX:0 Y:intensity Z:0 W:0],
                                 @"inputBVector": [CIVector vectorWithX:0 Y:0 Z:intensity W:0],
                                 @"inputAVector": [CIVector vectorWithX:0 Y:0 Z:0 W:0],
                             }];
            [_addMode setValue:image forKey:kCIInputImageKey];
            [_addMode setValue:rand forKey:kCIInputBackgroundImageKey];
            image = _addMode.outputImage;
        }

        // 6. 暗角
        if (vignette > 0) {
            double strength = vignette / 100.0 * 0.6;
            CIImage *bounded = [image imageByClampingToExtent];
            [_vignette setValue:bounded forKey:kCIInputImageKey];
            [_vignette setValue:[CIVector vectorWithX:w / 2.0 Y:h / 2.0]
                         forKey:@"inputCenter"];
            [_vignette setValue:@(strength) forKey:@"inputIntensity"];
            [_vignette setValue:@(w * 0.7) forKey:@"inputRadius"];
            image = [_vignette.outputImage
                imageByCroppingToRect:CGRectMake(0, 0, w, h)];
        }

        if (image == nil) return NO;

        CVPixelBufferLockBaseAddress(output, 0);
        [_context render:image toCVPixelBuffer:output];
        CVPixelBufferUnlockBaseAddress(output, 0);
        return YES;
    }
}

/// 将 5x4 色彩矩阵（20 double，dart ColorFilter.matrix 语义）应用到 CIImage。
- (void)_applyColorMatrix:(NSArray<NSNumber *> *)m toImage:(CIImage **)imgPtr {
    CIFilter *cf = _colorFilter;
    [cf setValue:*imgPtr forKey:kCIInputImageKey];
    [cf setValue:[CIVector vectorWithX:m[0].doubleValue Y:m[1].doubleValue
                                    Z:m[2].doubleValue W:m[3].doubleValue]
          forKey:@"inputRVector"];
    [cf setValue:[CIVector vectorWithX:m[5].doubleValue Y:m[6].doubleValue
                                    Z:m[7].doubleValue W:m[8].doubleValue]
          forKey:@"inputGVector"];
    [cf setValue:[CIVector vectorWithX:m[10].doubleValue Y:m[11].doubleValue
                                    Z:m[12].doubleValue W:m[13].doubleValue]
          forKey:@"inputBVector"];
    [cf setValue:[CIVector vectorWithX:m[15].doubleValue Y:m[16].doubleValue
                                    Z:m[17].doubleValue W:m[18].doubleValue]
          forKey:@"inputAVector"];
    [cf setValue:[CIVector vectorWithX:m[4].doubleValue Y:m[9].doubleValue
                                    Z:m[14].doubleValue W:m[19].doubleValue]
          forKey:@"inputBiasVector"];
    *imgPtr = cf.outputImage;
}

- (BOOL)_isIdentityMatrix:(NSArray<NSNumber *> *)m {
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            double v = m[i * 5 + j].doubleValue;
            double e = (i == j) ? 1.0 : 0.0;
            if (fabs(v - e) > 0.001) return NO;
        }
        if (fabs(m[i * 5 + 4].doubleValue) > 0.001) return NO;
    }
    return YES;
}

/// 直通拷贝（无效果时的语义统一输出）。
- (BOOL)_copyPixelBuffer:(CVPixelBufferRef)src toOutput:(CVPixelBufferRef)dst {
    CVPixelBufferLockBaseAddress(src, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferLockBaseAddress(dst, 0);
    size_t h = CVPixelBufferGetHeight(src);
    size_t rS = CVPixelBufferGetBytesPerRow(src);
    size_t rD = CVPixelBufferGetBytesPerRow(dst);
    const uint8_t *s = (const uint8_t *)CVPixelBufferGetBaseAddress(src);
    uint8_t *d = (uint8_t *)CVPixelBufferGetBaseAddress(dst);
    if (s && d) {
        size_t copyRow = MIN(rS, rD);
        for (size_t y = 0; y < h; y++) {
            memcpy(d + y * rD, s + y * rS, copyRow);
        }
    }
    CVPixelBufferUnlockBaseAddress(dst, 0);
    CVPixelBufferUnlockBaseAddress(src, kCVPixelBufferLock_ReadOnly);
    return YES;
}

@end