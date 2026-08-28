# 水印动画取景器帧直出 + 成片管线 设计

> 日期：2026-08-28
> 范围：Flutter 客户端（`lumira_app_flutter/`）+ iOS camerawesome 原生端
> 关联：拍摄页 `capture_page.dart`、水印动画 `watermark_animation_overlay.dart`、
>       相机服务 `camera_service.dart`/`camerawesome_camera_service.dart`、
>       iOS 原生 `CameraPreview.m`/`CameraPictureController.m`、
>       OHOS 原生 `ohos_image_processor.dart`/`CameraState.ets`。

## 背景动机

当前 iOS 拍照「成片」直接抓取取景器当前帧编码（`captureVideoFrameToJpegAtPath`，video 管线），
成片与取景器同源同色、100% 所见即所得、出片快；但**质量受限**——没有 photo 管线带来的
弱光/闪光（Smart HDR、Deep Fusion、多帧合成等）增强，弱光与闪光场景成片细节与噪点不如原生拍照。

用户目标：**照片质量与出片速度兼得**。
- **最终成片走 photo 管线**（质量优先：弱光/闪光/Deep Fusion）。
- **水印定格动画内容走「取景器帧直出」**（速度优先：出图快、与取景器内容高度一致）。
- 用户明确：**动画不要求与最终成片逐像素一致**，只要**高度一致**即可；
  iOS 现有的「取景器帧直出」所见即所得、质量虽低但足以做动画，已满足需求。

## 核心结论

| 端 | 水印动画内容源 | 最终成片来源 |
|---|---|---|
| iOS | **取景器帧直出**（video 帧，`captureVideoFrameToJpegAtPath`，快 + WYSIWYG） | **photoOutput 管线**（质量优先，含闪光/弱光增强） |
| OHOS | **原生硬解码已拍原片**（`OhosImageProcessor.decodeJpegToRgba`，绕开 dart:ui 软件解码瓶颈） | 现有管线（原生快路径 / GPU+isolate），不受影响 |

两端最终成片都走现有管线，水印动画内容源两端独立选择，互不影响。

---

## 1. iOS：成片切回 photo 管线，水印动画用取景器帧

### 现状

`CameraPreview.takePictureAtPath`（iOS）：
- 无闪光时优先 `captureVideoFrameToJpegAtPath`（取景器帧直出 → 作为成片），
  以根治「photoOutput 成片比取景器偏黄」；
- 闪光时必须走 `captureWithPhotoOutputAtPath`。

### 目标态

1. **成片一律走 photoOutput**：`takePictureAtPath` 直接调 `captureWithPhotoOutputAtPath`
   （保留现有锁白平衡 / 闪光处理），保证弱光 / 闪光 / Deep Fusion 质量。
2. **新增独立的「取景器帧抓取」能力**暴露给 Flutter，专供水印动画：
   - 复用 `captureVideoFrameToJpegAtPath` 的原子帧换出 + 后台 JPEG 编码逻辑
     （100–300ms、不阻塞取景器渲染）；
   - 通过 MethodChannel / 现有插件通道暴露，返回「动画帧 JPEG 路径」。
3. **快门瞬间双路并行**：
   - 立即抓取取景器帧 → 交给 `WatermarkAnimationOverlay` 播放动画（几乎零等待）；
   - 同时 photoOutput 出成片 → 进现有后处理管线（GPU 校色 + worker + 水印合成 + 落库）。
   - 动画淡出后跳预览页，等成片落库完成带上 `finalPath` 打开（沿用现有 `_goToPreviewWhenReady`）。

### 改动点

- `CameraPreview.m`：`takePictureAtPath` 改为始终 photoOutput；新增/复用取景器帧抓取方法并暴露。
- `camera_service.dart` / `camerawesome_camera_service.dart`：`capture()` 返回成片路径；
  新增 `captureFrameForAnimation()`（iOS）返回动画帧路径，OHOS 返回 null（走原片解码）。
- `capture_page.dart` `_onCapture`：动画 overlay 的 `photoPath` 改为取景器帧路径（iOS）/
  原片路径（OHOS）；成片处理队列逻辑不变。
- `watermark_animation_overlay.dart`：接收的 `photoPath` 语义变为「动画内容源帧」。

### 边界

- 取景器帧直出仅在无闪光时可用（video 帧捕捉不到瞬时闪光）；闪光模式下动画源回退用
  photoOutput 成片（原生解码），动画延迟在可接受范围（合成阶段耗时相同，仅首帧来源不同）。
- 相机刚启动无帧时，动画源回退 photoOutput 成片。

