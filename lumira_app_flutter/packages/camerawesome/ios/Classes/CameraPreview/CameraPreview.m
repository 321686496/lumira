//
//  CameraPreview.m
//  camerawesome
//
//  Created by Dimitri Dessus on 23/07/2020.
//

#import "CameraPreview.h"
#import <ImageIO/ImageIO.h>
#import <CoreGraphics/CoreGraphics.h>

@implementation CameraPreview {
  dispatch_queue_t _dispatchQueue;
}

- (instancetype)initWithCameraSensor:(CameraSensor)sensor
                        streamImages:(BOOL)streamImages
                   mirrorFrontCamera:(BOOL)mirrorFrontCamera
                enablePhysicalButton:(BOOL)enablePhysicalButton
                     aspectRatioMode:(AspectRatio)aspectRatioMode
                         captureMode:(CaptureModes)captureMode
                          completion:(nonnull void (^)(NSNumber * _Nullable, FlutterError * _Nullable))completion
                       dispatchQueue:(dispatch_queue_t)dispatchQueue {
  self = [super init];
  
  _completion = completion;
  _dispatchQueue = dispatchQueue;
  
  // Creating capture session
  _captureSession = [[AVCaptureSession alloc] init];
  _captureVideoOutput = [AVCaptureVideoDataOutput new];
  _captureVideoOutput.videoSettings = @{(NSString*)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
  [_captureVideoOutput setAlwaysDiscardsLateVideoFrames:YES];
  [_captureVideoOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
  [_captureSession addOutputWithNoConnections:_captureVideoOutput];
  
  _cameraSensor = sensor;
  _aspectRatio = aspectRatioMode;
  _mirrorFrontCamera = mirrorFrontCamera;
  
  [self initCameraPreview:sensor];
  
  [_captureConnection setAutomaticallyAdjustsVideoMirroring:NO];
  
  _captureMode = captureMode;
  
  // By default enable auto flash mode
  _flashMode = AVCaptureFlashModeOff;
  _torchMode = AVCaptureTorchModeOff;
  
  _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_captureSession];
  _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
  
  // Controllers init
  _videoController = [[VideoController alloc] init];
  _imageStreamController = [[ImageStreamController alloc] initWithStreamImages:streamImages];
  _motionController = [[MotionController alloc] init];
  _locationController = [[LocationController alloc] init];
  _physicalButtonController = [[PhysicalButtonController alloc] init];
  
  [_motionController startMotionDetection];
  
  if (enablePhysicalButton) {
    [_physicalButtonController startListening];
  }
  
  [self setBestPreviewQuality];
  
  return self;
}

- (void)setAspectRatio:(AspectRatio)ratio {
  _aspectRatio = ratio;
}

/// Set image stream Flutter sink
- (void)setImageStreamEvent:(FlutterEventSink)imageStreamEventSink {
  if (_imageStreamController != nil) {
    [_imageStreamController setImageStreamEventSink:imageStreamEventSink];
  }
}

/// Set orientation stream Flutter sink
- (void)setOrientationEventSink:(FlutterEventSink)orientationEventSink {
  if (_motionController != nil) {
    [_motionController setOrientationEventSink:orientationEventSink];
  }
}

/// Set physical button Flutter sink
- (void)setPhysicalButtonEventSink:(FlutterEventSink)physicalButtonEventSink {
  if (_physicalButtonController != nil) {
    [_physicalButtonController setPhysicalButtonEventSink:physicalButtonEventSink];
  }
}

/// Assign the default preview qualities
- (void)setBestPreviewQuality {
  // WYSIWYG fix (iOS): keep the photo session preset (4:3 full sensor) so the
  // preview stream has the same aspect ratio and field of view as the captured
  // photo. Upstream switches to a 16:9 video preset here, which makes the
  // viewfinder show a horizontally-cropped 16:9 stream that can never match the
  // 4:3 photo — the same approach as the camerawesome_ohos fork, which picks a
  // preview profile matching the photo aspect ratio.
  if ([_captureSession canSetSessionPreset:AVCaptureSessionPresetPhoto]) {
    [_captureSession setSessionPreset:AVCaptureSessionPresetPhoto];
    _currentPresset = AVCaptureSessionPresetPhoto;
    CMVideoDimensions dimensions =
        CMVideoFormatDescriptionGetDimensions(_captureDevice.activeFormat.formatDescription);
    _currentPreviewSize = CGSizeMake(dimensions.width, dimensions.height);
    [_videoController setPreviewSize:_currentPreviewSize];
    return;
  }

  // Fallback for devices that do not support the photo preset.
  NSArray *qualities = [CameraQualities captureFormatsForDevice:_captureDevice];
  PreviewSize *firstPreviewSize = [qualities count] > 0 ? qualities.lastObject : [PreviewSize makeWithWidth:@3840 height:@2160];
  
  CGSize firstSize = CGSizeMake([firstPreviewSize.width floatValue], [firstPreviewSize.height floatValue]);
  [self setCameraPresset:firstSize];
}

/// Save exif preferences when taking picture
- (void)setExifPreferencesGPSLocation:(bool)gpsLocation completion:(void(^)(NSNumber *_Nullable, FlutterError *_Nullable))completion {
  _saveGPSLocation = gpsLocation;
  
  if (_saveGPSLocation) {
    [_locationController requestWhenInUseAuthorizationOnGranted:^{
      completion(@(YES), nil);
    } declined:^{
      completion(@(NO), nil);
    }];
  } else {
    completion(@(YES), nil);
  }
}

/// Init camera preview with Front or Rear sensor
- (void)initCameraPreview:(CameraSensor)sensor {
  // Here we set a preset which wont crash the device before switching to front or back
  [_captureSession setSessionPreset:AVCaptureSessionPresetPhoto];
  
  NSError *error;
  _captureDevice = [AVCaptureDevice deviceWithUniqueID:[self selectAvailableCamera:sensor]];
  _captureVideoInput = [AVCaptureDeviceInput deviceInputWithDevice:_captureDevice error:&error];
  
  if (error != nil) {
    _completion(nil, [FlutterError errorWithCode:@"CANNOT_OPEN_CAMERA" message:@"can't attach device to input" details:[error localizedDescription]]);
    return;
  }
  
  // Create connection
  _captureConnection = [AVCaptureConnection connectionWithInputPorts:_captureVideoInput.ports
                                                              output:_captureVideoOutput];
  
  // Attaching to session
  [_captureSession addInputWithNoConnections:_captureVideoInput];
  [_captureSession addConnection:_captureConnection];
  
  // Creating photo output
  _capturePhotoOutput = [AVCapturePhotoOutput new];
  [_capturePhotoOutput setHighResolutionCaptureEnabled:YES];
  [_captureSession addOutput:_capturePhotoOutput];
  
  // Mirror the preview only on portrait mode
  [_captureConnection setAutomaticallyAdjustsVideoMirroring:NO];
  [_captureConnection setVideoMirrored:(_cameraSensor == Front)];
  [_captureConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
}

- (void)dealloc {
  if (_latestPixelBuffer) {
    CFRelease(_latestPixelBuffer);
  }
  [_motionController startMotionDetection];
}

/// Set camera preview size
- (void)setCameraPresset:(CGSize)currentPreviewSize {
  CGSize preview = currentPreviewSize;
  if (_imageStreamController.streamImages) {
    // force preview to HD for image stream
    preview = CGSizeMake(720, 1280);
  }
  
  NSString *presetSelected;
  if (!CGSizeEqualToSize(CGSizeZero, preview)) {
    // Try to get the quality requested
    presetSelected = [CameraQualities selectVideoCapturePresset:preview session:_captureSession device:_captureDevice];
  } else {
    // Compute the best quality supported by the camera device
    presetSelected = [CameraQualities selectVideoCapturePresset:_captureSession device:_captureDevice];
  }
  [_captureSession setSessionPreset:presetSelected];
  _currentPresset = presetSelected;
  
  // Get preview size according to presset selected
  _currentPreviewSize = [CameraQualities getSizeForPresset:presetSelected];
  
  [_videoController setPreviewSize:_currentPreviewSize];
}

/// Get current video prewiew size
- (CGSize)getEffectivPreviewSize {
  return _currentPreviewSize;
}

// Get max zoom level
- (CGFloat)getMaxZoom {
  CGFloat maxZoom = _captureDevice.activeFormat.videoMaxZoomFactor;
  // Not sure why on iPhone 14 Pro, zoom at 90 not working, so let's block to 50 which is very high
  return maxZoom > 50.0 ? 50.0 : maxZoom;
}

/// Dispose camera inputs & outputs
- (void)dispose {
  [self stop];
  [self.physicalButtonController stopListening];
  
  for (AVCaptureInput *input in [_captureSession inputs]) {
    [_captureSession removeInput:input];
  }
  for (AVCaptureOutput *output in [_captureSession outputs]) {
    [_captureSession removeOutput:output];
  }
}

/// Set preview size resolution
- (void)setPreviewSize:(CGSize)previewSize error:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
  if (_videoController.isRecording) {
    *error = [FlutterError errorWithCode:@"PREVIEW_SIZE" message:@"impossible to change preview size, video already recording" details:@""];
    return;
  }
  
  [self setCameraPresset:previewSize];
}

/// Start camera preview
- (void)start {
  [_captureSession startRunning];
}

/// Stop camera preview
- (void)stop {
  // 回到连续自动白平衡，避免异常拍摄残留的 Locked 旧增益影响下次预览
  [self restoreAutoWhiteBalance];
  [_captureSession stopRunning];
}

/// Set sensor between Front & Rear camera
- (void)setSensor:(CameraSensor)sensor deviceId:(NSString *)captureDeviceId {
  // First remove all input & output
  [_captureSession beginConfiguration];
  
  // Only remove camera channel but keep audio
  for (AVCaptureInput *input in [_captureSession inputs]) {
    for (AVCaptureInputPort *port in input.ports) {
      if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
        [_captureSession removeInput:input];
        break;
      }
    }
  }
  [_videoController setAudioIsDisconnected:YES];
  
  [_captureSession removeOutput:_capturePhotoOutput];
  [_captureSession removeConnection:_captureConnection];
  
  _cameraSensor = sensor;
  _captureDeviceId = captureDeviceId;
  
  // Init the camera preview with the selected sensor
  [self initCameraPreview:sensor];
  
  [self setBestPreviewQuality];
  
  [_captureSession commitConfiguration];
}

