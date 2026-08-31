# 探店足迹分享海报 · 多款式重设计 Implementation Plan

> Agentic workers: use subagent-driven-development or executing-plans to implement task-by-task (checkbox syntax).

**Goal:** 把探店足迹分享海报改成 4 款可选样式（温柔手帐 f / 原版足迹 base / 金字招牌 v4 / 克制奢华 m4），支持 1 大图 + 至多 4 小图，照片 >5 张时弹选图面板。

**Architecture:** 复用 PosterKind + PosterStyleRegistry + PosterGenerator.showPosterWithStylePicker。给 PosterStyleData 增加 checkin 可选扩展字段（默认值不破坏模板/照片海报），新增 checkin_poster_styles.dart 定义 4 款样式并注册，重写 showCheckinPoster 入口：异步加载全部照片 -> 选图 -> 组装 PosterStyleData -> 样式选择器。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6, flutter_riverpod, 既有 poster 共享组件（poster_common.dart / poster_styles_shared.dart）。

## Global Constraints
- 不改 lumira-app/（废弃原型）。
- 海报用固定 PosterPalette，不随主题/UI 风格切换。
- 不得破坏既有 template/photo 海报：新字段必须可选带默认值；PosterKind 新增不破坏 switch。
- 各样式在 FittedBox 无界约束下必须正常，不得抛 infinite width（固定宽度 SizedBox(width:_kCkW)）。

### Task 1: 扩展 PosterStyleData / PosterKind
Files: poster_style_types.dart
- enum PosterKind 增加 checkin。
- PosterStyleData 增加可选字段（默认值）：String note='', place='', dateText='', double rating=0, List<Widget Function(w,h)>? thumbBuilders。复用 title/category/photoBuilder。
- 既有 const PosterStyleData 调用不受影响。

### Task 2: checkin_poster_widgets.dart
Files: lib/features/checkin/widgets/checkin_poster_widgets.dart
- checkinPhoto({url, tokens, width, height, radius}) cover 渲染，空则占位。
- PosterRatingRow / PosterMetaLine / PosterHairline / GoldNotchedFrame / PosterStamp / PosterWatermark / CheckinBrandTag。全部基于 PosterPalette。

### Task 3: checkin_poster_styles.dart（4 款）
Files: lib/features/checkin/widgets/checkin_poster_styles.dart
- checkinPosterStyles() 返回 ckF/ckBase/ckV4/ckM4，kind=checkin，ratios={ratio34}，画布 _kCkW=320。
- 大图=data.photoBuilder；小图=data.thumbBuilders（空跳过）；兜底 place/note/rating。
- f=温柔手帐、base=原版足迹、v4=金字招牌、m4=克制奢华，按设计文档与 HTML mockup 还原。

### Task 4: 注册
Files: poster_style_registry.dart
- import checkin_poster_styles.dart；_styles 追加 ...checkinPosterStyles()。

### Task 5: 选图面板 checkin_poster_photo_picker.dart
Files: lib/features/checkin/widgets/checkin_poster_photo_picker.dart
- showCheckinPhotoPicker({context, tokens, photoUrls}) -> Future<List<String>?>。网格多选最多5张，首位=大图，上移/下移调序。

### Task 6: 重写 checkin_poster_generator.dart
Files: lib/features/checkin/widgets/checkin_poster_generator.dart
- showCheckinPoster({context, tokens, item, ref})：checkinDetailProvider 取 detail->photos URL；>5 走选图；buildCheckinData(record, urls)；调 showPosterWithStylePicker(kind:checkin, ratio:ratio34)。

### Task 7: 更新入口
Files: checkin_list_page.dart
- 移除 _posterKey；_showSharePoster 改 Consumer 内传 ref。

### Task 8: 测试与验证
- 单测 buildCheckinData 兜底/顺序/截断；Widget 测 4 款无界布局；registry 测；flutter analyze + 相关测试通过。
