# EXIF 海报品牌化重设计(纸感卡)

> 日期:2026-09-16
> 范围:Flutter 客户端(`lumira_app_flutter/`)
> 关联:`features/capture/services/exif_card_generator.dart`(删除)、`features/capture/services/exif_info.dart`(新增)、
>       `features/capture/widgets/exif_poster_card.dart`(新增)、`features/capture/services/photo_exif_reader.dart`、
>       `features/capture/pages/capture_preview_page.dart`
> 复用:`shared/widgets/poster/poster_common.dart`(品牌色板/字体/组件)、`shared/services/poster_generator.dart`(预览与导出/分享管线)

## 背景动机

拍摄预览页「生成 EXIF 海报」出图样式差:10 个字段两列铺开像设置页、无视觉层级;
照片区 contain 留大面积黑边 + 描边显得廉价;深色金字与 App 分享海报已统一的
「暖白纸感 + 金色细线 + 衬线标题」品牌体系脱节;实现上为全项目唯一仍在用
dart:ui 手绘 canvas 出图的海报,字体排版能力受限,且需先落盘临时 PNG 再预览。

同时明确产品语义:**EXIF 海报是「社交分享衍生品」**,不是保存照片的替代品——
保存到系统相册的照片把参数藏在文件元数据里(分享到社交平台通常被剥离),
海报则把参数排版成可见文字。另注:App 内拍摄管线重编码后不含相机 EXIF,
仅导入照片有完整焦距/光圈/快门/ISO,海报必须「有啥显示啥」优雅降级。

## 核心结论

| 维度 | 决策 |
|---|---|
| 设计方向 | 品牌纸感卡(暖白 `#FDFBF7` + 金线 + 衬线),与相册/模板/探店海报同一品牌体系(用户已确认) |
| 实现路线 | 废弃 canvas 手绘,改为 Widget 海报,复用 `PosterGenerator.showPoster` 预览与导出/分享管线(内容级 RepaintBoundary 捕获,鸿蒙降级逻辑照旧) |
| 画布宽度 | 300 逻辑宽(与 fragment 等普通海报一致;导出 pixelRatio≈3.6 → 1080px) |
| 照片区 | 按原图真实宽高比全宽铺排(消除黑边);高度钳制在 0.5~2.0 倍画布宽,越界居中裁切(仅极端全景图) |
| 参数分层 | 曝光四要素一行衬线大字 → 相机型号 → 时间/位置 + 分辨率/大小小字 → 场景/模板金色 kicker;缺项自动跳过 |
| 宽高比探测 | `instantiateImageCodec(targetHeight: 120)` 快速解码取宽高比,失败回退 3:4 |
| 显示名 | 场景名 `ScenePresetsData.getScenePreset(id)?.name`、模板名 `CaptureState.originalTemplateProvider?.meta.name`,取不到回退原 ID |
| 旧代码 | 删除 `exif_card_generator.dart` 及两个旧测试,新增 Widget 测试 |

## 版式(设计宽 300)

```
┌────────────────────────────────┐ ← PosterCanvas:纸感底 + 金色发丝边 + 圆角 20
│ ◇ LUMIRA 如画            EXIF  │ ← 品牌行(复用 PosterBrandRow)+ 金色衬线 EXIF
│ ────────────────────────────── │ ← PosterDivider 发丝线
│                                │
│      照片(按原比例全宽铺排)      │ ← Image.file cover;高度=宽/宽高比,钳 150~600
│                                │
│ ────────────────────────────── │ ← PosterDivider
│  35mm · f/1.8 · 1/250s · ISO200│ ← 曝光四要素,衬线 16,金色分隔点;无参数时回退「W × H」
│  HUAWEI Pura 70                │ ← 相机型号,Georgia 10.5(缺省跳过)
│  2026.09.16 14:32 · 30.25° N   │ ← 时间 · 位置,plain 10
│  4096 × 3072 · 8.2 MB          │ ← 分辨率 · 大小,plain 10(四要素齐全时才展示)
│  场景「咖啡馆」 · 模板「胶片人像」 │ ← 创作信息 kicker,金 Deep(缺省跳过)
│  ◇ LUMIRA · 如画   如你所见,皆成画卷 │ ← PosterBrandFoot
└────────────────────────────────┘
```

## 数据流

1. `_onExifPoster`:守卫本地文件 → `PhotoExifReader.read` 读元数据(场景/模板传**显示名**)→
   `probePhotoAspect` 取宽高比 → `PosterGenerator.showPoster(content: ExifPosterCard(...))`。
2. 预览/导出/分享完全复用现有 `_PosterSheet` 管线,不再生成临时 PNG 文件。

## 测试

- `test/features/capture/exif_poster_card_test.dart`:
  1. 参数齐全 → 渲染 EXIF kicker、四要素、相机、创作信息、品牌落款;
  2. 仅分辨率 → 四要素行回退「W × H」;参数全空 → 不抛异常、仅照片+品牌脚。
- 删除 `test/exif_card_generator_test.dart`、`test/features/capture/exif_card_generator_test.dart`。
