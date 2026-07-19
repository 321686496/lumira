import 'package:flutter/material.dart';

import 'gallery_models.dart';

/// Gallery mock 数据（仅用于 diary 和 monthly-digest 页）
///
/// 相册主页和详情页已接入 GalleryDao，不再使用 mock。
/// diary 和 monthly-digest 在 uni-app 中也是硬编码 mock。
class GalleryMockData {
  GalleryMockData._();

  /// 拍摄日记时间轴（5 篇）
  static const List<DiaryEntry> diaryEntries = [
    DiaryEntry(
      weekday: '周日',
      date: '07/08',
      isToday: true,
      photos: [
        DiaryPhoto(
          img: 'https://picsum.photos/seed/414628/400/600',
          tags: [
            DiaryTag(label: '咖啡馆', color: DiaryTagColor.gold, icon: Icons.coffee_outlined),
            DiaryTag(label: '放松', color: DiaryTagColor.green, icon: Icons.sentiment_satisfied_outlined),
          ],
        ),
        DiaryPhoto(
          img: 'https://picsum.photos/seed/1239291/400/600',
          tags: [
            DiaryTag(label: '清新自然', color: DiaryTagColor.red, icon: Icons.eco_outlined),
          ],
        ),
      ],
    ),
    DiaryEntry(
      weekday: '周六',
      date: '07/07',
      photos: [
        DiaryPhoto(
          img: 'https://picsum.photos/seed/774909/400/600',
          tags: [
            DiaryTag(label: '咖啡馆', color: DiaryTagColor.gold, icon: Icons.coffee_outlined),
            DiaryTag(label: '放松', color: DiaryTagColor.green, icon: Icons.sentiment_satisfied_outlined),
          ],
        ),
        DiaryPhoto(
          img: 'https://picsum.photos/seed/2074130/400/600',
          tags: [
            DiaryTag(label: '咖啡日记', color: DiaryTagColor.red, icon: Icons.coffee_outlined),
          ],
        ),
      ],
    ),
    DiaryEntry(
      weekday: '周五',
      date: '07/06',
      photos: [
        DiaryPhoto(
          img: 'https://picsum.photos/seed/733872/400/600',
          tags: [
            DiaryTag(label: '夜晚出行', color: DiaryTagColor.gold, icon: Icons.location_city_outlined),
            DiaryTag(label: '自信', color: DiaryTagColor.green, icon: Icons.sentiment_satisfied_outlined),
          ],
        ),
        DiaryPhoto(
          img: 'https://picsum.photos/seed/774095/400/600',
          tags: [
            DiaryTag(label: '都市夜景', color: DiaryTagColor.red, icon: Icons.location_city_outlined),
          ],
        ),
      ],
    ),
    DiaryEntry(
      weekday: '周四',
      date: '07/05',
      photos: [
        DiaryPhoto(
          img: 'https://picsum.photos/seed/414628/400/600',
          tags: [
            DiaryTag(label: '运动装', color: DiaryTagColor.gold, icon: Icons.directions_run_outlined),
            DiaryTag(label: '元气', color: DiaryTagColor.green, icon: Icons.flash_on_outlined),
          ],
        ),
        DiaryPhoto(
          img: 'https://picsum.photos/seed/1926773/400/600',
          tags: [
            DiaryTag(label: '公园随拍', color: DiaryTagColor.red, icon: Icons.park_outlined),
          ],
        ),
      ],
    ),
    DiaryEntry(
      weekday: '周三',
      date: '07/04',
      photos: [
        DiaryPhoto(
          img: 'https://picsum.photos/seed/1926769/400/600',
          tags: [
            DiaryTag(label: '午后', color: DiaryTagColor.gold, icon: Icons.wb_sunny_outlined),
          ],
        ),
        DiaryPhoto(
          img: 'https://picsum.photos/seed/1038002/400/600',
          tags: [
            DiaryTag(label: '静物', color: DiaryTagColor.red, icon: Icons.brush_outlined),
          ],
        ),
      ],
    ),
  ];

  /// 月度手帐封面统计
  static const List<CoverStat> coverStats = [
    CoverStat(num: '32', label: '张照片'),
    CoverStat(num: '8', label: '个模板'),
    CoverStat(num: '4', label: '个场景'),
  ];

