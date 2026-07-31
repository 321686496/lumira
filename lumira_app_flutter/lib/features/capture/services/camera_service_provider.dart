import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'camera_service.dart';
import 'camerawesome_camera_service.dart';
import 'camerawesome_delegate.dart';

final cameraServiceProvider = Provider<CameraService>((ref) {
  return CamerawesomeCameraService(CamerawesomeDelegate.forCurrentPlatform());
});
