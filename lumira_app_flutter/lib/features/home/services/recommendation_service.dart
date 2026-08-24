import '../../../core/db/dao/composition_kits_dao.dart';
import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/dao/growth_dao.dart';
import '../../../core/db/dao/scenes_dao.dart';
import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/dao/usage_dao.dart';
import '../../../features/profile/data/composition_kit_models.dart';
import '../../onboarding/data/questionnaire_dao.dart';
import '../data/home_mock_data.dart';

/// Banner 推荐源类型
enum BannerSource {
  /// 基于最近拍摄分类
  recentCategory,

  /// 基于收藏场景/常用套件
  favoriteScene,

  /// 系统推荐模板
  systemPick,

  /// 新用户引导（totalPhotos < 3）
  newUserGuide,

  /// 探索新鲜感（用户少拍的类型）
  exploration,
}

/// 分类标签映射（参考 templates_browse_mock_data.dart 的 _categoryLabelMap）
const Map<String, String> _categoryLabelMap = {
  'portrait': '人像',
  'landscape': '风光',
  'food': '美食',
  'street': '街拍',
  'night': '夜景',
  'macro': '微距',
  'still-life': '静物',
};

/// 7 个内置分类的固定顺序（用于"未在槽位 2 出现的第一个"等 fallback）
const List<String> _kAllCategories = [
  'portrait',
  'landscape',
  'food',
  'street',
  'night',
  'macro',
  'still-life',
];

/// 新用户阈值：累计拍摄数 < [_kNewUserThreshold] 视为新用户
const int _kNewUserThreshold = 3;

/// 首页 Banner 推荐服务
///
/// 5 个固定槽位：
/// 1. 新老用户分层（新用户引导 / 老用户由槽位 5 补位）
/// 2. 基于最近拍摄分类的模板
/// 3. 基于收藏场景/常用套件
/// 4. 系统推荐模板
/// 5. 探索新鲜感（用户少拍的类型）
class RecommendationService {
  RecommendationService({
    required GalleryDao galleryDao,
    required ScenesDao scenesDao,
    required TemplatesDao templatesDao,
    required CompositionKitsDao kitsDao,
    required GrowthDao growthDao,
    required QuestionnaireDao questionnaireDao,
    UsageDao? usageDao,
  })  : _galleryDao = galleryDao,
        _scenesDao = scenesDao,
        _templatesDao = templatesDao,
        _kitsDao = kitsDao,
        _growthDao = growthDao,
        _questionnaireDao = questionnaireDao,
        _usageDao = usageDao;

  final GalleryDao _galleryDao;
  final ScenesDao _scenesDao;
  final TemplatesDao _templatesDao;
  final CompositionKitsDao _kitsDao;
  final GrowthDao _growthDao;
  final QuestionnaireDao _questionnaireDao;
  final UsageDao? _usageDao;