  /// 月度手帐照片墙（杂志式混合比例）
  static const List<DigestGalleryPhoto> digestGalleryPhotos = [
    DigestGalleryPhoto(img: 'https://picsum.photos/seed/733872/400/400', ratio: DigestPhotoRatio.ratio34),
    DigestGalleryPhoto(img: 'https://picsum.photos/seed/774095/400/400', ratio: DigestPhotoRatio.ratio11),
    DigestGalleryPhoto(img: 'https://picsum.photos/seed/1038002/400/400', ratio: DigestPhotoRatio.ratio45),
    DigestGalleryPhoto(img: 'https://picsum.photos/seed/312415/400/400', ratio: DigestPhotoRatio.ratio11),
    DigestGalleryPhoto(img: 'https://picsum.photos/seed/457882/400/400', ratio: DigestPhotoRatio.ratio11),
    DigestGalleryPhoto(img: 'https://picsum.photos/seed/312415/400/400', ratio: DigestPhotoRatio.ratio34),
    DigestGalleryPhoto(img: 'https://picsum.photos/seed/1038002/400/400', ratio: DigestPhotoRatio.ratio11),
    DigestGalleryPhoto(img: 'https://picsum.photos/seed/733872/400/400', ratio: DigestPhotoRatio.ratio34),
  ];

  /// 月度手帐本月精选
  static const List<DigestSelectedPhoto> digestSelectedPhotos = [
    DigestSelectedPhoto(img: 'https://picsum.photos/seed/733872/400/400', title: '河畔金色的午后', date: '7月12日', tag: '日系胶片'),
    DigestSelectedPhoto(img: 'https://picsum.photos/seed/774095/400/400', title: '城市夜雨', date: '7月18日', tag: '黑金电影'),
    DigestSelectedPhoto(img: 'https://picsum.photos/seed/1239291/400/400', title: '山间晨雾', date: '7月25日', tag: '日系清新'),
  ];

  /// 月度手帐总结统计
  static const List<SummaryStat> summaryStats = [
    SummaryStat(num: '12', label: '天有拍摄'),
    SummaryStat(num: '5', label: '个地点'),
    SummaryStat(num: '日系', label: '最常用风格'),
    SummaryStat(num: '傍晚', label: '最佳时段'),
  ];

  /// 月度手帐月度语录
  static const String monthQuote = '这个月你记录了 32 个美好瞬间，\n偏爱日系胶片风，最常在傍晚按下快门。';

  /// 月度手帐场景足迹 pills
  static const List<DigestSceneTag> sceneTags = [
    DigestSceneTag(icon: Icons.location_city_outlined, label: '城市', count: 14),
    DigestSceneTag(icon: Icons.local_florist_outlined, label: '自然', count: 8),
    DigestSceneTag(icon: Icons.home_outlined, label: '室内', count: 6),
    DigestSceneTag(icon: Icons.restaurant_outlined, label: '美食', count: 4),
  ];

  /// 详情页工具 pills（调色 / LUT / 裁剪 / 磨皮 / 锐化）
  static const List<String> detailTools = ['调色', 'LUT', '裁剪', '磨皮', '锐化'];

  /// 详情页调色滑块初始值
  static const List<SliderMock> detailSliders = [
    SliderMock(label: '亮度', value: 62, display: '+12'),
    SliderMock(label: '对比度', value: 44, display: '-4'),
    SliderMock(label: '饱和度', value: 50, display: '0'),
    SliderMock(label: '色温', value: 58, display: '+8'),
  ];

  /// 详情页 LUT 缩略图（仅前 2 个有名字）
  static const List<LutMock> detailLuts = [
    LutMock(img: 'https://picsum.photos/seed/733872/400/400', name: '暖调'),
    LutMock(img: 'https://picsum.photos/seed/1239291/400/400', name: '冷调'),
    LutMock(img: 'https://picsum.photos/seed/1926769/400/400', name: ''),
    LutMock(img: 'https://picsum.photos/seed/774909/400/400', name: ''),
    LutMock(img: 'https://picsum.photos/seed/1038002/400/400', name: ''),
    LutMock(img: 'https://picsum.photos/seed/51383/400/400', name: ''),
  ];
}

/// 详情页调色滑块 mock
class SliderMock {
  const SliderMock({required this.label, required this.value, required this.display});
  final String label;
  final int value;
  final String display;
}

/// 详情页 LUT mock
class LutMock {
  const LutMock({required this.img, required this.name});
  final String img;
  final String name;
}
