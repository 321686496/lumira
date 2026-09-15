import 'package:flutter/foundation.dart';

import '../../../core/db/dao/composition_kits_dao.dart';
import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/dao/growth_dao.dart';
import '../../../core/db/dao/scenes_dao.dart';
import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/dao/usage_dao.dart';
import '../../../core/db/dao/user_interests_dao.dart';
import '../../../features/profile/data/composition_kit_models.dart';
import '../../../features/profile/data/profile_dao.dart';
import '../../templates/recommend/template_ranking.dart';
import '../../onboarding/data/questionnaire_dao.dart';
import '../data/home_mock_data.dart';
import '../data/operation_banners.dart';

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
/// 4 个固定槽位：
/// 0. 运营位（[OperationUserInputs] 条件满足则占，否则让位个性化补位）
/// 1. 新用户引导/问卷（新用户前置判断）或最近常拍分类（老用户）
/// 2. 基于收藏场景/常用套件
/// 3. 探索新鲜感（用户少拍的类型）；老用户且 slot 0 无运营位时补一条
class RecommendationService {
  RecommendationService({
    required GalleryDao galleryDao,
    required ScenesDao scenesDao,
    required TemplatesDao templatesDao,
    required CompositionKitsDao kitsDao,
    required GrowthDao growthDao,
    required QuestionnaireDao questionnaireDao,
    UsageDao? usageDao,
    InterestDao? interestDao,
    UserProfileDao? profileDao,
  })  : _galleryDao = galleryDao,
        _scenesDao = scenesDao,
        _templatesDao = templatesDao,
        _kitsDao = kitsDao,
        _growthDao = growthDao,
        _questionnaireDao = questionnaireDao,
        _usageDao = usageDao,
        _interestDao = interestDao,
        _profileDao = profileDao;

  final GalleryDao _galleryDao;
  final ScenesDao _scenesDao;
  final TemplatesDao _templatesDao;
  final CompositionKitsDao _kitsDao;
  final GrowthDao _growthDao;
  final QuestionnaireDao _questionnaireDao;
  final UsageDao? _usageDao;
  final InterestDao? _interestDao;
  final UserProfileDao? _profileDao;

  /// 本次构建解析出的用户性别（'male'/'female'），未知/不愿透露为 null。仅随单次
  /// buildBanners 使用，作为所有槽位挑模板时的性别硬过滤依据。
  String? _resolvedGender;

  /// 构建首页 Banner（槽位：运营位 + 个性化位 + 活动/广告位）
  ///
  /// [operationInputs] 为运营位条件所需的用户状态快照（远端拉取，失败/离线
  /// 传空 → 不出运营位，slot 0 由个性化补位）。
  /// [operationBanners] 为运营条目目录（默认静态；远端拉取成功后注入后台下发列表）。
  /// kind=ad 的广告条目按各自 [position] 归位插入（缺省/越界放最后），并过滤出
  /// 后台统一下发的广告；广告不参与 slot 0 运营位条件匹配。
  Future<List<HomeBannerItem>> buildBanners({
    OperationUserInputs operationInputs = const OperationUserInputs(),
      List<OperationBanner> operationBanners = kOperationBanners,
  }) async {
    // 并行启动所有数据源查询（Future 创建即开始执行，await 顺序不影响并行性）
    final categoryCountsFuture = _galleryDao.countByCategory();
    final favoriteScenesFuture = _scenesDao.getFavorites();
    final totalPhotosFuture = _growthDao.getTotalPhotos();
    final allKitsFuture = _kitsDao.getAll();
    // 候选池 = 内置推荐位 ∪ 全部远程模板（后台实时下发的运营模板参与 Banner 推荐）
    final systemPicksFuture = _templatesDao.getRecommendedCandidatePool();
    final popularityFuture = _loadTemplatePopularity();

    final categoryCounts = await categoryCountsFuture;
    final favoriteScenes = await favoriteScenesFuture;
    final totalPhotos = await totalPhotosFuture;
    final allKits = await allKitsFuture;
    final systemPicks = await systemPicksFuture;
    final popularity = await popularityFuture;
    // 解析用户性别（Profile 优先，问卷兜底）作为本次所有槽位的性别硬过滤依据
    _resolvedGender = await _userGender();
    final interestById = await _loadTemplateInterest(systemPicks);
    // 最近用过的模板（用户已实际拍摄过/相册里存在的），推荐时优先排除，
    // 避免轮播重复推用户刚用过的同款内容（与主流推荐 app 一致）。
    final recentlyUsed = await _loadRecentlyUsedTemplateIds();

    // 客户端按 usage_count DESC 排序（DAO 未提供 orderByUsage 参数）
    final kitsByUsage = [...allKits]..sort((a, b) => b.usageCount.compareTo(a.usageCount));

    final isNewUser = totalPhotos < _kNewUserThreshold;

    // 拆分广告与运营位：广告按 position 归位展示（不参与 slot 0 条件匹配）
    final ads = operationBanners
        .where((b) => b.kind == OperationBannerKind.ad)
        .toList();
    final ops = operationBanners
        .where((b) => b.kind != OperationBannerKind.ad)
        .toList();

    final List<HomeBannerItem> banners = [];
    final Set<String> usedTemplateIds = {};
    final Set<String> usedSceneIds = {};
    final Set<String> usedCategories = {};

    // === slot 0：运营位（条件满足则占，否则让位给个性化补位） ===
    final operation = matchOperationBanner(
      isNewUser: isNewUser,
      banners: ops,
      inputs: operationInputs,
    );
    if (operation != null) {
      banners.add(operationBannerToItem(operation));
    }

    // === slot 1：新用户引导/问卷（前置判断）或最近常拍分类 ===
    // 统一读取问卷（含性别 + 二级风格偏好）；老用户可从未答或已拍模板推断风格。
    final questionnaire = await _questionnaireDao.getAnswers();
    final userGender = questionnaire?.gender;
    // 偏好风格集合：问卷二级风格 ∪ 老用户最常拍模板的二级风格（含目录缺失时回退）
    final preferredStyles = <String>{...?questionnaire?.favoriteStyles};
    if (!isNewUser) {
      try {
        final templateCounts = await _galleryDao.countByTemplate();
        if (templateCounts.isNotEmpty) {
          final topEntry =
              templateCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);
          final topTpl = await _templatesDao.getById(topEntry.key);
          final s = topTpl == null ? null : _secondaryStyleOf(topTpl);
          if (s != null) preferredStyles.add(s);
        }
      } catch (e) {
        debugPrint('[recommend] infer preferred style failed (silent fallback): $e');
      }
    }