  /// 构建 5 条首页 Banner
  Future<List<HomeBannerItem>> buildBanners() async {
    // 并行启动所有数据源查询（Future 创建即开始执行，await 顺序不影响并行性）
    final categoryCountsFuture = _galleryDao.countByCategory();
    final favoriteScenesFuture = _scenesDao.getFavorites();
    final totalPhotosFuture = _growthDao.getTotalPhotos();
    final allKitsFuture = _kitsDao.getAll();
    final systemPicksFuture = _templatesDao.getBuiltin(isRecommended: true);
    final popularityFuture = _loadTemplatePopularity();

    final categoryCounts = await categoryCountsFuture;
    final favoriteScenes = await favoriteScenesFuture;
    final totalPhotos = await totalPhotosFuture;
    final allKits = await allKitsFuture;
    final systemPicks = await systemPicksFuture;
    final popularity = await popularityFuture;

    // 客户端按 usage_count DESC 排序（DAO 未提供 orderByUsage 参数）
    final kitsByUsage = [...allKits]..sort((a, b) => b.usageCount.compareTo(a.usageCount));

    final isNewUser = totalPhotos < _kNewUserThreshold;

    final List<HomeBannerItem> banners = [];
    final Set<String> usedTemplateIds = {};
    final Set<String> usedSceneIds = {};
    final Set<String> usedCategories = {}; // 用于 slot 5 去重

    // === 槽位 1：新老用户分层 ===
    if (isNewUser) {
      // 优先读问卷偏好，推用户首选分类的推荐模板
      final questionnaire = await _questionnaireDao.getAnswers();
      final favCats = questionnaire?.favoriteCategories ?? [];
      HomeBannerItem? questionnaireBanner;
      if (favCats.isNotEmpty) {
        final topCat = favCats.first;
        final tpls = await _templatesDao.getBuiltin(
          category: topCat,
          isRecommended: true,
        );
        if (tpls.isNotEmpty) {
          final tpl = tpls.first;
          usedTemplateIds.add(tpl.id);
          usedCategories.add(topCat);
          final label = _categoryLabelMap[topCat] ?? '推荐';
          questionnaireBanner = HomeBannerItem(
            id: 'banner_questionnaire_pick',
            title: '从$label开始',
            subtitle: tpl.description.isNotEmpty
                ? _truncate(tpl.description, 30)
                : '根据你的偏好推荐',
            imageSeed: 'banner-questionnaire-$topCat',
            tag: '为你推荐',
            route: '/templates/detail?templateId=${tpl.id}',
            cover: tpl.cover.isNotEmpty ? tpl.cover : null,
            coverData: tpl.coverData,
          );
        }
      }
      banners.add(questionnaireBanner ??
          const HomeBannerItem(
            id: 'banner_new_user_guide',
            title: '新手友好场景',
            subtitle: '从咖啡馆开始你的拍摄之旅',
            imageSeed: 'banner-new-user-cafe',
            tag: '新手友好',
            route: '/capture/scene-detail?sceneId=preset_cafe',
          ));
      if (questionnaireBanner == null) {
        usedSceneIds.add('preset_cafe');
      }
    }
    // 老用户跳过槽位 1，由末尾的槽位 5 补位（多一条探索新鲜感）

    // === 槽位 2：基于最近拍摄分类 ===
    final topCategory = _pickTopCategory(categoryCounts);
    TemplateRecord? slot2Tpl;
    var slot2Tag = '编辑精选'; // 冷启动 fallback 标签
    if (topCategory != null) {
      final tpls = await _templatesDao.getBuiltin(
        category: topCategory,
        isRecommended: true,
      );
      if (tpls.isNotEmpty) {
        slot2Tpl = tpls.first;
        slot2Tag = '常拍分类';
        usedCategories.add(topCategory);
      }
    }
    slot2Tpl ??= _pickUnusedSystemPick(systemPicks, usedTemplateIds, popularity);
    if (slot2Tpl != null) {
      usedTemplateIds.add(slot2Tpl.id);
      final label = _categoryLabelMap[topCategory] ?? '推荐';
      final subtitle = topCategory != null
          ? '你最近常拍$label，试试这套模板'
          : '编辑精选，${_truncate(slot2Tpl.description, 30)}';
      banners.add(HomeBannerItem(
        id: 'banner_recent_category',
        title: topCategory != null ? '继续拍$label' : slot2Tpl.name,
        subtitle: subtitle,
        imageSeed: 'banner-recent-${topCategory ?? slot2Tpl.id}',
        tag: slot2Tag,
        route: '/templates/detail?templateId=${slot2Tpl.id}',
        cover: slot2Tpl.cover.isNotEmpty ? slot2Tpl.cover : null,
        coverData: slot2Tpl.coverData,
      ));
    }

    // === 槽位 3：基于收藏场景/常用套件 ===
    final favScene = favoriteScenes.isNotEmpty ? favoriteScenes.first : null;
    // 内置场景的收藏行 name 可能为空（仅标记位），需 fallback
    final hasValidFav = favScene != null && favScene.name.isNotEmpty;
    CompositionKit? fallbackKit;
    if (!hasValidFav && kitsByUsage.isNotEmpty) {
      fallbackKit = kitsByUsage.first;
    }
    if (hasValidFav) {
      final fav = favScene;
      final sceneId = fav.id;
      usedSceneIds.add(sceneId);
      banners.add(HomeBannerItem(
        id: 'banner_favorite_scene',
        title: '${fav.name}灵感',
        subtitle: '你收藏的场景，新的拍摄灵感',
        imageSeed: 'banner-fav-$sceneId',
        tag: '收藏场景',
        route: '/capture/scene-detail?sceneId=$sceneId',
      ));
    } else if (fallbackKit != null &&
        !usedSceneIds.contains(fallbackKit.sceneId)) {
      final sceneId = fallbackKit.sceneId;
      usedSceneIds.add(sceneId);
      banners.add(HomeBannerItem(
        id: 'banner_kit_scene',
        title: '${fallbackKit.name}灵感',
        subtitle: '你常用的套件，新的拍摄灵感',
        imageSeed: 'banner-kit-${fallbackKit.id}',
        tag: '收藏场景',
        route: '/capture/scene-detail?sceneId=$sceneId',
      ));
    } else {
      // 全空 fallback：系统推荐模板
      final tpl = _pickUnusedSystemPick(systemPicks, usedTemplateIds, popularity);
      if (tpl != null) {
        usedTemplateIds.add(tpl.id);
        banners.add(HomeBannerItem(
          id: 'banner_favorite_scene_fallback',
          title: tpl.name,
          subtitle: '编辑精选，${_truncate(tpl.description, 30)}',
          imageSeed: 'banner-pick-${tpl.id}',
          tag: '编辑精选',
          route: '/templates/detail?templateId=${tpl.id}',
          cover: tpl.cover.isNotEmpty ? tpl.cover : null,
          coverData: tpl.coverData,
        ));
      }
    }

    // === 槽位 4：系统推荐模板 ===
    final slot4Tpl = _pickUnusedSystemPick(systemPicks, usedTemplateIds, popularity);
    if (slot4Tpl != null) {
      usedTemplateIds.add(slot4Tpl.id);
      banners.add(HomeBannerItem(
        id: 'banner_system_pick',
        title: slot4Tpl.name,
        subtitle: '编辑精选，${_truncate(slot4Tpl.description, 30)}',
        imageSeed: 'banner-pick-${slot4Tpl.id}',
        tag: '编辑精选',
        route: '/templates/detail?templateId=${slot4Tpl.id}',
        cover: slot4Tpl.cover.isNotEmpty ? slot4Tpl.cover : null,
        coverData: slot4Tpl.coverData,
      ));
    }

    // === 槽位 5：探索新鲜感（用户少拍的类型） ===
    await _buildExplorationBanner(
      banners: banners,
      categoryCounts: categoryCounts,
      usedCategories: usedCategories,
      usedTemplateIds: usedTemplateIds,
      systemPicks: systemPicks,
      idSuffix: '',
      popularity: popularity,
    );

    // === 老用户补位：再来一条探索 ===
    if (!isNewUser) {
      await _buildExplorationBanner(
        banners: banners,
        categoryCounts: categoryCounts,
        usedCategories: usedCategories,
        usedTemplateIds: usedTemplateIds,
        systemPicks: systemPicks,
        idSuffix: '_extra',
        popularity: popularity,
      );
    }

    // 防御性截断：固定 5 条
    return banners.take(5).toList();
  }

