//
//  CameraPicture.m
//  camerawesome
//
//  Created by Dimitri Dessus on 24/07/2020.
//

#import "CameraPictureController.h"
#import "ExifContainer.h"
#import "NSData+Exif.h"

@implementation CameraPictureController {
  CameraPictureController *selfReference;
}

- (instancetype)initWithPath:(NSString *)path
                 orientation:(NSInteger)orientation
                      sensor:(CameraSensor)sensor
             saveGPSLocation:(bool)saveGPSLocation
           mirrorFrontCamera:(bool)mirrorFrontCamera
                 aspectRatio:(AspectRatio)aspectRatio
                  completion:(nonnull void (^)(NSNumber * _Nullable, FlutterError * _Nullable))completion
                    callback:(OnPictureTaken)callback {
  self = [super init];
  NSAssert(self, @"super init cannot be nil");
  _path = path;
  _completion = completion;
  _orientation = orientation;
  _completionBlock = callback;
  _sensor = sensor;
  _saveGPSLocation = saveGPSLocation;
  _aspectRatioType = aspectRatio;
  _mirrorFrontCamera = mirrorFrontCamera;
  
  if (aspectRatio == Ratio4_3) {
    _aspectRatio = 4.0/3.0;
  } else if(aspectRatio == Ratio16_9) {
    _aspectRatio = 16.0/9.0;
  } else {
    _aspectRatio = 1;
  }
  
  selfReference = self;
  return self;
}

- (NSData *)writeMetadataIntoImageData:(NSData *)imageData metadata:(NSMutableDictionary *)metadata {
  // create an imagesourceref
  CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef) imageData, NULL);
  
  // this is the type of image (e.g., public.jpeg)
  CFStringRef UTI = CGImageSourceGetType(source);
  
  // create a new data object and write the new image into it
  NSMutableData *dest_data = [NSMutableData data];
  CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)dest_data, UTI, 1, NULL);
  if (!destination) {
    NSLog(@"Error: Could not create image destination");
  }
  // add the image contained in the image source to the destination, overidding the old metadata with our modified metadata
  CGImageDestinationAddImageFromSource(destination, source, 0, (__bridge CFDictionaryRef) metadata);
  BOOL success = NO;
  success = CGImageDestinationFinalize(destination);
  if (!success) {
    NSLog(@"Error: Could not create data from image destination");
  }
  CFRelease(destination);
  CFRelease(source);
  return dest_data;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (void)captureOutput:(AVCapturePhotoOutput *)output
didFinishProcessingPhotoSampleBuffer:(CMSampleBufferRef)photoSampleBuffer
previewPhotoSampleBuffer:(CMSampleBufferRef)previewPhotoSampleBuffer
     resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
      bracketSettings:(AVCaptureBracketedStillImageSettings *)bracketSettings
                error:(NSError *)error {
#pragma clang diagnostic pop
  
  selfReference = nil;
  if (error) {
    _completion(nil, [FlutterError errorWithCode:@"CAPTURE ERROR" message:error.description details:@""]);
    return;
  }
  
  // Add exif data
  ExifContainer *container = [[ExifContainer alloc] init];
  [container addCreationDate:[NSDate date]];
  
  // Save GPS location only if provided
  if (_saveGPSLocation) {
    CLLocationManager *locationManager = [CLLocationManager new];
    CLLocation *location = [locationManager location];
    [container addLocation:location];
  }
  
  // we ignore this error because plugin can only be installed on iOS 11+
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  NSData *data = [AVCapturePhotoOutput JPEGPhotoDataRepresentationForJPEGSampleBuffer:photoSampleBuffer
                                                             previewPhotoSampleBuffer:previewPhotoSampleBuffer];
#pragma clang diagnostic pop
  
  // Color fidelity fix (iOS): save the full-resolution sensor photo WITHOUT going
  // through UIImage → UIImageJPEGRepresentation re-encoding.
  //
  // Why: on wide-gamut devices the camera's AVCapturePhoto JPEG is Display P3.
  // UIImageJPEGRepresentation performs a non-perceptual P3 → sRGB conversion that
  // over-saturates warm tones (e.g. skin), making the captured photo look yellow,
  // while the viewfinder (AVCaptureVideoPreviewLayer) is rendered natively in the
  // device P3 display space and therefore looks neutral.
  //
  // Fix: keep the sensor's original bytes and only overlay EXIF metadata
  // (creation date / GPS / image orientation). addExif uses
  // CGImageDestinationAddImageFromSource, which copies the source pixels and merges
  // metadata WITHOUT re-encoding the color data, so the native color pipeline and its
  // embedded color profile are preserved intact.
  //
  // This matches Android (CameraX) / OHOS (Camera Kit), which save the raw sensor
  // photo and let the app's Dart pipeline crop to the selected ratio afterwards.
  [container addImageOrientation:[self exifOrientationFromJpegOrientation:[self getJpegOrientation]]];
  
  NSData *imageWithExif = [data addExif:container];
  
  bool success = [imageWithExif writeToFile:_path atomically:YES];
  if (!success) {
    _completion(nil, [FlutterError errorWithCode:@"IOError" message:@"unable to write file" details:nil]);
    return;
  }
  _completionBlock();
  
}

