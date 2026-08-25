enum TodayShootTarget { scene, template }

class TodayShootItem {
  const TodayShootItem({
    required this.id,
    required this.name,
    required this.vibe,
    required this.imageAsset,
    required this.target,
    required this.targetId,
    this.categories = const [],
    this.slots = const [],
  });

  final String id;
  final String name;
  final String vibe;
  final String imageAsset;
  final TodayShootTarget target;
  final String targetId;
  final List<String> categories;
  final List<String> slots;
}

class InspirationGalleryItem {
  const InspirationGalleryItem({
    required this.assetPath,
    required this.title,
    required this.templateId,
  });

  final String assetPath;
  final String title;
  final String templateId;
}

class InspirationContent {
  InspirationContent._();

  static const List<TodayShootItem> todayShootPool = [
    TodayShootItem(
      id: 'cafe-window',
      name: '咖啡馆窗边',
      vibe: '午后斜阳，把光调成蜜糖色',
      imageAsset: 'assets/images/scenes/scene_cafe.jpg',
      target: TodayShootTarget.scene,
      targetId: 'cafe-window',
      categories: ['portrait', 'food'],
      slots: ['morning', 'noon'],
    ),
    TodayShootItem(
      id: 'home-cozy',
      name: '居家温暖',
      vibe: '窗边晨光，把日子过成一首慢歌',
      imageAsset: 'assets/images/scenes/scene_home.jpg',
      target: TodayShootTarget.scene,
      targetId: 'home-cozy',
      categories: ['portrait', 'still-life'],
      slots: ['morning'],
    ),
    TodayShootItem(
      id: 'sunset-silhouette',
      name: '黄昏剪影',
      vibe: '逆光之下，把剪影装进落日',
      imageAsset: 'assets/images/templates/sunset_silhouette.jpg',
      target: TodayShootTarget.scene,
      targetId: 'sunset-silhouette',
      categories: ['portrait', 'landscape'],
      slots: ['dusk'],
    ),
    TodayShootItem(
      id: 'night-street',
      name: '霓虹街头',
      vibe: '霓虹与夜，城市的故事',
      imageAsset: 'assets/images/scenes/scene_street.jpg',
      target: TodayShootTarget.scene,
      targetId: 'night-street',
      categories: ['street', 'night'],
      slots: ['night'],
    ),
    TodayShootItem(
      id: 'convenience-store',
      name: '便利店',
      vibe: '深夜便利店，日系生活感',
      imageAsset: 'assets/images/scenes/scene_shop.jpg',
      target: TodayShootTarget.scene,
      targetId: 'convenience-store',
      categories: ['street', 'night'],
      slots: ['night'],
    ),
    TodayShootItem(
      id: 'cafe_portrait',
      name: '咖啡馆人像',
      vibe: '窗边柔光，情绪写真',
      imageAsset: 'assets/images/templates/cafe_portrait.jpg',
      target: TodayShootTarget.template,
      targetId: 'cafe_portrait',
      categories: ['portrait'],
      slots: ['noon'],
    ),
    TodayShootItem(
      id: 'golden_landscape',
      name: '金色风光',
      vibe: '黄金时刻，风光大片',
      imageAsset: 'assets/images/templates/golden_landscape.jpg',
      target: TodayShootTarget.template,
      targetId: 'golden_landscape',
      categories: ['landscape'],
      slots: ['dusk'],
    ),
    TodayShootItem(
      id: 'night_cityscape',
      name: '城市夜景',
      vibe: '蓝调时刻，长曝出片',
      imageAsset: 'assets/images/templates/night_cityscape.jpg',
      target: TodayShootTarget.template,
      targetId: 'night_cityscape',
      categories: ['night'],
      slots: ['night'],
    ),
  ];

  static const List<InspirationGalleryItem> galleryItems = [
    InspirationGalleryItem(
      assetPath: 'assets/images/templates/cafe_portrait.jpg',
      title: '咖啡馆人像 · 窗边柔光',
      templateId: 'cafe_portrait',
    ),
    InspirationGalleryItem(
      assetPath: 'assets/images/templates/soft_portrait.jpg',
      title: '柔光人像 · 奶油质感',
      templateId: 'soft_portrait',
    ),
    InspirationGalleryItem(
      assetPath: 'assets/images/templates/golden_landscape.jpg',
      title: '金色风光 · 黄金时刻',
      templateId: 'golden_landscape',
    ),
    InspirationGalleryItem(
      assetPath: 'assets/images/templates/food_flat_lay.jpg',
      title: '美食俯拍 · 构图美学',
      templateId: 'food_flat_lay',
    ),
    InspirationGalleryItem(
      assetPath: 'assets/images/templates/night_cityscape.jpg',
      title: '城市夜景 · 蓝调时刻',
      templateId: 'night_cityscape',
    ),
    InspirationGalleryItem(
      assetPath: 'assets/images/templates/street_bw.jpg',
      title: '街头黑白 · 光影叙事',
      templateId: 'street_bw',
    ),
    InspirationGalleryItem(
      assetPath: 'assets/images/templates/macro_flower.jpg',
      title: '微距花卉 · 细节之美',
      templateId: 'macro_flower',
    ),
    InspirationGalleryItem(
      assetPath: 'assets/images/templates/indoor_still_life.jpg',
      title: '温暖静物 · 光影层次',
      templateId: 'indoor_still_life',
    ),
  ];

  /// 与 InspirationService 的时段划分保持一致：5-10 晨 / 10-14 午 / 14-18 暮 / 其余夜
  static String slotOf(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 10) return 'morning';
    if (h >= 10 && h < 14) return 'noon';
    if (h >= 14 && h < 18) return 'dusk';
    return 'night';
  }

  static List<TodayShootItem> pickTodayShoot(
    String? topCategory,
    DateTime now, {
    int count = 4,
    Map<String, double> interestByTemplateId = const {},
  }) {
    final slot = slotOf(now);
    int scoreOf(TodayShootItem item) {
      var score = 0;
      if (item.slots.contains(slot) || item.slots.contains('any')) score += 2;
      if (topCategory != null && item.categories.contains(topCategory)) {
        score += 3;
      }
      // 个人兴趣加成（仅模板目标；0..1 → 0..5，与 slot/category 分同量级）
      if (item.target == TodayShootTarget.template) {
        score += ((interestByTemplateId[item.targetId] ?? 0) * 5).round();
      }
      return score;
    }

    final items = List<TodayShootItem>.from(todayShootPool);
    items.sort((a, b) {
      final d = scoreOf(b).compareTo(scoreOf(a));
      if (d != 0) return d;
      return a.id.compareTo(b.id);
    });
    return items.take(count).toList();
  }
}