/// Set zoom level
- (void)setZoom:(float)value error:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
  CGFloat maxZoom = [self getMaxZoom];
  CGFloat scaledZoom = value * (maxZoom - 1.0f) + 1.0f;
  
  NSError *zoomError;
  if ([_captureDevice lockForConfiguration:&zoomError]) {
    _captureDevice.videoZoomFactor = scaledZoom;
    [_captureDevice unlockForConfiguration];
  } else {
    *error = [FlutterError errorWithCode:@"ZOOM_NOT_SET" message:@"can't set the zoom value" details:[zoomError localizedDescription]];
  }
}

- (void)setBrightness:(NSNumber *)brightness error:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
  NSError *brightnessError = nil;
  if ([_captureDevice lockForConfiguration:&brightnessError]) {
    AVCaptureExposureMode exposureMode = AVCaptureExposureModeContinuousAutoExposure;
    if ([_captureDevice isExposureModeSupported:exposureMode]) {
      [_captureDevice setExposureMode:exposureMode];
    }
    
    // brightness∈[0,1] 编码 EV∈[-3,+3]（0.5=0EV，与应用侧滑块一致）。
    // exposureTargetBias 单位即 EV，直接按 EV 解码以匹配原相机的曝光档位与步进，
    // 避免把 [0,1] 线性映射到设备满量程（±8EV）导致小步进被放大数倍。
    CGFloat minExposureTargetBias = _captureDevice.minExposureTargetBias;
    CGFloat maxExposureTargetBias = _captureDevice.maxExposureTargetBias;

    CGFloat ev = ((CGFloat)[brightness floatValue] - 0.5f) * 6.0f;
    CGFloat exposureTargetBias = MAX(minExposureTargetBias, MIN(maxExposureTargetBias, ev));
    
    [_captureDevice setExposureTargetBias:exposureTargetBias completionHandler:nil];
    [_captureDevice unlockForConfiguration];
  } else {
    *error = [FlutterError errorWithCode:@"BRIGHTNESS_NOT_SET" message:@"can't set the brightness value" details:[brightnessError localizedDescription]];
  }
}

