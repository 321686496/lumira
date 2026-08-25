import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/templates/data/remote_template_dto.dart';
import 'package:lumira_app_flutter/features/templates/services/template_mapper.dart';

void main() {
  group('TemplateMapper.toRecord', () {
    test('PhotoTemplate → TemplateRecord 完整字段保留', () {
      final tpl = PhotoTemplate(
        meta: TemplateMeta(
          id: 'cafe_portrait',
          name: '咖啡馆人像',
          author: '如画',
          version: '1.0.0',
          category: 'portrait',
          classification: TemplateClassification(
              type: 'portrait', style: 'japanese', method: 'normal'),
          tags: ['咖啡馆', '人像'],
          tagIds: ['t1', 't2'],
          price: 0,
          cover: 'https://example.com/cover.jpg',
          description: '咖啡馆室内自然光人像',
          referenceSource: '样片 EXIF: Unsplash #67890',
        ),
        composition: Composition(
          overlayType: 'center',
          subjectFrame: SubjectFrame(x: 0.3, y: 0.2, w: 0.4, h: 0.6),
          opacity: 0.45,
          aspectRatio: '3:4',
          description: '人物居中',
        ),
        pose: Pose(
          silhouette: SilhouetteResource(type: 'builtin', data: 'sitting-cafe'),
          position: Position(x: 0.5, y: 0.45),
          scale: 1.0,
          rotation: 0,
          description: '坐姿',
        ),
        camera: CameraParams(
          exposureCompensation: 0.3,
          iso: 400,
          shutterSpeed: '1/80',
          whiteBalance: 'cloudy',
          whiteBalanceK: 4800,
          flashMode: 'off',
          focusMode: 'auto',
          lensSuggestion: 'main',
        ),
        sceneGuide: SceneGuide(
          lightDirection: '侧光 45°',
          shootingDistance: '1.5-2.5m',
          background: '咖啡馆室内',
          props: ['咖啡杯', '书本'],
          bestTime: '14:00-17:00',
          tips: ['让模特面朝窗户', '大光圈虚化'],
        ),
        postProcess: PostProcess(
          cropRatio: '3:4',
          color: PostProcessColor(
              brightness: 5,
              contrast: 10,
              saturation: 10,
              temperature: 20,
              tint: -5),
          smoothStrength: 20,
          sharpen: 15,
          vignette: 15,
          grain: 5,
          lut: 'warm_film',
        ),
      );

      final record = TemplateMapper.toRecord(tpl, createdAt: 1700000000000);

      expect(record.id, 'cafe_portrait');
      expect(record.name, '咖啡馆人像');
      expect(record.category, 'portrait');
      expect(record.tags, ['咖啡馆', '人像']);
      expect(record.composition['overlayType'], 'center');
      expect(record.composition['subjectFrame'], isNotNull);
      // Phase 1：toRecord 将 pose 序列化为多姿势数组，首姿势的 silhouette 非空
      expect((record.pose as List).first['silhouette'], isNotNull);
      expect(record.camera['iso'], 400);
      expect(record.sceneGuide['lightDirection'], '侧光 45°');
      expect(record.postProcess['lut'], 'warm_film');
    });
  });

  group('TemplateMapper.metaToRecord (四级别分类保留)', () {
    test('remote meta → TemplateRecord 保留 majorStyle/subStyle', () {
      final meta = RemoteTemplateMetaDto.fromJson({
        'id': 'srv_test',
        'name': '测试模板',
        'author': 'Lumira',
        'version': '1.0.0',
        'category': 'portrait',
        'price': 0,
        'coverUrl': 'https://example.com/cover.jpg',
        'description': '',
        'referenceSource': '',
        'tags': <String>[],
        'tagIds': <String>[],
        'sortOrder': 0,
        'updatedAt': 1700000000000,
        // 后台四级分类：type=一级 / majorStyle=二级 / subStyle=三级 / method=四级
        'classification': {
          'type': 'portrait',
          'majorStyle': 'emotional',
          'subStyle': 'broken_cold',
          'method': 'selfie',
        },
      });

      final record = TemplateMapper.metaToRecord(meta);

      expect(record.category, 'portrait');
      expect(record.classification['type'], 'portrait');
      expect(record.classification['majorStyle'], 'emotional');
      expect(record.classification['subStyle'], 'broken_cold');
      expect(record.classification['method'], 'selfie');
    });
  });

  group('TemplateMapper.toPhotoTemplate', () {
    test('TemplateRecord → PhotoTemplate 往返一致', () {
      final record = TemplateRecord(
        id: 'r1',
        name: '测试',
        author: 'a',
        version: '1.0.0',
        category: 'portrait',
        classification: {'type': 'portrait', 'style': '', 'method': ''},
        tags: ['t1'],
        tagIds: [],
        price: 0,
        cover: '',
        description: '',
        referenceSource: '',
        composition: {
          'overlayType': 'center',
          'opacity': 0.5,
          'aspectRatio': '3:4',
          'description': ''
        },
        pose: {
          'silhouette': {'type': 'builtin', 'data': 'none'},
          'scale': 1.0,
          'rotation': 0,
          'description': ''
        },
        camera: {
          'exposureCompensation': 0.0,
          'iso': 200,
          'shutterSpeed': '1/200',
          'whiteBalance': 'daylight',
          'whiteBalanceK': 5500,
          'flashMode': 'off',
          'focusMode': 'auto',
          'lensSuggestion': 'main'
        },
        sceneGuide: {
          'lightDirection': '',
          'shootingDistance': '',
          'background': '',
          'props': <String>[],
          'bestTime': '',
          'tips': <String>[]
        },
        postProcess: {
          'cropRatio': '3:4',
          'color': {
            'brightness': 0,
            'contrast': 0,
            'saturation': 0,
            'temperature': 0,
            'tint': 0
          },
          'smoothStrength': 0,
          'sharpen': 0,
          'vignette': 0,
          'grain': 0,
          'lut': 'none'
        },
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
        isBuiltin: false,
        isRecommended: false,
      );

      final tpl = TemplateMapper.toPhotoTemplate(record);
      expect(tpl.meta.id, 'r1');
      expect(tpl.meta.category, 'portrait');
      expect(tpl.composition.overlayType, 'center');
      expect(tpl.camera.iso, 200);
      expect(tpl.postProcess.lut, 'none');
    });
  });

  group('TemplateMapper.silhouetteToJson / silhouetteFromJson', () {
    test('builtin 剪影自包含（仅存 key）', () {
      final s = SilhouetteResource(type: 'builtin', data: 'standing-profile');
      final json = TemplateMapper.silhouetteToJson(s);
      expect(json['type'], 'builtin');
      expect(json['data'], 'standing-profile');

      final restored = TemplateMapper.silhouetteFromJson(json);
      expect(restored.type, 'builtin');
      expect(restored.data, 'standing-profile');
    });

    test('image 剪影自包含（存 base64 data URL）', () {
      final s = SilhouetteResource(
        type: 'image',
        data: 'data:image/png;base64,iVBORw0KGgo=',
        filename: 'sil.png',
        sizeKB: 12,
      );
      final json = TemplateMapper.silhouetteToJson(s);
      expect(json['type'], 'image');
      expect(json['data'], 'data:image/png;base64,iVBORw0KGgo=');
      expect(json['filename'], 'sil.png');

      final restored = TemplateMapper.silhouetteFromJson(json);
      expect(restored.type, 'image');
      expect(restored.data, 'data:image/png;base64,iVBORw0KGgo=');
    });

    test('svg 剪影自包含（存 inline SVG）', () {
      final s = SilhouetteResource(type: 'svg', data: '<svg></svg>');
      final json = TemplateMapper.silhouetteToJson(s);
      expect(json['type'], 'svg');
      expect(json['data'], '<svg></svg>');
    });
  });
}
