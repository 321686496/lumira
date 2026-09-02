//
//  QRView.swift
//  flutter_qr
//
//  Created by Julius Canute on 21/12/18.
//

import Foundation
import MTBBarcodeScanner

public class QRView:NSObject,FlutterPlatformView {
    @IBOutlet var previewView: UIView!
    var scanner: MTBBarcodeScanner?
    var registrar: FlutterPluginRegistrar
    var channel: FlutterMethodChannel
    var cameraFacing: MTBCamera

    /// setDimensions 阶段缓存、会话启动后应用的扫描区域（仅识别框内二维码）。
    var pendingScanRect: CGRect?
    
    // Codabar, maxicode, rss14 & rssexpanded not supported. Replaced with qr.
    // UPCa uses ean13 object.
    var QRCodeTypes = [
          0: AVMetadataObject.ObjectType.aztec,
          1: AVMetadataObject.ObjectType.qr,
          2: AVMetadataObject.ObjectType.code39,
          3: AVMetadataObject.ObjectType.code93,
          4: AVMetadataObject.ObjectType.code128,
          5: AVMetadataObject.ObjectType.dataMatrix,
          6: AVMetadataObject.ObjectType.ean8,
          7: AVMetadataObject.ObjectType.ean13,
          8: AVMetadataObject.ObjectType.interleaved2of5,
          9: AVMetadataObject.ObjectType.qr,
          10: AVMetadataObject.ObjectType.pdf417,
          11: AVMetadataObject.ObjectType.qr,
          12: AVMetadataObject.ObjectType.qr,
          13: AVMetadataObject.ObjectType.qr,
          14: AVMetadataObject.ObjectType.ean13,
          15: AVMetadataObject.ObjectType.upce
         ]
    
    public init(withFrame frame: CGRect, withRegistrar registrar: FlutterPluginRegistrar, withId id: Int64, params: Dictionary<String, Any>){
        self.registrar = registrar
        previewView = UIView(frame: frame)
        cameraFacing = MTBCamera.init(rawValue: UInt(Int(params["cameraFacing"] as! Double))) ?? MTBCamera.back
        channel = FlutterMethodChannel(name: "net.touchcapture.qr.flutterqr/qrview_\(id)", binaryMessenger: registrar.messenger())
    }
    
    deinit {
        scanner?.stopScanning()
    }
    