// 逐通道钳制增益到 [1.0, maxWhiteBalanceGain]。
// Apple 文档警告：部分温度/色度组合会得到越界的 RGB 增益，直接传给
// setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains: 会造成 NSException 崩溃。
static AVCaptureWhiteBalanceGains ClampWhiteBalanceGains(AVCaptureWhiteBalanceGains gains, float maxGain) {
  gains.redGain   = MAX(1.0f, MIN(maxGain, gains.redGain));
  gains.greenGain = MAX(1.0f, MIN(maxGain, gains.greenGain));
  gains.blueGain  = MAX(1.0f, MIN(maxGain, gains.blueGain));
  return gains;
}

- (void)setWhiteBalance:(NSString *)mode temperatureK:(NSNumber *_Nullable)k
                  error:(FlutterError *_Nullable __autoreleasing *_Nonnull)error {
  NSError *e = nil;
  if (![_captureDevice lockForConfiguration:&e]) {
    *error = [FlutterError errorWithCode:@"WB_LOCK_ERR" message:[e localizedDescription] details:nil];
    return;
  }

  if (k != nil) {
    // 手动色温：用目标 K 得到 gains，锁定（渐进钳制避免越界崩溃）
    AVCaptureWhiteBalanceTemperatureAndTintValues tt = { .temperature = [k floatValue], .tint = 0.0f };
    AVCaptureWhiteBalanceGains gains =
        [_captureDevice deviceWhiteBalanceGainsForTemperatureAndTintValues:tt];
    gains = ClampWhiteBalanceGains(gains, _captureDevice.maxWhiteBalanceGain);
    if ([_captureDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeLocked]) {
      [_captureDevice setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains:gains completionHandler:nil];
    } else {
      *error = [FlutterError errorWithCode:@"WB_MODE_UNSUPPORTED" message:@"locked white balance not supported" details:nil];
    }
  } else if ([mode isEqualToString:@"auto"]) {
    // 恢复自动（连续自动白平衡）
    AVCaptureWhiteBalanceMode wbMode = AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
    if ([_captureDevice isWhiteBalanceModeSupported:wbMode]) _captureDevice.whiteBalanceMode = wbMode;
    else *error = [FlutterError errorWithCode:@"WB_MODE_UNSUPPORTED" message:@"continuous auto white balance not supported" details:nil];
  } else {
    // 模式预设：映射到目标 K 再锁定（渐进钳制避免越界崩溃）
    float presetK = 5500.0f;
    if      ([mode isEqualToString:@"daylight"])     presetK = 5500.0f;
    else if ([mode isEqualToString:@"cloudy"])       presetK = 6500.0f;
    else if ([mode isEqualToString:@"fluorescent"])  presetK = 4200.0f;
    else if ([mode isEqualToString:@"incandescent"]) presetK = 3000.0f;
    AVCaptureWhiteBalanceTemperatureAndTintValues tt = { .temperature = presetK, .tint = 0.0f };
    AVCaptureWhiteBalanceGains gains =
        [_captureDevice deviceWhiteBalanceGainsForTemperatureAndTintValues:tt];
    gains = ClampWhiteBalanceGains(gains, _captureDevice.maxWhiteBalanceGain);
    if ([_captureDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeLocked]) {
      [_captureDevice setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains:gains completionHandler:nil];
    } else {
      *error = [FlutterError errorWithCode:@"WB_MODE_UNSUPPORTED" message:@"locked white balance not supported" details:nil];
    }
  }

  [_captureDevice unlockForConfiguration];
}

