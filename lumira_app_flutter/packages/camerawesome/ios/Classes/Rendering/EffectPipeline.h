//
//  EffectPipeline.h
//  camerawesome
//
//  iOS 取景器实时效果管线：把 Dart 传入的后期参数（色彩矩阵 + 磨皮/清晰度/
//  锐化/颗粒/暗角）在原生 video 帧阶段用 CoreImage（Metal GPU 加速）渲染，
//  使取景器与成片同源同效果（WYSIWYG）。
//

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

@interface EffectPipeline : NSObject

@property(class, readonly) EffectPipeline *shared;

/// 色彩矩阵（20 个 double，行优先，与 dart filter_recipe 的 5x4 矩阵一致）。
@property(nonatomic, copy, nullable) NSArray<NSNumber *> *colorMatrix;

/// 磨皮强度 0-100（0 = 关闭）。
@property(nonatomic, assign) int smoothStrength;
/// 清晰度 -100~100（0 = 关闭）。
@property(nonatomic, assign) double clarity;
/// 锐化强度 0-100（0 = 关闭）。
@property(nonatomic, assign) int sharpen;
/// 颗粒强度 0-100（0 = 关闭）。
@property(nonatomic, assign) int grain;
/// 暗角强度 0-100（0 = 关闭）。
@property(nonatomic, assign) int vignette;

/// 重置为中性（全程无效果）。相机切换/重建时调用，避免残留旧参数。
- (void)reset;

/// 是否存在需要 GPU 处理的效果。
- (BOOL)hasEffects;

/// 对输入 BGRA pixelBuffer 施加全部效果，输出到 outPixelBuffer（同样 BGRA）。
/// outPixelBuffer 尺寸建议与输入一致。返回 NO 表示参数无效/处理失败，
/// 调用方应直接使用原 buffer。
- (BOOL)processPixelBuffer:(CVPixelBufferRef)input
                 toOutput:(CVPixelBufferRef)output;

/// 初始化（惰性，内部确保只建一次）。失败返回 NO。
- (BOOL)ensureInitialized;

@end

NS_ASSUME_NONNULL_END