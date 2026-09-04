//
//  PreviewEffectProcessor.h
//  camerawesome
//
//  iOS 取景器逐帧效果处理器（Metal 后端 Core Image）。
//
//  背景：取景器当前以 FlutterTexture 显示的 BGRA 原始帧，由 Dart 的 ColorFiltered
//  统一色矩阵上色。但「锐化 / 磨皮 / 暗角 / 颗粒」是像素级空间核，Flutter 合成层
//  （Transform+ClipRect，即拉腿那种）做不了，必须真正改像素——这正是本类承担的职责：
//  在原生 GPU 上，把完整后期色彩矩阵（含白平衡温度，全屏均匀）+ 暗角 + 磨皮 + 锐化 +
//  颗粒逐帧渲染，成片复用同一参数 → 所见即所得（WYSIWYG），且全片处理发生在独立的
//  串行 GPU 队列，不阻塞 Flutter 光栅线程，取景器不降帧率。
//
//  线程模型：
//  - [render:] 在调用方投递到内部串行 `_gpuQueue` 执行（CoreImage + Metal）。
//  - 输出写入 3 槽回环缓冲池，渲染完成原子发布到 `copyDisplayBuffer` 供光栅线程读取。
//  - 全部参数默认值即「无效果」时走直通快路径（返回原始输入），不产生任何 GPU 开销。
//
//  性能：约 8MP 预览分辨率下约 5~10 CIFilter/帧、GPU 执行 ~8~15ms，当代 iPhone 满足
//  30fps。当前帧渲染未完成（忙碌）时丢弃新帧，保持队列不满、帧率平滑。
//

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#import <stdatomic.h>

NS_ASSUME_NONNULL_BEGIN

/// 一次性传给处理器的完整取景器效果参数（源自 Dart effectivePost + 白平衡折叠）。
typedef struct {
  /// Flutter ColorFilter.matrix 的 20 个元素（4x5 行主序：R/G/B/A 行 + offset 列）。
  BOOL hasMatrix;
  double matrix[20];
  /// 暗角强度 0..100（0 = 关闭）。
  BOOL hasVignette;
  double vignette;
  /// 磨皮强度 0..100（0 = 关闭）。
  BOOL hasSmooth;
  double smooth;
  /// 锐化强度 0..100（0 = 关闭）。
  BOOL hasSharpen;
  double sharpen;
  /// 颗粒强度 0..100（0 = 关闭）。
  BOOL hasGrain;
  double grain;
} PreviewEffectsParams;

@interface PreviewEffectProcessor : NSObject

/// 是否处于「有任一效果生效」的状态（无效果时为 NO，走直通快路径）。
@property(nonatomic, readonly) BOOL active;

/// 将最新参数写入处理器（线程安全，任意线程可调）。随后渲染会自动选择直通/处理。
- (void)updateEffects:(PreviewEffectsParams)params;

/// 对输入 BGRA 缓冲做整条效果链渲染；无效果或渲染失败时返回 NULL。
/// 调用方持有输入在渲染完成前必须保持存活（内部会在串行队列内安全引用）。
/// 该调用会投递到内部队列，返回后【尚未】完成；用 [copyDisplayBuffer] 取最新成帧。
- (void)render:(CVPixelBufferRef _Nonnull)input;

/// 取出最新已渲染的显示缓冲（原子 swap-out，调用方负责 CFRelease）。
/// 无已渲染帧/未激活时返回 NULL。与 PhotoPost 的 copyPixelBuffer 语义一致，
/// 供 FlutterTexture 光栅线程每帧读取。
- (CVPixelBufferRef _Nullable)copyDisplayBuffer;

- (void)flush;
- (void)dispose;

@end

NS_ASSUME_NONNULL_END