/// 拍照前把设备白平衡锁定到「当前取景器白平衡增益」。
///
/// 背景：iOS 的 AVCapturePhotoOutput（快照）与 AVCaptureVideoPreviewLayer（取景器）
/// 走两套独立的白平衡评估引擎。ContinuousAutoWhiteBalance 状态下，快照在按下快门瞬间
/// 重新评估白平衡，结果往往比取景器当前画面更暖（偏黄），导致「取景器正常、成片偏黄」。
///
/// 修复思路：拍照前读取 device.deviceWhiteBalanceGains（实时预览正在应用的白平衡增益），
/// 切换到 Locked 模式并冻结为该增益，此时快照会复用取景器的白平衡 → 成片与取景器一致；
/// 拍摄完成后再由 restoreAutoWhiteBalance 恢复连续自动白平衡。
///
/// 每次一律重新采样当前增益并锁定（不做模式守卫）：用户手动设过色温时
/// deviceWhiteBalanceGains 就是其手动增益，重锁到同一值等效无操作，误伤为零；
/// 而若上一帧拍摄异常未能恢复（残留 Locked 旧增益），此处也能用实时增益覆盖，避免陈旧值。
- (void)lockWhiteBalanceToCurrentPreview {
  if (_captureDevice == nil) return;
  NSError *e = nil;
  if (![_captureDevice lockForConfiguration:&e]) return;
  AVCaptureWhiteBalanceGains gains = _captureDevice.deviceWhiteBalanceGains;
  gains = ClampWhiteBalanceGains(gains, _captureDevice.maxWhiteBalanceGain);
  if ([_captureDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeLocked]) {
    [_captureDevice setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains:gains completionHandler:nil];
  }
  [_captureDevice unlockForConfiguration];
}

/// 拍照完成后恢复连续自动白平衡。
- (void)restoreAutoWhiteBalance {
  if (_captureDevice == nil) return;
  NSError *e = nil;
  if (![_captureDevice lockForConfiguration:&e]) return;
  AVCaptureWhiteBalanceMode mode = AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
  if ([_captureDevice isWhiteBalanceModeSupported:mode]) {
    _captureDevice.whiteBalanceMode = mode;
  }
  [_captureDevice unlockForConfiguration];
}

- (void)setMirrorFrontCamera:(bool)value error:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
  _mirrorFrontCamera = value;
}

/// Set flash mode
- (void)setFlashMode:(CameraFlashMode)flashMode error:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
  if (![_captureDevice hasFlash]) {
    *error = [FlutterError errorWithCode:@"FLASH_UNSUPPORTED" message:@"flash is not supported on this device" details:@""];
    return;
  }
  
  if (_cameraSensor == Front) {
    *error = [FlutterError errorWithCode:@"FLASH_UNSUPPORTED" message:@"can't set flash for portrait mode" details:@""];
    return;
  }
  
  NSError *lockError;
  [_captureDevice lockForConfiguration:&lockError];
  if (lockError != nil) {
    *error = [FlutterError errorWithCode:@"FLASH_ERROR" message:@"impossible to change configuration" details:@""];
    return;
  }
  
  switch (flashMode) {
    case None:
      _torchMode = AVCaptureTorchModeOff;
      _flashMode = AVCaptureFlashModeOff;
      break;
    case On:
      _torchMode = AVCaptureTorchModeOff;
      _flashMode = AVCaptureFlashModeOn;
      break;
    case Auto:
      _torchMode = AVCaptureTorchModeAuto;
      _flashMode = AVCaptureFlashModeAuto;
      break;
    case Always:
      _torchMode = AVCaptureTorchModeOn;
      _flashMode = AVCaptureFlashModeOn;
      break;
    default:
      _torchMode = AVCaptureTorchModeAuto;
      _flashMode = AVCaptureFlashModeAuto;
      break;
  }
  [_captureDevice setTorchMode:_torchMode];
  [_captureDevice unlockForConfiguration];
}

/// Trigger focus on device at the specific point of the preview
/// 使用 AVCaptureFocusModeAutoFocus（单次扫描后锁定到触点），这样点击取景器
/// 时会像 iPhone 原生相机一样触发一次可见的对焦扫动；若直接设
/// ContinuousAutoFocus 且设备本就处于连续对焦模式，则不会触发任何对焦动作
/// （表现为「黄色对焦框出现但画面没有任何对焦效果」）。
- (void)focusOnPoint:(CGPoint)position preview:(CGSize)preview error:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
  NSError *lockError;
  if ([_captureDevice isFocusModeSupported:AVCaptureFocusModeAutoFocus] && [_captureDevice isFocusPointOfInterestSupported]) {
    if ([_captureDevice lockForConfiguration:&lockError]) {
      if (lockError != nil) {
        *error = [FlutterError errorWithCode:@"FOCUS_ERROR" message:@"impossible to set focus point" details:@""];
        return;
      }
      
      [_captureDevice setFocusPointOfInterest:position];
      [_captureDevice setFocusMode:AVCaptureFocusModeAutoFocus];
      
      [_captureDevice unlockForConfiguration];
    }
  }
}

