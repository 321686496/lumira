import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/templates/data/remote_template_dto.dart';
import 'package:lumira_app_flutter/features/templates/data/remote_templates_providers.dart';
import 'package:lumira_app_flutter/features/templates/data/remote_templates_repository.dart';

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

  test('fetches missing remote template detail into local cache', () async {
    final repository = _FakeRemoteTemplatesRepository();
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
      remoteTemplatesRepositoryProvider.overrideWith((ref) async => repository),
    ]);
    addTearDown(container.dispose);

    final detail =
        await container.read(templateDetailProvider('tpl_new').future);

    expect(repository.fetchDetailCalls, ['tpl_new']);
    expect(detail, isNotNull);
    expect(detail!.id, 'tpl_new');

    final dao = await container.read(templatesDaoProvider.future);
    final cached = await dao.getById('tpl_new');
    expect(cached, isNotNull);
    expect(cached!.source, 'remote');
    expect(cached.composition, isNotEmpty);
  });
}

Future<void> _onCreate(Database db, int version) async {
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
      ${Tables.colCompositionJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPoseJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colImagesJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colCameraJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPostProcessJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colIsBuiltin} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colIsRecommended} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colSource} TEXT NOT NULL DEFAULT 'builtin',
      ${Tables.colShortDesc} TEXT NOT NULL DEFAULT '',
      ${Tables.colAmbienceJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
}

class _FakeRemoteTemplatesRepository implements RemoteTemplatesRepository {
  final fetchDetailCalls = <String>[];

  @override
  Future<RemoteTemplateDetailDto> fetchDetail(String id) async {
    fetchDetailCalls.add(id);
    return const RemoteTemplateDetailDto(
      id: 'tpl_new',
      name: '涓婃柊妯℃澘',
      author: 'lumira',
      version: '1.0.0',
      category: 'portrait',
      price: 0,
      coverUrl: 'https://example.com/cover.jpg',
      description: '鍚庡彴鍒氫笂鏂扮殑妯℃澘',
      referenceSource: '',
      tags: [],
      tagIds: [],
      classification: RemoteTemplateClassificationDto(type: 'portrait'),
      sortOrder: 0,
      composition: {
        'background': {'color': 0xFFFFFFFF}
      },
      pose: {'poses': []},
      camera: {},
      sceneGuide: {},
      postProcess: {},
      updatedAt: 1760000000,
    );
  }

  @override
  Future<List<TemplateCategoryDto>> fetchCategories() async =>
      throw UnimplementedError();

  @override
  Future<RemoteTemplateListResponseDto> list({
    int? since,
    String? category,
  }) async =>
      throw UnimplementedError();

  @override
  Future<RemoteTemplateSearchResponseDto> search({
    required String q,
    required TemplateSearchSort sort,
    String? category,
    int page = 1,
    int pageSize = 20,
  }) async =>
      throw UnimplementedError();
}
