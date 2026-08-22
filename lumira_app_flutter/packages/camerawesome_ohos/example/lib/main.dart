import 'package:open_file_ohos/open_file_ohos.dart';
import 'package:camera_app/utils/file_utils.dart';
import 'package:camerawesome_ohos/camerawesome_plugin.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const CameraAwesomeApp());
}

class CameraAwesomeApp extends StatelessWidget {
  const CameraAwesomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'camerAwesome',
      home: CameraPage(),
    );
  }
}

class CameraPage extends StatelessWidget {
  const CameraPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: CameraAwesomeBuilder.awesome(
          saveConfig: SaveConfig.photoAndVideo(
            photoPathBuilder: () => path(CaptureMode.photo),
            videoPathBuilder: () => path(CaptureMode.video),
            initialCaptureMode: CaptureMode.photo,
          ),
          enablePhysicalButton: true,
          filter: AwesomeFilter.None,
          flashMode: FlashMode.auto,
          aspectRatio: CameraAspectRatios.ratio_16_9,
          previewFit: CameraPreviewFit.fitWidth,
          mirrorFrontCamera: true,
          previewAlignment: Alignment.bottomLeft,
          onMediaTap: (mediaCapture) {
            OpenFile.open(mediaCapture.filePath);
          },
        ),
      ),
    );
  }
}
