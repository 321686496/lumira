import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/home/data/home_mock_data.dart' show BannerType;
import 'package:lumira_app_flutter/features/home/data/operation_banners.dart';
import 'package:lumira_app_flutter/features/home/data/operation_banners_repository.dart';
import 'package:lumira_app_flutter/features/home/providers/banner_recommendation_provider.dart';
import 'package:lumira_app_flutter/features/invite/data/invite_models.dart';
import 'package:lumira_app_flutter/features/invite/data/invite_repository.dart';
import 'package:lumira_app_flutter/features/points/data/points_models.dart';
import 'package:lumira_app_flutter/features/points/data/points_repository.dart';
import 'package:lumira_app_flutter/features/templates/data/owned_templates_repository.dart';

/// bannerRecommendationProvider 接线回归测试
///
/// 历史 Bug：provider 定义了 `_loadOperationBanners`（拉后台运营目录）却从未调用，
/// 导致首页 slot 0 永远用静态 kOperationBanners，后台动态改 banner 不生效。
/// 修复后 provider 会把远端目录注入 buildBanners（operationBanners: ...）。
///
/// 关键验证：远端下发的运营条目应真实作用于 slot 0，取代静态目录；空列表应
/// 维持「后台全部停用 → 不出运营位」语义。
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late Database db;

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
  });

  tearDown(() => db.close());

  /// 构造带 overrides 的容器：数据库 + 4 个远端依赖全部打桩。
  /// [opBanners] 为后台下发的运营条目目录。
  ProviderContainer makeContainer(List<OperationBanner> opBanners) {
    return ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
      operationBannersRepositoryProvider
          .overrideWith((ref) async => _FakeOperationBannersRepo(opBanners)),
      pointsRepositoryProvider.overrideWith((ref) async => _FakePointsRepo()),
      inviteRepositoryProvider.overrideWith((ref) async => _FakeInviteRepo()),
      ownedTemplatesRepositoryProvider
          .overrideWith((ref) async => _FakeOwnedTemplatesRepo()),
    ]);
  }

  /// 后台下发的「积分」运营条目：与静态 op_points 同 route / 同条件，
  /// 但 id / title 不同，用于区分「远程注入生效」vs「仍用静态」。
  const backendBanner = OperationBanner(
    id: 'op_backend_points',
    title: '后台配置：去积分中心',
    subtitle: '来自后台的动态配置',
    tag: '后台运营',
    route: '/points/wallet',
    condition: OperationCondition.pointsReady,
  );

  test('远端运营条目注入 slot 0：后台下发 banner 取代静态目录', () async {
    final container = makeContainer([backendBanner]);
    addTearDown(container.dispose);

    final banners = await container.read(bannerRecommendationProvider.future);

    expect(banners, isNotEmpty);
    // slot 0 必须是后台下发的条目（此前死代码会落到静态 op_points）
    expect(banners.first.type, BannerType.operation);
    expect(banners.first.id, 'op_backend_points');
    expect(banners.first.bannerId, 'op_backend_points');
    expect(banners.first.route, '/points/wallet');
    expect(banners.first.tag, '后台运营');
  });

  test('后台全部停用（空列表）→ 不出现运营位', () async {
    final container = makeContainer(const []);
    addTearDown(container.dispose);

    final banners = await container.read(bannerRecommendationProvider.future);

    expect(banners.where((b) => b.type == BannerType.operation), isEmpty,
        reason: '后台空列表 = 运营位停用，slot 0 让位个性化推荐');
  });
}

