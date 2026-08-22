import 'package:camerawesome_ohos/pigeon.dart';
import 'package:camerawesome_ohos/src/orchestrator/models/sensors.dart';

class CameraCharacteristics {
  const CameraCharacteristics._();

  static Future<bool> isVideoRecordingAndImageAnalysisSupported(
    Sensors sensor,
  ) {
    return CameraInterface()
        .isVideoRecordingAndImageAnalysisSupported(sensor.name.toUpperCase());
  }
}
