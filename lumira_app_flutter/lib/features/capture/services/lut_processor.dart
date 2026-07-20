// lib/features/capture/services/lut_processor.dart
import 'dart:ui' as ui;

/// LUT 处理器：封装 gpu_image 包的 3D LUT 支持。
///
/// **gpu_image 1.0.0 现状（已核实包源码）：**
/// - 该包仅提供基于 Platform View 的 UI 组件（`GPUImageWidget`、`GPUCameraWidget`），
///   通过原生 GPUImage 库（iOS）/ 自定义实现（Android）渲染。
/// - 暴露的滤镜为基础色彩调整（brightness/contrast/sepia/saturation/hue/...），
///   通过 `setFilter(GPUFilter)` 传递给 Platform View，无 3D LUT 文件加载能力。
/// - 无 `ui.Image → ui.Image` 的纯数据处理 API；仅在 Android/iOS 工作，不支持 HarmonyOS。
///
/// 因此 `apply3DLut` 当前抛出 `UnimplementedError`。
/// 调用方（`ImageProcessingService`）应 catch 该异常并回退到 `fromPostProcess(params)`
/// 中的 ColorMatrix 近似（`composeLutMatrix` 已实现 16 种 LUT 预设的矩阵近似）。
///
/// 未来实现方向：接入支持 3D LUT 的原生库（如 iOS GPUImage2 的 `GPUImageLookupFilter`），
/// 或通过 `image` 包逐像素应用 .cube/.3dl 文件。
class LutProcessor {
  LutProcessor._();

  /// 对 [input] 应用名为 [lutName] 的 3D LUT，返回处理后的图像。
  ///
  /// [lutName] 取值见 `filter_recipe.dart` 的 `composeLutMatrix`（如 'cinematic',
  /// 'vintage', 'bw', 'warm_film', ... 共 16 种）。
  ///
  /// 当前实现抛出 `UnimplementedError`（见类文档说明）。
  static Future<ui.Image> apply3DLut({
    required ui.Image input,
    required String lutName,
  }) async {
    throw UnimplementedError(
      'gpu_image 1.0.0 does not support 3D LUT processing. '
      'Falling back to ColorMatrix approximation via composeLutMatrix.',
    );
  }
}