    if (isNewUser) {
      // 优先读问卷偏好，推用户首选分类的推荐模板
      final favCats = questionnaire?.favoriteCategories ?? [];
      HomeBannerItem? questionnaireBanner;
      if (favCats.isNotEmpty) {
        final topCat = favCats.first;
        var tpls = await _templatesDao.getBuiltin(
          category: topCat,
          isRecommended: true,
        );
        // 二级风格细分：问卷在"大类下勾选的风格"进行过滤（无偏好不收敛）
        if (preferredStyles.isNotEmpty) {
          final styleFiltered = tpls
              .where((t) => preferredStyles.contains(_secondaryStyleOf(t)))
              .toList();
          if (styleFiltered.isNotEmpty) tpls = styleFiltered;
        }
        final candidates = _rankCandidates(tpls, usedTemplateIds);
        // 性别软偏好：同性别 + 通用模板优先（未知性别不分组），匹配组空回退全池
        final tpl = _pickGenderPreferred(
          candidates, userGender, popularity, interestById,
        );
        if (tpl != null) {
          usedTemplateIds.add(tpl.id);
          usedCategories.add(topCat);
          final label = _categoryLabelMap[topCat] ?? '推荐';
          questionnaireBanner = HomeBannerItem(
            id: 'banner_questionnaire_pick',
            bannerId: 'banner_questionnaire_pick:${tpl.id}',
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
    } else {
      // 老用户：基于最近拍摄分类，细分到偏好二级风格 + 性别匹配
      final topCategory = _pickTopCategory(categoryCounts);
      TemplateRecord? slot1Tpl;
      var slot1Tag = '为你精选'; // 冷启动 fallback 标签
      if (topCategory != null) {
        var tpls = await _templatesDao.getBuiltin(
          category: topCategory,
          isRecommended: true,
        );
        // 二级风格细分：优先推荐与用户偏好风格一致的模板（无偏好不收敛）
        if (preferredStyles.isNotEmpty) {
          final styleFiltered = tpls
              .where((t) => preferredStyles.contains(_secondaryStyleOf(t)))
              .toList();
          if (styleFiltered.isNotEmpty) tpls = styleFiltered;
        }
        // 去重：排除已占用模板 + 最近用过模板
        final candidates = _rankCandidates(
          tpls,
          usedTemplateIds,
          recentlyUsed: recentlyUsed,
        );
        if (candidates.isNotEmpty) {
          // 性别软偏好：同性别 + 通用模板优先
          slot1Tpl = _pickGenderPreferred(
            candidates, userGender, popularity, interestById,
          );
          slot1Tag = '常拍分类';
          usedCategories.add(topCategory);
        }
      }
      slot1Tpl ??= _pickUnusedSystemPick(
        systemPicks,
        usedTemplateIds,
        popularity,
        interestById,
        recentlyUsed,
      );
      if (slot1Tpl != null) {
        usedTemplateIds.add(slot1Tpl.id);
        final label = _categoryLabelMap[topCategory] ?? '推荐';
        final hasCategory = topCategory != null;
        // 文案钩子：有常拍分类时优先用模板 shortDesc 做情境化情绪标题
        // （如「雷阵雨后的街头光影」），无 shortDesc 回退「继续拍X」
        final title = hasCategory
            ? (slot1Tpl.shortDesc.isNotEmpty
                ? slot1Tpl.shortDesc
                : '继续拍$label')
            : slot1Tpl.name;
        final subtitle =
            hasCategory ? '你最近常拍$label，试试这套模板' : _bannerSubtitle(slot1Tpl);
        banners.add(HomeBannerItem(
          id: 'banner_recent_category',
          bannerId: 'banner_recent_category:${slot1Tpl.id}',
          title: title,
          subtitle: subtitle,
          imageSeed: 'banner-recent-${topCategory ?? slot1Tpl.id}',
          tag: slot1Tag,
          route: '/templates/detail?templateId=${slot1Tpl.id}',
          cover: slot1Tpl.cover.isNotEmpty ? slot1Tpl.cover : null,
          coverData: slot1Tpl.coverData,
        ));
      }
    }

    // === slot 2：基于收藏场景/常用套件 ===
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
          bannerId: 'banner_favorite_scene_fallback:${tpl.id}',
          title: tpl.name,
          subtitle: _bannerSubtitle(tpl),
          imageSeed: 'banner-pick-${tpl.id}',
          tag: '为你精选',
          route: '/templates/detail?templateId=${tpl.id}',
          cover: tpl.cover.isNotEmpty ? tpl.cover : null,
          coverData: tpl.coverData,
        ));
      }
    }

    // === slot 3：探索新鲜感（用户少拍的类型） ===
    await _buildExplorationBanner(
      banners: banners,
      categoryCounts: categoryCounts,
      usedCategories: usedCategories,
      usedTemplateIds: usedTemplateIds,
      systemPicks: systemPicks,
      idSuffix: '',
      popularity: popularity,
      interestById: interestById,
      recentlyUsed: recentlyUsed,
    );

    // === 老用户补位：slot 0 无运营条目时再补一条探索，维持总量 4 条 ===
    if (operation == null && !isNewUser) {
      await _buildExplorationBanner(
        banners: banners,
        categoryCounts: categoryCounts,
        usedCategories: usedCategories,
        usedTemplateIds: usedTemplateIds,
        systemPicks: systemPicks,
        idSuffix: '_extra',
        popularity: popularity,
        interestById: interestById,
        recentlyUsed: recentlyUsed,
      );
    }

    // === 活动/广告位：按各自 position 归位插入（缺省/越界放最后） ===
    for (final ad in ads) {
      final insertAt = (ad.position != null &&
              ad.position! >= 0 &&
              ad.position! < banners.length)
          ? ad.position!
          : banners.length;
      banners.insert(insertAt, operationBannerToItem(ad));
    }

    return banners;
  }

  /// 模板类 Banner 副标题：优先用模板短描述，否则截断 description。
  String _bannerSubtitle(TemplateRecord tpl) {
    if (tpl.shortDesc.isNotEmpty) return tpl.shortDesc;
    return _truncate(tpl.description, 30);
  }

  /// 构建单条探索新鲜感 banner。
  /// idSuffix 为空 = slot 3 探索位；`_extra` = 老用户补位探索
  /// （slot 0 无运营位时维持 4 条）。
  Future<void> _buildExplorationBanner({
    required List<HomeBannerItem> banners,
    required Map<String, int> categoryCounts,
    required Set<String> usedCategories,
    required Set<String> usedTemplateIds,
    required List<TemplateRecord> systemPicks,
    required String idSuffix,
    required Map<String, int> popularity,
    required Map<String, double> interestById,
    Set<String> recentlyUsed = const {},
  }) async {
    final explorationCat =
        _pickExplorationCategory(categoryCounts, usedCategories);
    if (explorationCat != null) {
      usedCategories.add(explorationCat);
      final tpls = await _templatesDao.getBuiltin(category: explorationCat);
      // 去重：过滤掉已被前面槽位用过的 / 尽量排除最近用过的 templateId
      final candidates = _rankCandidates(
        tpls,
        usedTemplateIds,
        recentlyUsed: recentlyUsed,
      );
      final tpl = candidates.isNotEmpty
          ? _pickBest(candidates, popularity, interestById)
          : _pickUnusedSystemPick(systemPicks, usedTemplateIds, popularity,
              interestById, recentlyUsed);
      if (tpl != null) {
        usedTemplateIds.add(tpl.id);
        final label = _categoryLabelMap[explorationCat] ?? explorationCat;
        banners.add(HomeBannerItem(
          id: 'banner_exploration$idSuffix',
          bannerId: 'banner_exploration$idSuffix:${tpl.id}',
          // 文案钩子：社会证明（基于分类热度/「最近都在拍」）
          title: '大家都在拍$label',
          subtitle: _bannerSubtitle(tpl),
          imageSeed: 'banner-explore-$explorationCat$idSuffix',
          tag: '探索新鲜',
          route: '/templates/detail?templateId=${tpl.id}',
          cover: tpl.cover.isNotEmpty ? tpl.cover : null,
          coverData: tpl.coverData,
        ));
      }
    } else {
      // 无可用分类时，fallback 到系统推荐
      final tpl = _pickUnusedSystemPick(systemPicks, usedTemplateIds, popularity,
          interestById, recentlyUsed);
      if (tpl != null) {
        usedTemplateIds.add(tpl.id);
        banners.add(HomeBannerItem(
          id: 'banner_exploration$idSuffix',
          bannerId: 'banner_exploration$idSuffix:${tpl.id}',
          title: tpl.name,
          subtitle: _bannerSubtitle(tpl),
          imageSeed: 'banner-pick-${tpl.id}$idSuffix',
          tag: '为你精选',
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

  /// 从 [picks] 中取"未被本批次占用"（[usedTemplateIds]）且尽量"非最近用过"
  /// （[recentlyUsed]，软倾向）的排序候选。
  /// 仅剩最近用过时仍返回（避免空候选导致 banner 缺失）。
  List<TemplateRecord> _rankCandidates(
    List<TemplateRecord> picks,
    Set<String> usedTemplateIds, {
    Set<String> recentlyUsed = const {},
  }) {
    final fresh = picks.where((t) => !usedTemplateIds.contains(t.id)).toList();
    if (recentlyUsed.isEmpty || fresh.isEmpty) return fresh;
    final newish =
        fresh.where((t) => !recentlyUsed.contains(t.id)).toList();
    return newish.isNotEmpty ? newish : fresh;
  }

  /// 在候选列表里选"热度*0.5 + 个人兴趣*0.5"混合分最大的模板；
  /// 分数打平时优先更新更晚的（利于新上线的线上模板/新模板曝光）。
  /// 挑选前先按用户性别硬过滤（仅保留通用 + 同性别模板）。
  TemplateRecord? _pickBest(
    List<TemplateRecord> candidates,
    Map<String, int> popularity,
    Map<String, double> interestById,
  ) {
    final pool = _genderFiltered(candidates);
    if (pool.isEmpty) return null;
    var best = pool.first;
    var bestScore = _blendScore(best, popularity, interestById);
    for (final t in pool.skip(1)) {
      final s = _blendScore(t, popularity, interestById);
      if (s > bestScore ||
          (s == bestScore && t.updatedAt > best.updatedAt)) {
        bestScore = s;
        best = t;
      }
    }
    return best;
  }

  /// 按已解析用户性别硬过滤候选池：仅保留 通用(unisex) + 同性别 模板。
  /// 同性别 + 通用均不存在时回退全池（含异性别），避免槽位空缺。
  /// 性别未知/不愿透露时不过滤。
  List<TemplateRecord> _genderFiltered(List<TemplateRecord> records) {
    final g = _resolvedGender;
    if (g == null || g.isEmpty) return records;
    final hit = records
        .where((t) => t.gender == 'unisex' || t.gender == g)
        .toList();
    return hit.isNotEmpty ? hit : records;
  }

  /// 解析用户性别：Profile 优先，问卷兜底；返回 'male'/'female'。
  /// 未设置或不方便透露时返回 null（不参与性别过滤）。
  Future<String?> _userGender() async {
    String? g;
    try {
      g = (await _profileDao?.get())?.gender;
    } catch (_) {/* 读取失败继续走问卷兜底 */}
    if (g == null || g == 'prefer_not') {
      try {
        g = (await _questionnaireDao.getAnswers())?.gender;
      } catch (_) {/* 问卷读取失败按未知处理 */}
    }
    return _mapGender(g);
  }

  /// 把性别值归一化为 'male'/'female'；非法/空/'prefer_not' 返回 null。
  static String? _mapGender(String? g) {
    if (g == 'male' || g == 'female') return g;
    return null;
  }

  /// 模板的「二级风格 key」：人像取 majorStyle，其余取 style。
  /// 与分类树 L2（人像大风格/非人像风格）保持一致。
  String? _secondaryStyleOf(TemplateRecord t) {
    final cls = t.classification;
    final major = cls['majorStyle'] as String?;
    if (major != null && major.isNotEmpty) return major;
    return cls['style'] as String?;
  }

  /// 按用户性别硬过滤后选最优（性别过滤统一走 [_pickBest] → [_resolvedGender]）。
  /// 同性别 + 通用不存在时回退全池，保证不空槽。
  /// [userGender] 入参保留以兼容调用方，实际以本次已解析性别为准。
  TemplateRecord? _pickGenderPreferred(
    List<TemplateRecord> candidates,
    String? userGender,
    Map<String, int> popularity,
    Map<String, double> interestById,
  ) {
    return _pickBest(candidates, popularity, interestById);
  }

  /// 从系统推荐列表中取未占用、且“(热度*0.5 + 个人兴趣*0.5) 混合分”最大的模板；
  /// 流行度全为 0/空时退回第一个未占用模板（保持原行为）。
  TemplateRecord? _pickUnusedSystemPick(
    List<TemplateRecord> systemPicks,
    Set<String> usedTemplateIds,
    Map<String, int> popularity, [
    Map<String, double> interestById = const {},
    Set<String> recentlyUsed = const {},
  ]) {
    final candidates =
        _rankCandidates(systemPicks, usedTemplateIds, recentlyUsed: recentlyUsed);
    return _pickBest(candidates, popularity, interestById);
  }

  /// 热度(原始)与个人兴趣的 0.5/0.5 混合分
  double _blendScore(TemplateRecord t, Map<String, int> popularity,
      Map<String, double> interestById) {
    return (popularity[t.id] ?? 0).toDouble() * 0.5 +
        (interestById[t.id] ?? 0) * 0.5;
  }

  /// 并行读取用户"最近用过的模板"集合：相册中存在照片（countByTemplate）+
  /// usage_dao 里 use_shoot 点数 >0 的模板。用于推荐时软排除，避免轮播重复推
  /// 用户刚用过的同款模板。读取失败静默降级为空集。
  Future<Set<String>> _loadRecentlyUsedTemplateIds() async {
    final result = <String>{};
    try {
      result.addAll((await _galleryDao.countByTemplate()).keys);
      final dao = _usageDao;
      if (dao != null) {
        final picks = await _templatesDao.getRecommendedCandidatePool();
        final counts =
            await dao.countMap('template', picks.map((t) => t.id).toList());
        for (final e in counts.entries) {
          if (e.value.useShoot > 0) result.add(e.key);
        }
      }
    } catch (e) {
      debugPrint('[recommend] load recently-used templates failed (silent fallback): $e');
    }
    return result;
  }

  /// 并行读取模板的个人兴趣（基于用户兴趣画像的三维加权）。未注入 interestDao 时返回空 map；
  /// 画像读取失败时静默回退空 map，不影响 Banner 主流程。
  Future<Map<String, double>> _loadTemplateInterest(
    List<TemplateRecord> picks,
  ) async {
    final dao = _interestDao;
    if (dao == null || picks.isEmpty) return const {};
    try {
      final all = await dao.getAll();
      final portrait = <String, double>{};
      for (final e in all.entries) {
        portrait[e.key] = e.value.score;
      }
      final ctx = RankingContext(
        nowMs: DateTime.now().millisecondsSinceEpoch,
        portrait: portrait,
      );
      return {
        for (final t in picks) t.id: TemplateRanking().interestFor(t, ctx),
      };
    } catch (e) {
      debugPrint('[recommend] load template interest failed (silent fallback): $e');
      return const {};
    }
  }

  /// 并行读取推荐候选池的全站流行度（templateId -> use_shoot*2 + open_detail）。
  /// 未注入 usageDao 时返回空 map。候选池含远程模板（纳入后台运营模板热度）。
  Future<Map<String, int>> _loadTemplatePopularity() async {
    final dao = _usageDao;
    if (dao == null) return const {};
    final picks = await _templatesDao.getRecommendedCandidatePool();
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
