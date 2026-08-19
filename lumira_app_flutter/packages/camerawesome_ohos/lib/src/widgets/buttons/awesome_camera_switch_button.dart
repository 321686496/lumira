import 'package:camerawesome_ohos/src/orchestrator/states/camera_state.dart';
import 'package:camerawesome_ohos/src/widgets/utils/awesome_circle_icon.dart';
import 'package:camerawesome_ohos/src/widgets/utils/awesome_oriented_widget.dart';
import 'package:camerawesome_ohos/src/widgets/utils/awesome_theme.dart';
import 'package:flutter/material.dart';
import 'package:camerawesome_ohos/camerawesome_plugin.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';

class AwesomeCameraSwitchButton extends StatefulWidget {
  final CameraState state;
  final AwesomeTheme? theme;
  final Widget Function() iconBuilder;
  final void Function(CameraState) onSwitchTap;

  AwesomeCameraSwitchButton({
    super.key,
    required this.state,
    this.theme,
    Widget Function()? iconBuilder,
    void Function(CameraState)? onSwitchTap,
    double scale = 1.3,
  })  : iconBuilder = iconBuilder ??
            (() {
              return AwesomeCircleWidget.icon(
                theme: theme,
                icon: Icons.cameraswitch,
                scale: scale,
              );
            }),
        onSwitchTap = onSwitchTap ?? ((state) => state.switchCameraSensor());

  @override
  State<AwesomeCameraSwitchButton> createState() =>
      _AwesomeCameraSwitchButtonState();
}

class _AwesomeCameraSwitchButtonState extends State<AwesomeCameraSwitchButton> {
  late StreamSubscription<Sensors> _cameraDeviceSubscription;

  @override
  void initState() {
    super.initState();
    // 订阅摄像头切换事件
    _cameraDeviceSubscription =
        CamerawesomePlugin.listenCameraDeviceChange()!.listen((sensor) {
      // 触发 onSwitchTap 回调
      widget.onSwitchTap(widget.state);
    });
  }

  @override
  void dispose() {
    _cameraDeviceSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? AwesomeThemeProvider.of(context).theme;

    return AwesomeOrientedWidget(
      rotateWithDevice: theme.buttonTheme.rotateWithCamera,
      child: theme.buttonTheme.buttonBuilder(
        widget.iconBuilder(),
        () => widget.onSwitchTap(widget.state),
      ),
    );
  }
}