/// 长按锁定 AE/AF：position 为归一化 [0,1] 坐标（与 focusOnPoint 一致）。
/// locked=YES：曝光与对焦均锁定在触点；locked=NO：恢复连续自动对焦/曝光。
- (void)setFocusAndExposureLock:(BOOL)locked position:(CGPoint)position preview:(CGSize)preview error:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
  NSError *lockError;
  if (locked) {
    // —— 曝光锁定 ——
    if ([_captureDevice isExposurePointOfInterestSupported] &&
        [_captureDevice isExposureModeSupported:AVCaptureExposureModeLocked]) {
      if ([_captureDevice lockForConfiguration:&lockError]) {
        [_captureDevice setExposurePointOfInterest:position];
        [_captureDevice setExposureMode:AVCaptureExposureModeLocked];
        [_captureDevice unlockForConfiguration];
      }
    }
    // —— 对焦锁定：先触发一次自动对焦到触点，再锁定到当前镜头位置 ——
    if ([_captureDevice isFocusPointOfInterestSupported] &&
        [_captureDevice isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
      if ([_captureDevice lockForConfiguration:&lockError]) {
        [_captureDevice setFocusPointOfInterest:position];
        [_captureDevice setFocusMode:AVCaptureFocusModeAutoFocus];
        [_captureDevice unlockForConfiguration];
      }
      if ([_captureDevice isFocusModeSupported:AVCaptureFocusModeLocked]) {
        CGFloat currentLens = _captureDevice.lensPosition;
        [_captureDevice setFocusModeLockedWithLensPosition:currentLens completionHandler:nil];
      }
    }
  } else {
    // —— 解锁：恢复连续自动 ——
    if ([_captureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
      if ([_captureDevice lockForConfiguration:&lockError]) {
        [_captureDevice setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
        [_captureDevice unlockForConfiguration];
      }
    }
    if ([_captureDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
      if ([_captureDevice lockForConfiguration:&lockError]) {
        [_captureDevice setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
        [_captureDevice unlockForConfiguration];
      }
    }
  }
}

- (void)receivedImageFromStream {
  [self.imageStreamController receivedImageFromStream];
}

/// Get the first available camera on device (front or rear)
- (NSString *)selectAvailableCamera:(CameraSensor)sensor {
  if (_captureDeviceId != nil) {
    return _captureDeviceId;
  }
  
  // TODO: add dual & triple camera
  NSArray<AVCaptureDevice *> *devices = [[NSArray alloc] init];
  AVCaptureDeviceDiscoverySession *discoverySession = [AVCaptureDeviceDiscoverySession
                                                       discoverySessionWithDeviceTypes:@[ AVCaptureDeviceTypeBuiltInWideAngleCamera, ]
                                                       mediaType:AVMediaTypeVideo
                                                       position:AVCaptureDevicePositionUnspecified];
  devices = discoverySession.devices;
  
  NSInteger cameraType = (sensor == Front) ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
  for (AVCaptureDevice *device in devices) {
    if ([device position] == cameraType) {
      return [device uniqueID];
    }
  }
  return nil;
}

- (NSArray *)getSensors:(AVCaptureDevicePosition)position {
  NSMutableArray *sensors = [NSMutableArray new];
  
  NSArray *sensorsType = @[AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeBuiltInTelephotoCamera, AVCaptureDeviceTypeBuiltInUltraWideCamera, AVCaptureDeviceTypeBuiltInTrueDepthCamera];
  
  AVCaptureDeviceDiscoverySession *discoverySession = [AVCaptureDeviceDiscoverySession
                                                       discoverySessionWithDeviceTypes:sensorsType
                                                       mediaType:AVMediaTypeVideo
                                                       position:AVCaptureDevicePositionUnspecified];
  
  for (AVCaptureDevice *device in discoverySession.devices) {
    PigeonSensorType type;
    if (device.deviceType == AVCaptureDeviceTypeBuiltInTelephotoCamera) {
      type = PigeonSensorTypeTelephoto;
    } else if (device.deviceType == AVCaptureDeviceTypeBuiltInUltraWideCamera) {
      type = PigeonSensorTypeUltraWideAngle;
    } else if (device.deviceType == AVCaptureDeviceTypeBuiltInTrueDepthCamera) {
      type = PigeonSensorTypeTrueDepth;
    } else if (device.deviceType == AVCaptureDeviceTypeBuiltInWideAngleCamera) {
      type = PigeonSensorTypeWideAngle;
    } else {
      type = PigeonSensorTypeUnknown;
    }
    
    PigeonSensorTypeDevice *sensorType = [PigeonSensorTypeDevice makeWithSensorType:type name:device.localizedName iso:[NSNumber numberWithFloat:device.ISO] flashAvailable:[NSNumber numberWithBool:device.flashAvailable] uid:device.uniqueID];
    
    if (device.position == position) {
      [sensors addObject:sensorType];
    }
  }
  
  return sensors;
}

/// Set capture mode between Photo & Video mode
- (void)setCaptureMode:(CaptureModes)captureMode error:(FlutterError * _Nullable __autoreleasing * _Nonnull)error {
  if (_videoController.isRecording) {
    *error = [FlutterError errorWithCode:@"CAPTURE_MODE" message:@"impossible to change capture mode, video already recording" details:@""];
    return;
  }
  
  _captureMode = captureMode;
  
  if (captureMode == Video) {
    [self setUpCaptureSessionForAudioError:^(NSError *audioError) {
      *error = [FlutterError errorWithCode:@"VIDEO_ERROR" message:@"error when trying to setup audio" details:[audioError localizedDescription]];
    }];
  }
}

- (void)refresh {
  if ([_captureSession isRunning]) {
    [self stop];
  }
  [self start];
}

# pragma mark - Camera picture

/// CGDataProvider 释放回调：释放直出路径 malloc 的像素拷贝。
static void _freeCapturedFrameData(void *info, const void *data, size_t size) {
  free((void *)data);
}

/// 【所见即所得直出】抓取取景器当前帧（AVCaptureVideoDataOutput 的 _latestPixelBuffer）
/// 原样编码为 JPEG 写盘，替代 AVCapturePhotoOutput。
///
/// 根因（2026-08-28 诊断，debugphotoyellow/ 实测）：photoOutput 的照片 ISP
/// （Smart HDR/Deep Fusion）产出比 video 管线偏暖的内容（全图 R-B≈+23，暖色内容集中、
/// 灰区近中性），锁白平衡 / P3→sRGB 色域转换（ImageCms 权威验证）/ 灰区自适应白平衡
/// 均无法消除。取景器渲染的正是这个 video 帧（FlutterTexture 路径），直出它 =
/// 成片与取景器同源同色、100% 所见即所得（与 OHOS「原始帧直出」同思路）。
///
/// 帧像素为 sensor-native 横屏（与 photoOutput JPEG 一致），EXIF orientation 与
/// CameraPictureController.getJpegOrientation 同映射，Dart 后处理管线无需改动。
///
/// 返回 NO 表示不满足直出条件（无帧/尺寸异常），调用方回退 photoOutput 路径；
/// 返回 YES 表示已受理，编码结果经 completion 回调（主线程）。
///
/// 并发模型（takePhotoPath 在插件串行队列、videoDataOutput delegate 在主队列、
/// copyPixelBuffer 在光栅线程，三者并发访问 _latestPixelBuffer）：
/// 不能「load 后再 retain」——load 与 retain 之间 delegate 可能已存新帧并 release
/// 旧帧（UAF 崩溃）。必须先用 CAS 把帧原子换出（取得所有权），retain 一份供后台
/// 编码持有，再原子放回存储；若放回时 delegate 已存入更新帧则保留新帧不放回。
/// memcpy + JPEG 编码（100-300ms）dispatch 到后台，避免阻塞取景器渲染。
- (BOOL)captureVideoFrameToJpegAtPath:(NSString *)path
                            completion:(nonnull void (^)(BOOL ok))completion {
  CVPixelBufferRef buf = atomic_load(&_latestPixelBuffer);
  while (buf != NULL &&
         !atomic_compare_exchange_strong(&_latestPixelBuffer, &buf, NULL)) {
    // CAS 失败时 buf 已被更新为最新存储值，循环自动重试
  }
  if (buf == NULL) return NO;
  const int w = (int)CVPixelBufferGetWidth(buf);
  const int h = (int)CVPixelBufferGetHeight(buf);
  if (w <= 0 || h <= 0) {
    CFRelease(buf);
    return NO;
  }
  CFRetain(buf);
  CVPixelBufferRef expected = NULL;
  if (!atomic_compare_exchange_strong(&_latestPixelBuffer, &expected, buf)) {
    // 持有期间 delegate 已存入更新的帧：保留新帧，只释放取出的一次所有权
    CFRelease(buf);
  }
  // EXIF orientation 依赖设备方向属性，派发后台前在当前线程算好。
  const NSInteger exifOrientation = [self exifOrientationForVideoFrame];

  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    CVPixelBufferLockBaseAddress(buf, kCVPixelBufferLock_ReadOnly);
    void *base = CVPixelBufferGetBaseAddress(buf);
    const size_t rowBytes = CVPixelBufferGetBytesPerRow(buf);
    BOOL ok = NO;
    if (base != NULL && rowBytes >= (size_t)w * 4) {
      // 锁窗口内只做 memcpy（~10ms）；编码在拷贝上进行，
      // 避免长时间锁帧阻塞取景器渲染（Flutter copyPixelBuffer 也读这个 buffer）。
      const size_t dataLen = rowBytes * (size_t)h;
      void *pixels = malloc(dataLen);
      if (pixels != NULL) {
        memcpy(pixels, base, dataLen);
        CVPixelBufferUnlockBaseAddress(buf, kCVPixelBufferLock_ReadOnly);
        CFRelease(buf);

        // BGRA 字节直接包装为 CGImage（DeviceRGB，零色彩空间转换）：
        // 编码出的 JPEG 数值 = 取景器显示数值（Flutter 纹理按 sRGB 语境直出渲染）。
        CGDataProviderRef provider =
            CGDataProviderCreateWithData(NULL, pixels, dataLen, _freeCapturedFrameData);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGImageRef cgImage = NULL;
        if (provider != NULL && colorSpace != NULL) {
          cgImage = CGImageCreate(w, h, 8, 32, rowBytes, colorSpace,
                                  kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little,
                                  provider, NULL, false, kCGRenderingIntentDefault);
        }
        if (colorSpace != NULL) CGColorSpaceRelease(colorSpace);
        if (provider != NULL) CGDataProviderRelease(provider);
        if (cgImage != NULL) {
          // EXIF orientation 与 photoOutput 路径同映射（portrait 后置=6、前置镜像=5 等），
          // 保证原图备份在系统相册等处的显示行为一致。
          NSDictionary *props = @{
            (id)kCGImageDestinationLossyCompressionQuality: @0.92,
            (id)kCGImagePropertyOrientation: @(exifOrientation),
          };
          NSURL *url = [NSURL fileURLWithPath:path];
          CGImageDestinationRef dest = CGImageDestinationCreateWithURL(
              (__bridge CFURLRef)url, CFSTR("public.jpeg"), 1, NULL);
          if (dest != NULL) {
            CGImageDestinationAddImage(dest, cgImage, (__bridge CFDictionaryRef)props);
            ok = CGImageDestinationFinalize(dest);
            CFRelease(dest);
          }
          CGImageRelease(cgImage);
        }
        NSLog(@"[camerawesome] WYSIWYG video frame capture: %dx%d ok=%d", w, h, ok);
        dispatch_async(dispatch_get_main_queue(), ^{ completion(ok); });
        return;
      }
    }
    CVPixelBufferUnlockBaseAddress(buf, kCVPixelBufferLock_ReadOnly);
    CFRelease(buf);
    NSLog(@"[camerawesome] WYSIWYG video frame capture failed: %dx%d", w, h);
    dispatch_async(dispatch_get_main_queue(), ^{ completion(NO); });
  });
  return YES;
}

/// 直出帧的 EXIF Orientation（1-8），与 CameraPictureController 的
/// getJpegOrientation + exifOrientationFromJpegOrientation 映射保持一致。
- (NSInteger)exifOrientationForVideoFrame {
  UIImageOrientation orientation;
  switch (_motionController.deviceOrientation) {
    case UIDeviceOrientationPortrait:
      if (_cameraSensor == Front && _mirrorFrontCamera) {
        orientation = UIImageOrientationLeftMirrored;
      } else {
        orientation = UIImageOrientationRight;
      }
      break;
    case UIDeviceOrientationLandscapeRight:
      orientation = (_cameraSensor == Back) ? UIImageOrientationUp : UIImageOrientationDown;
      break;
    case UIDeviceOrientationLandscapeLeft:
      orientation = (_cameraSensor == Back) ? UIImageOrientationDown : UIImageOrientationUp;
      break;
    default:
      orientation = UIImageOrientationLeft;
      break;
  }
  switch (orientation) {
    case UIImageOrientationDown:          return 3;
    case UIImageOrientationLeft:          return 8;
    case UIImageOrientationRight:         return 6;
    case UIImageOrientationUpMirrored:    return 2;
    case UIImageOrientationDownMirrored:  return 4;
    case UIImageOrientationLeftMirrored:  return 5;
    case UIImageOrientationRightMirrored: return 7;
    case UIImageOrientationUp:
    default:                              return 1;
  }
}

/// Take the picture into the given path
- (void)takePictureAtPath:(NSString *)path completion:(nonnull void (^)(NSNumber * _Nullable, FlutterError * _Nullable))completion {
  // 【所见即所得直出】无闪光时优先抓取取景器当前帧（videoDataOutput），
  // 成片与取景器同源同色，根治「成片比取景器偏黄」（photoOutput 照片 ISP 偏暖，
  // 详见 captureVideoFrameToJpegAtPath 注释）。闪光模式必须走 photoOutput
  // （video 帧捕捉不到瞬时闪光）。直出条件不满足或编码失败时回退 photoOutput。
  if (_flashMode == AVCaptureFlashModeOff) {
    if ([self captureVideoFrameToJpegAtPath:path
                                  completion:^(BOOL ok) {
                                    if (ok) {
                                      completion(@(YES), nil);
                                    } else {
                                      // 编码失败（磁盘异常等），回退 photoOutput 重试
                                      [self captureWithPhotoOutputAtPath:path completion:completion];
                                    }
                                  }]) {
      return;
    }
    // 无可用帧（相机刚启动等），走 photoOutput
  }
  [self captureWithPhotoOutputAtPath:path completion:completion];
}

/// AVCapturePhotoOutput 拍照路径（直出的回退 / 闪光模式）。
- (void)captureWithPhotoOutputAtPath:(NSString *)path
                           completion:(nonnull void (^)(NSNumber * _Nullable, FlutterError * _Nullable))completion {
  // Instanciate camera picture obj
  CameraPictureController *cameraPicture = [[CameraPictureController alloc] initWithPath:path
                                                                             orientation:_motionController.deviceOrientation
                                                                                  sensor:_cameraSensor
                                                                         saveGPSLocation:_saveGPSLocation
                                                                       mirrorFrontCamera:_mirrorFrontCamera
                                                                             aspectRatio:_aspectRatio
                                                                              completion:completion
                                                                                callback:^{
    // 拍照完成后恢复连续自动白平衡（lockWhiteBalanceToCurrentPreview 在拍照前冻结了它）
    [self restoreAutoWhiteBalance];

    // If flash mode is always on, restore it back after photo is taken
    if (self->_torchMode == AVCaptureTorchModeOn) {
      [self->_captureDevice lockForConfiguration:nil];
      [self->_captureDevice setTorchMode:AVCaptureTorchModeOn];
      [self->_captureDevice unlockForConfiguration];
    }

    completion(@(YES), nil);
  }];

  // Create settings instance
  AVCapturePhotoSettings *settings = [AVCapturePhotoSettings photoSettings];
  [settings setFlashMode:_flashMode];
  [settings setHighResolutionPhotoEnabled:YES];

  // 拍照前锁定白平衡到当前取景器增益，使快照成片与取景器观感一致。
  // 仅无闪光时锁定：闪光模式下快门会闪出与现场环境色温不同的照明，
  // 系统照片管线需要自行评估闪光白平衡，预锁定环境增益反而会让成片偏色。
  if (_flashMode == AVCaptureFlashModeOff) {
    [self lockWhiteBalanceToCurrentPreview];
  }

  [_capturePhotoOutput capturePhotoWithSettings:settings
                                       delegate:cameraPicture];

}

# pragma mark - Camera video
/// Record video into the given path
- (void)recordVideoAtPath:(NSString *)path withOptions:(VideoOptions *)options completion:(nonnull void (^)(FlutterError * _Nullable))completion {
  if (_imageStreamController.streamImages) {
    completion([FlutterError errorWithCode:@"VIDEO_ERROR" message:@"can't record video when image stream is enabled" details:@""]);
    return;
  }
  
  if (!_videoController.isRecording) {
    [_videoController recordVideoAtPath:path orientation:_deviceOrientation audioSetupCallback:^{
      [self setUpCaptureSessionForAudioError:^(NSError *error) {
        completion([FlutterError errorWithCode:@"VIDEO_ERROR" message:@"error when trying to setup audio" details:[error localizedDescription]]);
      }];
    } videoWriterCallback:^{
      if (self->_videoController.isAudioEnabled) {
        [self->_audioOutput setSampleBufferDelegate:self queue:self->_dispatchQueue];
      }
      [self->_captureVideoOutput setSampleBufferDelegate:self queue:self->_dispatchQueue];
      
      completion(nil);
    } options:options completion:completion];
  } else {
    completion([FlutterError errorWithCode:@"VIDEO_ERROR" message:@"already recording video" details:@""]);
  }
}

/// Pause video recording
- (void)pauseVideoRecording {
  [_videoController pauseVideoRecording];
}

/// Resume video recording after being paused
- (void)resumeVideoRecording {
  [_videoController resumeVideoRecording];
}

/// Stop recording video
- (void)stopRecordingVideo:(nonnull void (^)(NSNumber * _Nullable, FlutterError * _Nullable))completion {
  if (_videoController.isRecording) {
    [_videoController stopRecordingVideo:completion];
  } else {
    completion(@(NO), [FlutterError errorWithCode:@"VIDEO_ERROR" message:@"video is not recording" details:@""]);
  }
}

/// Set audio recording mode
- (void)setRecordingAudioMode:(bool)isAudioEnabled completion:(void(^)(NSNumber *_Nullable, FlutterError *_Nullable))completion {
  if (_videoController.isRecording) {
    completion(@(NO), [FlutterError errorWithCode:@"CHANGE_AUDIO_MODE" message:@"impossible to change audio mode, video already recording" details:@""]);
    return;
  }
  
  [_captureSession beginConfiguration];
  [_videoController setIsAudioEnabled:isAudioEnabled];
  [_videoController setIsAudioSetup:NO];
  [_videoController setAudioIsDisconnected:YES];
  
  // Only remove audio channel input but keep video
  for (AVCaptureInput *input in [_captureSession inputs]) {
    for (AVCaptureInputPort *port in input.ports) {
      if ([[port mediaType] isEqual:AVMediaTypeAudio]) {
        [_captureSession removeInput:input];
        break;
      }
    }
  }
  // Only remove audio channel output but keep video
  [_captureSession removeOutput:_audioOutput];
  
  if (_videoController.isRecording) {
    [self setUpCaptureSessionForAudioError:^(NSError *error) {
      completion(@(NO), [FlutterError errorWithCode:@"VIDEO_ERROR" message:@"error when trying to setup audio" details:[error localizedDescription]]);
    }];
  }
  
  
  [_captureSession commitConfiguration];
}

# pragma mark - Audio
/// Setup audio channel to record audio
- (void)setUpCaptureSessionForAudioError:(nonnull void (^)(NSError *))error {
  NSError *audioError = nil;
  // Create a device input with the device and add it to the session.
  // Setup the audio input.
  AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
  AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice
                                                                           error:&audioError];
  if (audioError) {
    error(audioError);
  }
  
  // Setup the audio output.
  _audioOutput = [[AVCaptureAudioDataOutput alloc] init];
  
  if ([_captureSession canAddInput:audioInput]) {
    [_captureSession addInput:audioInput];
    
    if ([_captureSession canAddOutput:_audioOutput]) {
      [_captureSession addOutput:_audioOutput];
      [_videoController setIsAudioSetup:YES];
    } else {
      [_videoController setIsAudioSetup:NO];
    }
  }
}

# pragma mark - Camera Delegates

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
  if (output == _captureVideoOutput) {
    CVPixelBufferRef newBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CFRetain(newBuffer);
    CVPixelBufferRef old = atomic_load(&_latestPixelBuffer);
    while (!atomic_compare_exchange_strong(&_latestPixelBuffer, &old, newBuffer)) {
      old = atomic_load(&_latestPixelBuffer);
    }
    if (old != nil) {
      CFRelease(old);
    }
    if (_onFrameAvailable) {
      _onFrameAvailable();
    }
  }
  
  // Process image stream controller
  if (_imageStreamController.streamImages && !_videoController.isRecording) {
    [_imageStreamController captureOutput:output didOutputSampleBuffer:sampleBuffer fromConnection:connection orientation:_motionController.deviceOrientation];
  }
  
  // Process video recording
  if (_videoController.isRecording) {
    [_videoController captureOutput:output didOutputSampleBuffer:sampleBuffer fromConnection:connection captureVideoOutput:_captureVideoOutput];
  }
}