/// 测试库 schema：建出 bannerRecommendationProvider 依赖的最小表集。
/// 与 recommendation_service_test.dart 保持一致，保证各 DAO 查询可用。
Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE ${Tables.galleryItems} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colDataUrl} TEXT,
      ${Tables.colFilePath} TEXT,
      ${Tables.colOriginalPath} TEXT,
      ${Tables.colTransform} TEXT,
      ${Tables.colPostProcess} TEXT,
      ${Tables.colSceneId} TEXT,
      ${Tables.colTemplateId} TEXT,
      ${Tables.colKitId} TEXT,
      ${Tables.colMood} TEXT,
      ${Tables.colLut} TEXT,
      ${Tables.colGalleryItemIsFavorite} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCreatedAt} INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE ${Tables.scenes} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colIcon} TEXT NOT NULL DEFAULT '',
      ${Tables.colCategory} TEXT NOT NULL,
      ${Tables.colStyle} TEXT NOT NULL DEFAULT '',
      ${Tables.colFilterJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colVibe} TEXT NOT NULL DEFAULT '',
      ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
      ${Tables.colExampleImagesJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colTipsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colWhereToShoot} TEXT NOT NULL DEFAULT '',
      ${Tables.colBestTime} TEXT NOT NULL DEFAULT '',
      ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colRelatedCategory} TEXT NOT NULL DEFAULT '',
      ${Tables.colRecommendedTagIdsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colTagIdsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colCreator} TEXT NOT NULL DEFAULT 'user',
      ${Tables.colIsFavorite} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCoverUrl} TEXT NOT NULL DEFAULT '',
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE ${Tables.customTemplates} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colAuthor} TEXT NOT NULL DEFAULT '',
      ${Tables.colVersion} TEXT NOT NULL DEFAULT '1.0.0',
      ${Tables.colCategory} TEXT NOT NULL,
      ${Tables.colClassificationJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colTagsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colTagIdsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colPrice} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCover} TEXT NOT NULL DEFAULT '',
      ${Tables.colCoverData} TEXT,
      ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
      ${Tables.colReferenceSource} TEXT NOT NULL DEFAULT '',
      ${Tables.colShortDesc} TEXT NOT NULL DEFAULT '',
      ${Tables.colAmbienceJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colCompositionJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPoseJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colImagesJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colCameraJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPostProcessJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colIsBuiltin} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colIsRecommended} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colSource} TEXT NOT NULL DEFAULT 'builtin',
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  await db.execute(CompositionKitsTable.createSql);
  await db.execute('''
    CREATE TABLE ${Tables.questionnaire} (
      ${Tables.colId} INTEGER PRIMARY KEY DEFAULT 1,
      ${Tables.colAnswersJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colSubmittedAt} INTEGER,
      ${Tables.colSyncedAt} INTEGER
    )
  ''');
  await db.execute('''
    CREATE TABLE ${Tables.userProgress} (
      ${Tables.colId} INTEGER PRIMARY KEY DEFAULT 1,
      ${Tables.colLevel} INTEGER NOT NULL DEFAULT 1,
      ${Tables.colLevelName} TEXT NOT NULL DEFAULT '新手',
      ${Tables.colXp} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colXpToNextLevel} INTEGER NOT NULL DEFAULT 100,
      ${Tables.colTotalPhotos} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colUsedTemplates} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colFavorites} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colStreakDays} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colLastCheckInDate} TEXT,
      ${Tables.colFragmentsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colAchievementsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  await db.insert(Tables.userProgress, {
    Tables.colId: 1,
    Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
  });
}

// ===== 远端依赖 Fake =====

class _FakeOperationBannersRepo implements OperationBannersRepository {
  _FakeOperationBannersRepo(this.banners);
  final List<OperationBanner> banners;
  @override
  Future<List<OperationBanner>> list() async => banners;
}

class _FakePointsRepo implements PointsRepository {
  @override
  Future<PointsBalance> getBalance() async =>
      PointsBalance.fromJson(const {'balance': 30});
  @override
  Future<PointsTransactions> listTransactions({
    int limit = 50,
    int offset = 0,
  }) async =>
      throw UnimplementedError();
  @override
  Future<PointEarnResult> earn({required String type, String? refId}) async =>
      throw UnimplementedError();
}

class _FakeInviteRepo implements InviteRepository {
  @override
  Future<InviteStats> stats() async => throw UnimplementedError();
  @override
  Future<InviteCode> generate() async => throw UnimplementedError();
  @override
  Future<ActivateInviteResponse> activate(ActivateInviteRequest req) async =>
      throw UnimplementedError();
  @override
  Future<CompleteInviteResponse> completeInvite() async =>
      throw UnimplementedError();
}

class _FakeOwnedTemplatesRepo implements OwnedTemplatesRepository {
  @override
  Future<OwnedTemplates> listOwned() async => throw UnimplementedError();
  @override
  Future<TemplatePrices> listPrices() async => throw UnimplementedError();
  @override
  Future<TemplateExchangeResult> exchange(
    String templateId, {
    int? priceCredits,
    String payBy = 'points',
  }) async =>
      throw UnimplementedError();
}