---

## 2. iOS 偏黄修复：内容自适应校色（photo 管线副产物）

### 背景

photoOutput 照片 ISP（Smart HDR / Deep Fusion）产出比 video 管线偏暖
（全图 R-B≈+23，暖色集中、灰区近中性）。此前 iOS 走取景器帧直出绕开了该问题，
本次切回 photo 管线后**必须重新引入校色**，否则成片再次偏黄。

### 方案：内容自适应白平衡（灰世界 + 曝光守恒）

- 从**成片自身的中性灰/浅灰像素**（低饱和度 + 亮度适中，避开过曝/暗部/强饱和色）
  统计 R/G/B 均值，构造逐通道增益，把灰区拉回等量（R=G=B）→ 只抵消相机 ISP 对
  中性区域的色偏，不动场景真实色彩。
- **曝光守恒铁律**：三通道增益几何均值归 1（中灰像素校正后灰值不变 → 全局亮度守恒）。
- 仅当通道间失衡足够大（R-B 失衡，即偏黄/偏蓝）才产生非恒等校正矩阵。
- 仅 iOS 启用（OHOS/Android 无此偏黄问题）。

> 实现可参考 `fd6391d0` 曾引入、`f7dc362a` 移除的 `_buildAdaptiveWhiteBalanceMatrixFromRgba`，
> 切回 photo 管线时在 `_applyColorMatrixOnGpu` 的 iOS 分支重新启用，并在用户色彩矩阵之前叠乘。

### 与动画的观感一致性

- 动画（video 帧）走中性色管，本就不黄；
- 成片 = photo 管线 + 自适应校色 → 灰区中性、观感追平取景器；
- 两端在「高度一致」的可接受范围内，无需逐像素对齐。

---

## 3. OHOS：水印动画内容源 = 原生硬解码已拍原片

### 背景

- OHOS 无现成「取景器帧抓取」实现；若新增相机负载得不偿失。
- flutter_ohos 引擎 dart:ui 的 JPEG 软件解码极慢（1200x1600 实测 ~6s），不能直接解码原片做动画。

### 方案

- 水印动画 overlay 用 `OhosImageProcessor.decodeJpegToRgba`（系统/硬件解码 + 降采样到
  展示目标尺寸）对**已拍原片**解码，再走现有水印合成（渲染器 + 原生编码），绕开 dart:ui 软件解码瓶颈。
- 成片走现有管线（原生快路径 `processJpeg` / GPU+isolate 回退），**不受本次改动影响**。
- 动画与成片同源（同一张原片）→ 高度一致；解码降采样目标尺寸沿用现有 `_decodeTargetDim=1200`。

### 边界

- 原片即「原生快路径产出底片」时，复用现有 `nativeFastDone` 分支的
  `decodeJpegToRgba(targetWidth/Height=0)` 逻辑，不重复解码。
- 失败回退：动画 overlay 现有 `_prepBase`/`_buildComposite` 的 catch 回退逻辑保持不变。

---

## 4. 动画与成片「高度一致」保障

1. **方向对齐一致**：动画与成片共用同一套对齐逻辑
   （`isPortrait`/`isFront` → 旋转 + 前置镜像），动画 overlay 沿用现有 `_alignOrientation`，
   与后处理管线 `_alignOrientationImg` / `_applyColorMatrixOnGpu` 方向铁律一致。
2. **色彩一致**：iOS 动画=取景器帧（中性），成片=photo 管线+自适应校色 → 观感追平；
   OHOS 动画与成片同源。
3. **宽高比**：动画按抓帧/原片全幅展示（4:3），成片按 `targetRatio` 裁切；动画仅作
   定格展示，接受比例差异（用户已确认）。

---

## 影响面

- 纯 Flutter + iOS camerawesome 原生端改动；OHOS 无新增原生能力（复用现有硬解码）。
- 涉及文件：
  - iOS 原生：`packages/camerawesome/ios/Classes/CameraPreview/CameraPreview.m`
  - Flutter：`camera_service.dart`、`camerawesome_camera_service.dart`、
    `capture_page.dart`、`watermark_animation_overlay.dart`
  - 校色：`capture_page.dart`（`_applyColorMatrixOnGpu` iOS 分支，重建自适应白平衡）
- 不涉及后端 / 后台 / uni-app。
- 本次改动**不改变最终成片的处理链路**，仅调整「成片来源（iOS 取景器帧 → photo 管线）」
  与「水印动画内容源」，成片方向对齐 / 比例裁剪 / 水印合成 / 落库流程保持不变。
