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

    /// 是否已识别到首个有效码。识别后立即清空 resultBlock 停止每帧
    /// 重复回调（MTBBarcodeScanner 的 resultBlock 每帧都会被调用），避免经平台
    /// 通道高频回调打爆主线程；同时避免 pop 转场期间触发重型 stopScanning。
    var didDetect = false

    /// 是否已执行过一次高清晰度 session 配置（preset 提升）。preset 变更会触发
    /// AVFoundation 会话异步重建并冲掉刚设好的连续自动对焦/近距限制，反复变更
    /// preset 会让近距重新拉焦、画面发虚。该守卫保证 preset 只提升一次，对焦则
    /// 在每次 didStartScanningBlock 中重复补（见 configureHighQualityScanning）。
    private var didConfigureHighQuality = false
    
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
        // 统一走轻量停流：iOS 18+ 用 freezeCapture，避免 stopScanning 的会话
        // 拆除（removeInput/removeOutput/stopRunning）阻塞主线程导致 UI 挂起。
        stopScanningLightly()
    }
    
    public func view() -> UIView {
        // 注册点击对焦手势（防重复添加）：近距离取景时用户可点击目标位置立即合焦
        if previewView.gestureRecognizers?.contains(where: { $0 is UITapGestureRecognizer }) != true {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTapToFocus(_:)))
            previewView.addGestureRecognizer(tap)
        }
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
                    NSLog("[QRView] didStartScanningBlock fired — configure high quality")
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
                                guard let result = result else { continue }
                                if allowedBarcodeTypes.count == 0 || allowedBarcodeTypes.contains(code.type) {
                                    self?.emitOnce(result)
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
    ///    把 preset 提升到 1080p（AVFoundation 扫码元数据输出最稳定清晰档位，
    ///    同时清晰度足以应对近距离二维码；不使用 .photo 以规避大分辨率下
    ///    元数据输出偶发识别缺失）；
    /// 2. 对当前摄像头开启连续自动对焦/自动曝光，让相机随距离变化持续对焦；
    /// 3. 聚焦点锁定在取景中央 + 近距对焦优先（.near），改善靠近二维码失焦；
    /// 4. 应用 setDimensions 缓存的扫描区域（scanRect），保证只识别框内码。
    ///
    /// 注：贴近到镜头最小对焦距离以内时（常见 iPhone 约 8cm 内）受硬件物理
    /// 限制必然模糊，无法靠软件消除；此处保证可用距离内画面最清晰。
    func configureHighQualityScanning() {
        guard let scanner = self.scanner else { return }
        guard let previewLayer = scanner.previewLayer as? AVCaptureVideoPreviewLayer,
              let session = previewLayer.session else { return }

        // 1. 提高取景分辨率：1080p。MTBBarcodeScanner 默认 AVCaptureSessionPresetHigh
        //    (720p)，在 2x/3x 高分屏上放大预览会明显发虚；1080p 是扫码元数据输出
        //    最稳定清晰的档位（不使用 .photo 以规避大分辨率下识别偶发缺失）。
        //    仅在首次执行——preset 变更会触发会话重建并冲掉连续对焦/近距限制，
        //    重复变更反而让画面反复拉焦。对焦已在下方每次 didStartScanningBlock
        //    重复补，无需再次触发重建。
        if !didConfigureHighQuality {
            session.beginConfiguration()
            let preferred: AVCaptureSession.Preset = .hd1920x1080
            if session.canSetSessionPreset(preferred) {
                session.sessionPreset = preferred
            }
            session.commitConfiguration()
            didConfigureHighQuality = true
        }

        // 2. 连续自动对焦/自动曝光 + 中央聚焦 + 近距优先。
        //    preset 提升会让 AVFoundation 重建会话连接，从而把刚设好的自动对焦/
        //    曝光重置回默认——这是「手机拉近二维码后画面仍发虚」的核心根因。这里
        //    立即应用一次，并在接下来的 ~1.5s 内短周期重复补对焦，确保连续对焦在
        //    分辨率提升之后依然生效（近距取景保持清晰，且对设备/时序差异更鲁棒）。
        if #available(iOS 10.0, *) {
            let device = (session.inputs.compactMap { $0 as? AVCaptureDeviceInput }
                .first?.device)
                ?? AVCaptureDevice.default(
                    .builtInWideAngleCamera, for: .video,
                    position: (self.cameraFacing == MTBCamera.front) ? .front : .back)
            guard let device = device else { return }
            self.applyBestFocus(on: device)
            // 覆盖会话重建窗口的大致时长：0.2s/0.5s/1.0s/1.5s 各补一次。
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else { return }
                self.applyBestFocus(on: device)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                self.applyBestFocus(on: device)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                self.applyBestFocus(on: device)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                self.applyBestFocus(on: device)
            }
        }

        // 3. 应用扫描区域限制（setDimensions 阶段缓存）
        if let scanRect = self.pendingScanRect {
            scanner.scanRect = scanRect
        }

        NSLog("[QRView] high-quality configured preset=%@", session.sessionPreset.rawValue)
    }

    /// 对指定摄像头应用「中央聚焦 + 连续自动对焦/曝光 + 近距优先」。
    ///
    /// 注意顺序：AVFoundation 要求先设置 focusPointOfInterest /
    /// exposurePointOfInterest，再设置 focusMode / exposureMode——
    /// 反过来先设模式再设点，焦点点不会生效（此前「近距离仍模糊」的根因之一）。
    /// lockForConfiguration 对同一设备是安全的，失败（如设备忙）时静默回退、
    /// 不阻断扫码。提取为复用方法，供 preset 提升前后各调用一次，覆盖会话
    /// 重建导致的配置回退。
    @available(iOS 10.0, *)
    private func applyBestFocus(on device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }
            device.unlockForConfiguration()
        } catch {
            // 配置失败（如设备忙）时保持默认行为，不阻断扫码
        }
    }

    /// 点击对焦：把点击位置换算成相机设备坐标并单次对焦，稍后恢复连续对焦。
    ///
    /// 靠近二维码时若连续对焦仍在拉风箱，用户点击取景框内目标位置可立即
    /// 合焦（对齐微信等主流扫码体验）。坐标转换用 previewLayer 的
    /// captureDevicePointConverted(fromLayerPoint:)，自动处理预览方向与
    /// videoGravity 裁剪。
    @objc private func handleTapToFocus(_ gesture: UITapGestureRecognizer) {
        guard #available(iOS 10.0, *),
              let scanner = self.scanner,
              let previewLayer = scanner.previewLayer as? AVCaptureVideoPreviewLayer,
              let session = previewLayer.session else { return }
        let device = session.inputs.compactMap { $0 as? AVCaptureDeviceInput }.first?.device
        guard let device = device else { return }
        let tapPoint = gesture.location(in: previewView)
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: tapPoint)
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = devicePoint
            }
            // 单次自动对焦立即合焦；同时把曝光测光点带到点击处
            if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = devicePoint
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        } catch {
            return
        }
        // 单次对焦合焦后恢复连续自动对焦，保持后续移动取景仍能跟焦
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.applyBestFocus(on: device)
        }
    }

    /// 识别到首个有效码后经平台通道回传一次，并立即置位停止后续重复回传。
    ///
    /// MTBBarcodeScanner 的 resultBlock 每帧都会被调用（同一码会被识别几十次），
    /// 若不在此截断，会持续把同一结果经 iOS 平台视图通道高频发回 Dart，抢占
    /// 主线程并反复触发 pop，是「扫码后卡死」的根因之一。
    ///
    /// 回传后**立即轻量停流**：Dart 收到结果会 pop 页面并随视图拆除调用
    /// stopCamera / deinit，若相机此时仍在出流，iOS 18+ 上平台视图（UiKitView）
    /// 与活动 AVCaptureSession 的拆除会互锁导致主线程挂起（社区已在
    /// qr_code_scanner_plus 中以 freeze 规避）。这里先停掉相机，保证视图拆除前
    /// 会话已停，从根上避开该死锁。
    func emitOnce(_ result: [String : Any]) {
        if didDetect { return }
        didDetect = true
        scanner?.resultBlock = nil
        NSLog("[QRView] emitOnce: detected, send result then stop capture")
        channel.invokeMethod("onRecognizeQR", arguments: result)
        stopScanningLightly()
    }

    /// 轻量停流：iOS 18+ 用 freezeCapture（仅后台 stopRunning + 禁用连接，
    /// 不会阻塞主线程），iOS 18 以下用 stopScanning 彻底拆除会话。
    /// 与 deinit / stopCamera 共用，保证所有退出路径一致且不挂起主线程。
    private func stopScanningLightly() {
        guard let sc = scanner else { return }
        if sc.isScanning() {
            if #available(iOS 18.0, *) {
                NSLog("[QRView] freezeCapture (iOS 18+)")
                sc.freezeCapture()
            } else {
                NSLog("[QRView] stopScanning (< iOS 18)")
                sc.stopScanning()
            }
        } else {
            NSLog("[QRView] stopScanningLightly: not scanning, skip")
        }
    }

    /// 关闭相机。
    ///
    /// iOS 18+ 上 stopScanning 的会话拆除（removeOutput/removeInput + stopRunning）
    /// 会阻塞主线程导致 UI 挂起（社区已验证，qr_code_scanner_plus 改用 freeze）。
    /// 因此统一走 [stopScanningLightly]：iOS 18+ 轻量停流，iOS 18 以下彻底拆除。
    func stopCamera(_ result: @escaping FlutterResult) {
        stopScanningLightly()
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
