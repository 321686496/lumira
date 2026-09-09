import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:lumira_app_flutter/core/db/dao/settings_dao.dart';
import 'package:lumira_app_flutter/core/theme/capture_appearance.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';

void main() {
  late Database db;
  late SettingsDao dao;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE user_settings (
            id INTEGER PRIMARY KEY DEFAULT 1,
            theme_key TEXT NOT NULL DEFAULT 'warmWhite',
            theme_key_dark TEXT NOT NULL DEFAULT 'ink',
            theme_key_light TEXT NOT NULL DEFAULT 'warmWhite',
            ui_style TEXT NOT NULL DEFAULT 'neumorphic',
            follow_system INTEGER NOT NULL DEFAULT 0,
            capture_fullscreen INTEGER NOT NULL DEFAULT 0,
            grid_enabled INTEGER NOT NULL DEFAULT 0,
            level_enabled INTEGER NOT NULL DEFAULT 1,
            shutter_sound INTEGER NOT NULL DEFAULT 1,
            capture_appearance TEXT NOT NULL DEFAULT 'immersive',
            watermark INTEGER NOT NULL DEFAULT 0,
            seed_v3_done INTEGER NOT NULL DEFAULT 0,
            auto_deblur INTEGER NOT NULL DEFAULT 1,
            free_mode_camera TEXT,
            free_mode_post_process TEXT,
            free_mode_composition TEXT,
            watermark_settings TEXT,
            camera_facing TEXT,
            aspect_ratio TEXT,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.insert('user_settings', {
          'id': 1,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });
      },
    );
    dao = SettingsDao(db);
  });

  tearDown(() async => db.close());

  test('default value is true (1)', () async {
    final value = await dao.getAutoDeblur();
    expect(value, isTrue);
  });

  test('setAutoDeblur(false) persists to DB', () async {
    await dao.setAutoDeblur(false);
    final value = await dao.getAutoDeblur();
    expect(value, isFalse);
    final rows = await db.query('user_settings', where: 'id = 1');
    expect(rows.first['auto_deblur'], equals(0));
  });

  test('setAutoDeblur(true) after false works', () async {
    await dao.setAutoDeblur(false);
    await dao.setAutoDeblur(true);
    expect(await dao.getAutoDeblur(), isTrue);
  });

  group('level enabled persistence', () {
    test('default is true (1) even when DB has no explicit value', () async {
      // 无行时回退 true
      await db.delete('user_settings', where: 'id = 1');
      expect(await dao.getLevelEnabled(), isTrue);
    });

    test('getLevelEnabled reads current DB value', () async {
      expect(await dao.getLevelEnabled(), isTrue);
    });

    test('setLevelEnabled(false) persists to DB', () async {
      await dao.setLevelEnabled(false);
      expect(await dao.getLevelEnabled(), isFalse);
      final rows = await db.query('user_settings', where: 'id = 1');
      expect(rows.first['level_enabled'], equals(0));
    });

    test('setLevelEnabled(true) after false works', () async {
      await dao.setLevelEnabled(false);
      await dao.setLevelEnabled(true);
      expect(await dao.getLevelEnabled(), isTrue);
    });
  });

  group('free mode params persistence', () {
    test('setFreeModeCamera persists and getFreeModeCamera returns same value', () async {
      const params = CameraParams(
        exposureCompensation: 1.5,
        iso: 400,
        shutterSpeed: '1/125',
        whiteBalance: 'cloudy',
        flashMode: 'auto',
        focusMode: 'continuous',
      );
      await dao.setFreeModeCamera(params);
      final restored = await dao.getFreeModeCamera();
      expect(restored, isNotNull);
      expect(restored!.exposureCompensation, equals(1.5));
      expect(restored.iso, equals(400));
      expect(restored.shutterSpeed, equals('1/125'));
      expect(restored.whiteBalance, equals('cloudy'));
      expect(restored.flashMode, equals('auto'));
      expect(restored.focusMode, equals('continuous'));
    });

    test('getFreeModeCamera returns null when not set', () async {
      final restored = await dao.getFreeModeCamera();
      expect(restored, isNull);
    });

    test('setFreeModePostProcess persists and getFreeModePostProcess returns same value', () async {
      const params = PostProcess(
        cropRatio: '1:1',
        color: PostProcessColor(brightness: 10, saturation: 20, clarity: 15),
        smoothStrength: 12,
        sharpen: 25,
        vignette: 30,
        grain: 8,
        lut: 'cinematic',
        systemFilter: 'vivid',
      );
      await dao.setFreeModePostProcess(params);
      final restored = await dao.getFreeModePostProcess();
      expect(restored, isNotNull);
      expect(restored!.cropRatio, equals('1:1'));
      expect(restored.color.brightness, equals(10));
      expect(restored.color.saturation, equals(20));
      expect(restored.color.clarity, equals(15));
      expect(restored.smoothStrength, equals(12));
      expect(restored.sharpen, equals(25));
      expect(restored.vignette, equals(30));
      expect(restored.grain, equals(8));
      expect(restored.lut, equals('cinematic'));
      expect(restored.systemFilter, equals('vivid'));
    });

    test('setFreeModeComposition persists and getFreeModeComposition returns same value', () async {
      const params = Composition(
        overlayType: 'golden_ratio',
        opacity: 0.7,
        aspectRatio: '4:3',
        description: '测试构图',
      );
      await dao.setFreeModeComposition(params);
      final restored = await dao.getFreeModeComposition();
      expect(restored, isNotNull);
      expect(restored!.overlayType, equals('golden_ratio'));
      expect(restored.opacity, equals(0.7));
      expect(restored.aspectRatio, equals('4:3'));
      expect(restored.description, equals('测试构图'));
    });
  });

  group('拍摄页偏好持久化', () {
    test('getCameraFacing returns null when not set', () async {
      expect(await dao.getCameraFacing(), isNull);
    });

    test('setCameraFacing persists and getCameraFacing returns same value', () async {
      await dao.setCameraFacing('front');
      expect(await dao.getCameraFacing(), equals('front'));
      await dao.setCameraFacing('back');
      expect(await dao.getCameraFacing(), equals('back'));
    });

    test('getCameraFacing rejects invalid value', () async {
      await db.update('user_settings', {'camera_facing': 'side'}, where: 'id = 1');
      expect(await dao.getCameraFacing(), isNull);
    });

    test('getAspectRatio returns null when not set', () async {
      expect(await dao.getAspectRatio(), isNull);
    });

    test('setAspectRatio persists and getAspectRatio returns same value', () async {
      await dao.setAspectRatio('4:3');
      expect(await dao.getAspectRatio(), equals('4:3'));
      await dao.setAspectRatio('1:1');
      expect(await dao.getAspectRatio(), equals('1:1'));
    });
  });

  group('跟随系统主题持久化', () {
    test('getFollowSystem default is false', () async {
      expect(await dao.getFollowSystem(), isFalse);
    });

    test('setFollowSystem(true) persists to DB', () async {
      await dao.setFollowSystem(true);
      expect(await dao.getFollowSystem(), isTrue);
      final rows = await db.query('user_settings', where: 'id = 1');
      expect(rows.first['follow_system'], equals(1));
    });

    test('setFollowSystem(false) after true works', () async {
      await dao.setFollowSystem(true);
      await dao.setFollowSystem(false);
      expect(await dao.getFollowSystem(), isFalse);
    });

    test('getDarkThemeKey default is ink', () async {
      expect(await dao.getDarkThemeKey(), ThemeKey.ink);
    });

    test('setDarkThemeKey persists and getDarkThemeKey returns same value', () async {
      await dao.setDarkThemeKey(ThemeKey.retro);
      expect(await dao.getDarkThemeKey(), ThemeKey.retro);
      final rows = await db.query('user_settings', where: 'id = 1');
      expect(rows.first['theme_key_dark'], equals('retro'));
    });

    test('getLightThemeKey default is warmWhite', () async {
      expect(await dao.getLightThemeKey(), ThemeKey.warmWhite);
    });

    test('setLightThemeKey persists and getLightThemeKey returns same value', () async {
      await dao.setLightThemeKey(ThemeKey.fresh);
      expect(await dao.getLightThemeKey(), ThemeKey.fresh);
      final rows = await db.query('user_settings', where: 'id = 1');
      expect(rows.first['theme_key_light'], equals('fresh'));
    });
  });

  group('capture appearance persistence', () {
    test('getCaptureAppearance default is immersive', () async {
      expect(await dao.getCaptureAppearance(), CaptureAppearance.immersive);
    });

    test('setCaptureAppearance(theme) persists to DB', () async {
      await dao.setCaptureAppearance(CaptureAppearance.theme);
      expect(await dao.getCaptureAppearance(), CaptureAppearance.theme);
      final rows = await db.query('user_settings', where: 'id = 1');
      expect(rows.first['capture_appearance'], equals('theme'));
    });

    test('setCaptureAppearance(immersive) after theme works', () async {
      await dao.setCaptureAppearance(CaptureAppearance.theme);
      await dao.setCaptureAppearance(CaptureAppearance.immersive);
      expect(await dao.getCaptureAppearance(), CaptureAppearance.immersive);
    });

    test('invalid value falls back to immersive', () async {
      await db.update('user_settings',
          {'capture_appearance': 'bogus'}, where: 'id = 1');
      expect(await dao.getCaptureAppearance(), CaptureAppearance.immersive);
    });

    test('无行时回退 immersive', () async {
      await db.delete('user_settings', where: 'id = 1');
      expect(await dao.getCaptureAppearance(), CaptureAppearance.immersive);
    });
  });
}