  /// 构建单条探索新鲜感 banner（槽位 5 复用）
  Future<void> _buildExplorationBanner({
    required List<HomeBannerItem> banners,
    required Map<String, int> categoryCounts,
    required Set<String> usedCategories,
    required Set<String> usedTemplateIds,
    required List<TemplateRecord> systemPicks,
    required String idSuffix,
    required Map<String, int> popularity,
  }) async {
    final explorationCat =
        _pickExplorationCategory(categoryCounts, usedCategories);
    if (explorationCat != null) {
      usedCategories.add(explorationCat);
      final tpls = await _templatesDao.getBuiltin(category: explorationCat);
      // 去重：过滤掉已被前面槽位用过的 templateId
      final unused =
          tpls.where((t) => !usedTemplateIds.contains(t.id)).toList();
      final tpl = unused.isNotEmpty
          ? unused.first
          : _pickUnusedSystemPick(systemPicks, usedTemplateIds, popularity);
      if (tpl != null) {
        usedTemplateIds.add(tpl.id);
        final label = _categoryLabelMap[explorationCat] ?? explorationCat;
        banners.add(HomeBannerItem(
          id: 'banner_exploration$idSuffix',
          title: '试试$label',
          subtitle: tpl.description.isNotEmpty
              ? _truncate(tpl.description, 30)
              : '换个风格，发现新视角',
          imageSeed: 'banner-explore-$explorationCat$idSuffix',
          tag: '探索新鲜',
          route: '/templates/detail?templateId=${tpl.id}',
          cover: tpl.cover.isNotEmpty ? tpl.cover : null,
          coverData: tpl.coverData,
        ));
      }
    } else {
      // 无可用分类时，fallback 到系统推荐
      final tpl = _pickUnusedSystemPick(systemPicks, usedTemplateIds, popularity);
      if (tpl != null) {
        usedTemplateIds.add(tpl.id);
        banners.add(HomeBannerItem(
          id: 'banner_exploration$idSuffix',
          title: tpl.name,
          subtitle: '编辑精选，${_truncate(tpl.description, 30)}',
          imageSeed: 'banner-pick-${tpl.id}$idSuffix',
          tag: '编辑精选',
          route: '/templates/detail?templateId=${tpl.id}',
          cover: tpl.cover.isNotEmpty ? tpl.cover : null,
          coverData: tpl.coverData,
        ));
      }
    }
  }