# pragma mark - Data manipulation

/// Used to copy pixels to in-memory buffer
///
/// 【非消费式读取】引擎（光栅线程）每帧渲染取景器纹理都会调用本方法。
/// 原实现把 _latestPixelBuffer 原子换空（消费），导致每帧渲染后到下一帧
/// 到来前（~33ms）存储为 nil——拍照直出路径（captureVideoFrameToJpegAtPath）
/// 将频繁取不到帧而回退偏黄的 photoOutput。改为：原子换出（取得所有权，
/// 避免与 delegate 的 release 竞争）→ 给引擎 retain 一份 → 原子放回；
/// 放回失败说明 delegate 已存入更新帧，保留新帧即可。
- (CVPixelBufferRef _Nullable)copyPixelBuffer {
  CVPixelBufferRef pixelBuffer = atomic_load(&_latestPixelBuffer);
  while (pixelBuffer != NULL &&
         !atomic_compare_exchange_strong(&_latestPixelBuffer, &pixelBuffer, NULL)) {
  }
  if (pixelBuffer == NULL) return NULL;
  CFRetain(pixelBuffer);
  CVPixelBufferRef expected = NULL;
  if (!atomic_compare_exchange_strong(&_latestPixelBuffer, &expected, pixelBuffer)) {
    // 保留 delegate 存入的新帧；释放我们取出的一次所有权（引擎那份保留）
    CFRelease(pixelBuffer);
  }
  return pixelBuffer;
}

@end