    public func view() -> UIView {
        channel.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch(call.method){
                case "setDimensions":
                    let arguments = call.arguments as! Dictionary<String, Double>
                    self?.setDimensions(result,
                                        width: arguments["width"] ?? 0,
                                        height: arguments["height"] ?? 0,
                                        scanAreaWidth: arguments["scanAreaWidth"] ?? 0,
                                        scanAreaHeight: arguments["scanAreaHeight"] ?? 0,
                                        scanAreaOffset: arguments["scanAreaOffset"] ?? 0)
                case "startScan":
                    self?.startScan(call.arguments as! Array<Int>, result)
                case "flipCamera":
                    self?.flipCamera(result)
                case "toggleFlash":
                    self?.toggleFlash(result)
                case "pauseCamera":
                    self?.pauseCamera(result)
                case "stopCamera":
                    self?.stopCamera(result)
                case "resumeCamera":
                    self?.resumeCamera(result)
                case "getCameraInfo":
                    self?.getCameraInfo(result)
                case "getFlashInfo":
                    self?.getFlashInfo(result)
                case "getSystemFeatures":
                    self?.getSystemFeatures(result)
                default:
                    result(FlutterMethodNotImplemented)
                    return
            }
        })
        return previewView
    }
    
    func setDimensions(_ result: @escaping FlutterResult, width: Double, height: Double, scanAreaWidth: Double, scanAreaHeight: Double, scanAreaOffset: Double) {
        // Then set the size of the preview area.
        previewView.frame = CGRect(x: 0, y: 0, width: width, height: height)
        
        // Then set the size of the scan area.
        let midX = self.view().bounds.midX
        let midY = self.view().bounds.midY
        
        if let sc: MTBBarcodeScanner = scanner {
            // Set the size of the preview if preview is already created.
            if let previewLayer = sc.previewLayer {
                previewLayer.frame = self.previewView.bounds
            }
        } else {
            // Create new preview.
            scanner = MTBBarcodeScanner(previewView: previewView)
        }

        // Set scanArea if provided. 不在这里直接挂 didStartScanningBlock——
        // 该回调会被 startScan 里 configureHighQualityScanning 覆盖，导致扫描区域失效；
        // 这里仅缓存待应用的扫描区域，由 configureHighQualityScanning 在会话启动后统一应用。
        if (scanAreaWidth != 0 && scanAreaHeight != 0) {
            var rect = CGRect(x: Double(midX) - (scanAreaWidth / 2),
                              y: Double(midY) - (scanAreaHeight / 2),
                              width: scanAreaWidth,
                              height: scanAreaHeight)

            // Set offset if provided.
            if (scanAreaOffset != 0) {
                let reversedOffset = -scanAreaOffset
                rect = rect.offsetBy(dx: 0, dy: CGFloat(reversedOffset))
            }
            pendingScanRect = rect
        }
        return result(width)
        
    }
    
    func startScan(_ arguments: Array<Int>, _ result: @escaping FlutterResult) {
        // Check for allowed barcodes
        var allowedBarcodeTypes: Array<AVMetadataObject.ObjectType> = []
        arguments.forEach { arg in
            allowedBarcodeTypes.append( QRCodeTypes[arg]!)
        }
        MTBBarcodeScanner.requestCameraPermission(success: { [weak self] permissionGranted in
            guard let self = self else { return }

            self.channel.invokeMethod("onPermissionSet", arguments: permissionGranted)

            if permissionGranted {
                // 在会话启动完成后立刻提升取景清晰度：提高 sessionPreset 分辨率
                // + 开启连续自动对焦/自动曝光，避免靠近二维码时画面越拉越模糊。
                self.scanner?.didStartScanningBlock = { [weak self] in
                    self?.configureHighQualityScanning()
                }
                do {
                    try self.scanner?.startScanning(with: self.cameraFacing, resultBlock: { [weak self] codes in
                        if let codes = codes {
                            for code in codes {
                                var typeString: String;
                                switch(code.type) {
                                    case AVMetadataObject.ObjectType.aztec:
                                       typeString = "AZTEC"
                                    case AVMetadataObject.ObjectType.code39:
                                        typeString = "CODE_39"
                                    case AVMetadataObject.ObjectType.code93:
                                        typeString = "CODE_93"
                                    case AVMetadataObject.ObjectType.code128:
                                        typeString = "CODE_128"
                                    case AVMetadataObject.ObjectType.dataMatrix:
                                        typeString = "DATA_MATRIX"
                                    case AVMetadataObject.ObjectType.ean8:
                                        typeString = "EAN_8"
                                    case AVMetadataObject.ObjectType.ean13:
                                        typeString = "EAN_13"
                                    case AVMetadataObject.ObjectType.itf14,
                                         AVMetadataObject.ObjectType.interleaved2of5:
                                        typeString = "ITF"
                                    case AVMetadataObject.ObjectType.pdf417:
                                        typeString = "PDF_417"
                                    case AVMetadataObject.ObjectType.qr:
                                        typeString = "QR_CODE"
                                    case AVMetadataObject.ObjectType.upce:
                                        typeString = "UPC_E"
                                    default:
                                        return
                                }
                                let bytes = { () -> Data? in
                                    if #available(iOS 11.0, *) {
                                        switch (code.descriptor) {
                                        case let qrDescriptor as CIQRCodeDescriptor:
                                            return qrDescriptor.errorCorrectedPayload
                                        case let aztecDescriptor as CIAztecCodeDescriptor:
                                            return aztecDescriptor.errorCorrectedPayload
                                        case let pdf417Descriptor as CIPDF417CodeDescriptor:
                                            return pdf417Descriptor.errorCorrectedPayload
                                        case let dataMatrixDescriptor as CIDataMatrixCodeDescriptor:
                                            return dataMatrixDescriptor.errorCorrectedPayload
                                        default:
                                            return nil
                                        }
                                    } else {
                                        return nil
                                    }
                                }()
                                let result = { () -> [String : Any]? in
                                    guard let stringValue = code.stringValue else {
                                        guard let safeBytes = bytes else {
                                            return nil
                                        }
                                        return ["type": typeString, "rawBytes": safeBytes]
                                    }
                                    guard let safeBytes = bytes else {
                                        return ["code": stringValue, "type": typeString]
                                    }
                                    return ["code": stringValue, "type": typeString, "rawBytes": safeBytes]
                                }()
                                guard result != nil else { continue }
                                if allowedBarcodeTypes.count == 0 || allowedBarcodeTypes.contains(code.type) {
                                    self?.channel.invokeMethod("onRecognizeQR", arguments: result)
                                }
                                
                            }
                        }

                    })
                } catch {
                    let scanError = FlutterError(code: "unknown-error", message: "Unable to start scanning", details: error)
                    result(scanError)
                }
            }
        })
    }
    
    /// 会话启动后配置高清晰度取景（提升拉近时的清晰度）。
    ///
    /// MTBBarcodeScanner 默认 sessionPreset = High（720p），在 2x/3x 高分屏上
    /// 放大预览会明显发虚；且默认未开启连续自动对焦，手机靠近二维码时相机
    /// 不会重新对焦，导致画面越拉越模糊。这里：
    /// 1. 通过 previewLayer 拿到 session（MTBBarcodeScanner 未公开 session），
    ///    把 preset 提升到 .photo（不支持时回退 1080p）；
    /// 2. 对当前摄像头开启连续自动对焦/自动曝光，让相机随距离变化持续对焦；
    /// 3. 聚焦点锁定在取景中央 + 近距对焦优先（.near），改善靠近二维码失焦；
    /// 4. 应用 setDimensions 缓存的扫描区域（scanRect），保证只识别框内码。
    func configureHighQualityScanning() {
        guard let scanner = self.scanner else { return }

        // 1. 提高取景分辨率
        if let previewLayer = scanner.previewLayer as? AVCaptureVideoPreviewLayer,
           let session = previewLayer.session {
            let preferred: AVCaptureSession.Preset = .photo
            if session.canSetSessionPreset(preferred) {
                session.beginConfiguration()
                session.sessionPreset = preferred
                session.commitConfiguration()
            } else if session.canSetSessionPreset(.hd1920x1080) {
                session.beginConfiguration()
                session.sessionPreset = .hd1920x1080
                session.commitConfiguration()
            }
        }

        // 2-3. 连续自动对焦 + 自动曝光 + 中央聚焦 + 近距优先（iOS 10+）
        if #available(iOS 10.0, *) {
            let position: AVCaptureDevice.Position =
                (self.cameraFacing == MTBCamera.front) ? .front : .back
            guard let device = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: position)
            else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                }
                if device.isAutoFocusRangeRestrictionSupported {
                    device.autoFocusRangeRestriction = .near
                }
                device.unlockForConfiguration()
            } catch {
                // 配置失败（如设备忙）时保持默认行为，不阻断扫码
            }
        }

        // 4. 应用扫描区域限制（setDimensions 阶段缓存）
        if let scanRect = self.pendingScanRect {
            scanner.scanRect = scanRect
        }
    }

    func stopCamera(_ result: @escaping FlutterResult) {
        if let sc: MTBBarcodeScanner = self.scanner {
            if sc.isScanning() {
                sc.stopScanning()
            }
        }
    }
    
    func getCameraInfo(_ result: @escaping FlutterResult) {
        result(self.cameraFacing.rawValue)
    }
    
    func flipCamera(_ result: @escaping FlutterResult) {
        if let sc: MTBBarcodeScanner = self.scanner {
            if sc.hasOppositeCamera() {
                sc.flipCamera()
                self.cameraFacing = sc.camera
            }
            return result(sc.camera.rawValue)
        }
        return result(FlutterError(code: "404", message: "No barcode scanner found", details: nil))
    }
    
    func getFlashInfo(_ result: @escaping FlutterResult) {
        if let sc: MTBBarcodeScanner = self.scanner {
            result(sc.torchMode.rawValue != 0)
        } else {
            let error = FlutterError(code: "cameraInformationError", message: "Could not get flash information", details: nil)
            result(error)
        }
    }
    
    func toggleFlash(_ result: @escaping FlutterResult){
        if let sc: MTBBarcodeScanner = self.scanner {
            if sc.hasTorch() {
                sc.toggleTorch()
                return result(sc.torchMode == MTBTorchMode(rawValue: 1))
            }
            return result(FlutterError(code: "404", message: "This device doesn\'t support flash", details: nil))
        }
        return result(FlutterError(code: "404", message: "No barcode scanner found", details: nil))
    }
    
    func pauseCamera(_ result: @escaping FlutterResult) {
        if let sc: MTBBarcodeScanner = self.scanner {
            if sc.isScanning() {
                sc.freezeCapture()
            }
            return result(true)
        }
        return result(FlutterError(code: "404", message: "No barcode scanner found", details: nil))
    }
    
    func resumeCamera(_ result: @escaping FlutterResult) {
        if let sc: MTBBarcodeScanner = self.scanner {
            if !sc.isScanning() {
                sc.unfreezeCapture()
            }
            return result(true)
        }
        return result(FlutterError(code: "404", message: "No barcode scanner found", details: nil))
    }

    func getSystemFeatures(_ result: @escaping FlutterResult) {
        if let sc: MTBBarcodeScanner = scanner {
            var hasBackCameraVar = false
            var hasFrontCameraVar = false
            let camera = sc.camera

            if(camera == MTBCamera(rawValue: 0)){
                hasBackCameraVar = true
                if sc.hasOppositeCamera() {
                    hasFrontCameraVar = true
                }
            }else{
                hasFrontCameraVar = true
                if sc.hasOppositeCamera() {
                    hasBackCameraVar = true
                }
            }
            return result([
                "hasFrontCamera": hasFrontCameraVar,
                "hasBackCamera": hasBackCameraVar,
                "hasFlash": sc.hasTorch(),
                "activeCamera": camera.rawValue
            ])
        }
        return result(FlutterError(code: "404", message: nil, details: nil))
    }

 }