  /// 取计数最多的非零分类
  String? _pickTopCategory(Map<String, int> counts) {
    if (counts.isEmpty) return null;
    final entries = counts.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) return null;
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  /// 取计数最少的非零且未在 [usedCategories] 中出现的分类；
  /// 若全零则取 7 分类中第一个未在 [usedCategories] 出现的
  String? _pickExplorationCategory(
    Map<String, int> counts,
    Set<String> usedCategories,
  ) {
    final nonZero = counts.entries.where((e) => e.value > 0).toList();
    if (nonZero.isNotEmpty) {
      nonZero.sort((a, b) => a.value.compareTo(b.value));
      for (final e in nonZero) {
        if (!usedCategories.contains(e.key)) return e.key;
      }
    }
    // 全零 fallback：取 7 分类中第一个未在 used 出现的
    for (final c in _kAllCategories) {
      if (!usedCategories.contains(c)) return c;
    }
    return null;
  }

  /// 从系统推荐列表中取第一个未使用、且全站流行度最大的模板；
  /// 流行度全为 0/空时退回第一个未使用模板（保持原行为）。
  TemplateRecord? _pickUnusedSystemPick(
    List<TemplateRecord> systemPicks,
    Set<String> usedTemplateIds,
    Map<String, int> popularity,
  ) {
    final unused =
        systemPicks.where((t) => !usedTemplateIds.contains(t.id)).toList();
    if (unused.isEmpty) return null;
    var best = unused.first;
    var bestPop = popularity[best.id] ?? 0;
    for (final t in unused.skip(1)) {
      final p = popularity[t.id] ?? 0;
      if (p > bestPop) {
        bestPop = p;
        best = t;
      }
    }
    return best;
  }

  /// 并行读取系统推荐模板的全站流行度（templateId -> use_shoot*2 + open_detail）。
  /// 未注入 usageDao 时返回空 map。
  Future<Map<String, int>> _loadTemplatePopularity() async {
    final dao = _usageDao;
    if (dao == null) return const {};
    final picks = await _templatesDao.getBuiltin(isRecommended: true);
    final result = <String, int>{};
    final counts =
        await dao.countMap('template', picks.map((t) => t.id).toList());
    for (final t in picks) {
      final e = counts[t.id];
      result[t.id] = (e?.useShoot ?? 0) * 2 + (e?.openDetail ?? 0);
    }
    return result;
  }

  /// 截断字符串到 [max] 字符，超出加省略号
  String _truncate(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}…';
  }
}
