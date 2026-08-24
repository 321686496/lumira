import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/services/camera_service.dart';
import 'package:lumira_app_flutter/features/capture/services/camerawesome_camera_service.dart';
import 'package:lumira_app_flutter/features/capture/services/camerawesome_delegate.dart';

void main() {
  group('CamerawesomeCameraService readyStream', () {
    test(
        'facing 变化（摄像头切换）时 readyStream 必须发出 false，'
        '供上层阻止切换期间再次切换，避免原生相机 init/start 重叠导致黑屏', () async {
      final service = CamerawesomeCameraService(CamerawesomeDelegate.ios);
      final events = <bool>[];
      final sub = service.readyStream.listen(events.add);
      addTearDown(() => sub.cancel());

      // 首次 build（facing 从 null → 'back'），应发出 false（相机尚未就绪）
      service.buildPreview(
        config: const CameraPreviewConfig(facing: 'back'),
      );
      // 摄像头切换（back → front），必须再次发出 false，
      // 表示"上一次切换尚未就绪，禁止再次切换"
      service.buildPreview(
        config: const CameraPreviewConfig(facing: 'front'),
      );

      // 等待流事件投递
      await Future<void>.delayed(Duration.zero);

      // 两次 facing 变化（null→back、back→front）都应产生 false
      final falseCount =
          events.where((e) => e == false).length;
      expect(falseCount, greaterThanOrEqualTo(2),
          reason: 'facing 变化时必须发出 false，通知上层切换进行中');

      // 相同 facing 的普通重建（比例/参数调整等）不应重复发出 false，
      // 否则会误锁切换按钮。这里再以相同 facing 重建一次：
      service.buildPreview(
        config: const CameraPreviewConfig(facing: 'front'),
      );
      await Future<void>.delayed(Duration.zero);
      final falseCountAfter = events.where((e) => e == false).length;
      expect(falseCountAfter, falseCount,
          reason: '相同 facing 的重建不应再次发出 false');
    });
  });
}
