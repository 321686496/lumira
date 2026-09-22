# 全平台自建增强实况图插件 · 设计文档

日期：2026-09-22
状态：已确认（用户逐节审阅通过）

## 1. 背景与目标

在现有 Flutter 拍摄页（`lumira_app_flutter`，锁定 Flutter 3.7.12 / Dart 2.19.6，OHOS 兼容优先）上，实现"实况图"能力：按下快门得到一张成片的同时，附带约 2 秒可长按播放的带效果动态片段。

关键约束与决策（用户已确认）：
- **必须带效果**：动态片段需与成片视觉一致（美颜/滤镜等），不能是原始无效果片段。
- **全平台自建增强实况**：由自建播放器渲染/播放，不做 iOS 系统级 PHLivePhoto（系统相册长按播放不了带 App 效果的动态）。
- **插件重逻辑 100% 原生层**：Dart 仅留薄桥（MethodChannel/EventChannel）。
- **交付节奏**：OHOS + iOS 先行，Android 后续。
- **零依赖冲突**：不得引入 pub 新依赖，绕开 Dart 3.7.12 的依赖限制。

## 2. 总体架构

### 2.1 插件包形态

`packages/live_photo_bridge`（path 依赖，仿 `camerawesome_ohos` 挂法）
- `pubspec.yaml`：Dart ≥2.19.6，声明 `ios:` / `ohos:` 平台插件，零重依赖。
- Dart 薄桥 `LivePhotoBridge`：仅 `MethodChannel` / `EventChannel` 转发，不含图像处理逻辑。

### 2.2 实况数据单元 LivePackage（自建格式，三端一致）

```jsonc
{
  "still":    "<成片 JPEG 相对路径>",        // 走现有管线产出，保持不动
  "rawClip":  "<原始 H.264 ~2s 视频相对路径>", // 原生环形缓冲编码
  "recipe":   "<效果配方 JSON>",            // 色彩矩阵+锐化/磨皮/暗角/水印参数
  "meta":     { "durationMs", "fps", "rotation", "isFrontCamera" }
}
```

### 2.3 快门瞬间数据流

```
实况模式开启 → 原生层维护 ~2s 环形视频缓冲
用户按快门 →
  ① 原生：冻结当前帧作仍 (交给现有 Dart 管线) + 固化 rawClip
  ② Dart：仍走现有 pipeline，产出成片 + recipe
  ③ 组装 LivePackage → 存盘（沿用现有 gallery 存储抽象）
  ④ 详情页播放：自建播放器拉 rawClip + recipe → GPU 实时套效果
```

## 3. 播放器与 GPU 效果引擎

### 3.1 自建播放器（原生层）

```
rawClip(H.264) → 原生硬解（iOS VideoToolbox / OHOS VideoDecoder）
              → 每帧喂 GPU 效果 Pass（Metal Shader / OpenGL ES 2.0）
              → 渲染进 Flutter Texture 纹理
              → 拍摄页/详情页用 Texture widget 实时显示（长按播放徽标）
```
- 解码渲染都在原生，Dart 只持有 Texture 句柄，不逐帧回读像素。

### 3.2 GPU 效果着色器移植（CPU 效果 → shader）

| 现有效果 | Shader 难度 | 一致性 |
|---|---|---|
| 色彩矩阵 `composePostProcessMatrix` | 极低（矩阵乘） | **像素级精确**可达 |
| 锐化/清晰度/颗粒/暗角 | 低–中（卷积/混合） | 视觉一致 |
| 磨皮 `applySmoothSkinImg` | 中（降噪/模糊核） | 视觉一致 |
| 水印（Watermark） | 低（纹理叠加层） | 一致 |
| **拉腿 `legStretchRgba`** | 高（逐帧几何形变） | **首版不做** |

### 3.3 三条已确认取舍

1. **拉腿只在成片**，motion 片段不做拉腿形变（首版最硬取舍）。
2. **GPU 效果"视觉一致"非逐像素等同**（动态画面难以察觉差异）。
3. **rawClip 预算**：封顶 720p / 15–24fps / ~2s（前 1.5s + 后 0.5s）。

## 4. 原生采集细节与各端要点

### 4.1 拍摄页语义
- 「实况」开关：ON 原生启动环形缓冲，OFF 恢复纯拍照；开关态来自现有 capture_state / 参数面板，不改成片管线。
- 快门与仍管线串行：`shutterNow()` 冻结帧 + 固化 rawClip，Dart 仍走现有 worker 后处理，不抢锁。

### 4.2 rawClip 环形缓冲

| 项 | 取值 |
|---|---|
| 缓冲时长 | 前 1.5s + 后 0.5s（可配） |
| 编码 | H.264 硬编（VideoToolbox / OHOS Encoder） |
| 清晰度 | 封顶 720p @15–24fps |
| 载体 | 内存帧队列 + 落盘环形文件 |

### 4.3 平台要点
- iOS：`AVCaptureMovieFileOutput` 前后段录制 + `AVCaptureVideoDataOutput` 同步取景。
- OHOS：`CameraManager.createVideoOutput` + VideoDecoder/Encoder；复用现有 native C++ 快速路径做 shader 素材。

### 4.4 错误兜底（三端通用）
- 实况采集失败 → 自动回退纯拍照（仍照常出片，丢弃 rawClip/recipe）。
- 播放器解码失败 → 显示成片仍兜底，不白屏。
- 无实时况能力设备 → 开关置灰。

## 5. 存储 / 详情页 / 数据模型

### 5.1 存储
- 沿用现有 gallery 存储抽象，不新起一套。
- 新增关联资产三件 `rawClip.mp4` / `recipe.json` / `meta.json`，与成片同目录、约定后缀 `<stillBasename>_live.*`。
- 导出维持"导出成片 JPEG"行为；实况资产标注"仅 App 内可播放"，不混入通用导出。

### 5.2 详情页/相册回放
- 成片默认看静止帧；长按触发实况播放（自定义播放器纹理）。
- 相册列表实况图加 "LIVE" 徽标。

### 5.3 数据模型（薄桥 Dart API）

```dart
class LivePhotoBridge {
  Future<void> startLive({int preSecs=1.5, int postSecs=0.5, int fps=24});
  Future<void> stopLive();
  Future<LiveCapture> shutterNow();
  Future<int> openPlayer(LiveCapture lc);   // 返回纹理 id
  Future<void> closePlayer(int id);
}
```
- `LiveCapture` / `LivePackage` 为轻量模型（路径+配方+meta），无重反序列化逻辑。

## 6. 测试与验收

- 实况开启按快门 → 成片与以往完全一致（回归既仍未，无性能回退）。
- 长按播放流畅、GPU 效果与成片视觉一致（首帧截图对比）。
- 采集失败自动回退纯拍照；无能力设备开关置灰。
- OHOS + iOS 真机验收；CI 仅 Dart 分析/单测（原生层靠设备验收）。
- 拉腿只在成片、motion 无拉腿观感回归确认为可接受。

## 7. 范围外（明确不做）

- iOS 系统级 PHLivePhoto（系统相册长按播放带效果动态）——与"带效果"矛盾。
- 三端同时交付——OHOS+iOS 先行，Android 后续。
- 逐帧 CPU 级烘焙效果（方案 A）。
- 拉腿在 motion 片段上的逐帧形变（首版）。