- (UIImage *)imageByCroppingImage:(UIImage *)image toSize:(CGSize)size {
  double newCropWidth, newCropHeight;

  if(image.size.width < image.size.height) {
    if (image.size.width < size.width) {
      newCropWidth = size.width;
    } else {
      newCropWidth = image.size.width;
    }
    newCropHeight = (newCropWidth * size.height)/size.width;
  } else {
    if (image.size.height < size.height) {
      newCropHeight = size.height;
    } else {
      newCropHeight = image.size.height;
    }
    newCropWidth = (newCropHeight * size.width)/size.height;
  }
  
  double imageHeightDivided = image.size.height/2.0;
  double imageWidthDivided = image.size.width/2.0;
  
  double x = imageWidthDivided - newCropWidth/2.0;
  double y = imageHeightDivided - newCropHeight/2.0;
  
  CGRect cropRect;
  if (UIDeviceOrientationIsLandscape(_orientation)) {
    cropRect = CGRectMake(x, y, newCropWidth, newCropHeight);
  } else {
    if (_aspectRatioType == Ratio16_9) {
      cropRect = CGRectMake(0, 0, image.size.height, image.size.width);
    } else {
      if (_aspectRatioType == Ratio4_3) {
        double localX = imageHeightDivided - (imageHeightDivided / _aspectRatio);
        cropRect = CGRectMake(localX, 0, image.size.height / _aspectRatio, image.size.width);
      } else {
        cropRect = CGRectMake(y, x, newCropWidth, newCropHeight);
      }
    }
  }
  
  CGImageRef imageRef = CGImageCreateWithImageInRect([image CGImage], cropRect);
  
  UIImage *cropped = [UIImage imageWithCGImage:imageRef];
  CGImageRelease(imageRef);
  
  return cropped;
}

- (UIImageOrientation)getJpegOrientation {
  switch (_orientation) {
    case UIDeviceOrientationPortrait:
      if (_sensor == Front && _mirrorFrontCamera) {
        return UIImageOrientationLeftMirrored;
      } else {
        return UIImageOrientationRight;
      }
    case UIDeviceOrientationLandscapeRight:
      return (_sensor == Back) ? UIImageOrientationUp : UIImageOrientationDown;
    case UIDeviceOrientationLandscapeLeft:
      return (_sensor == Back) ? UIImageOrientationDown : UIImageOrientationUp;
    default:
      return UIImageOrientationLeft;
  }
}

// 将 UIImageOrientation 映射为 EXIF Orientation(1-8)。
// 相机原始 JPEG 已带传感器方向 EXIF，无需物理旋转像素；
// 写落盘时仅用此值覆盖 EXIF 方向标记，与 getJpegOrientation 语义保持一致。
- (NSInteger)exifOrientationFromJpegOrientation:(UIImageOrientation)orientation {
  // EXIF: 1=Up, 2=UpMirrored, 3=Down, 4=DownMirrored,
  //       5=LeftMirrored, 6=Rotate90CW, 7=RightMirrored, 8=Rotate270CW
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

@end
