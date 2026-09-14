import UIKit
import Flutter
import Photos

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    registerPhotoSaverChannel()
    registerSystemShareChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// 注册 "lumira/photo_saver" 方法通道，供 Flutter 层调用原生保存照片到系统相册。
  /// 修复 iOS 端 MissingPluginException：之前仅 OHOS 有实现，iOS 无对应原生实现。
  private func registerPhotoSaverChannel() {
    guard let registrar = self.registrar(forPlugin: "LumiraPhotoSaver") else { return }
    let channel = FlutterMethodChannel(
      name: "lumira/photo_saver",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "saveToAlbum" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String, !path.isEmpty else {
        result(["success": false, "error": "路径为空"])
        return
      }
      self?.saveToAlbum(path: path, result: result)
    }
  }

  /// 请求相册"仅添加"权限并保存图片。仅申请 addOnly 权限（无需 read full library）。
  private func saveToAlbum(path: String, result: @escaping FlutterResult) {
    let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    let handleStatus: (Bool) -> Void = { [weak self] authorized in
      DispatchQueue.main.async {
        guard authorized else {
          result(["success": false, "error": "用户未授权写入相册"])
          return
        }
        self?.performSave(path: path, result: result)
      }
    }
    switch status {
    case .authorized, .limited:
      handleStatus(true)
    case .notDetermined:
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { s in
        handleStatus(s == .authorized || s == .limited)
      }
    default:
      handleStatus(false)
    }
  }

  /// 通过 PHAssetChangeRequest 直接从本地文件写入系统相册（不走内存，适配大图）。
  private func performSave(path: String, result: @escaping FlutterResult) {
    let fileURL = URL(fileURLWithPath: path)
    PHPhotoLibrary.shared().performChanges {
      _ = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
    } completionHandler: { success, error in
      DispatchQueue.main.async {
        if success {
          result(["success": true])
        } else {
          result(["success": false, "error": error?.localizedDescription ?? "保存失败"])
        }
      }
    }
  }

  private func registerSystemShareChannel() {
    guard let registrar = registrar(forPlugin: "LumiraSystemShare") else { return }
    let channel = FlutterMethodChannel(
      name: "lumira/system_share",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "shareFiles":
        guard let args = call.arguments as? [String: Any],
              let paths = args["paths"] as? [String], !paths.isEmpty else {
          result(["success": false, "error": "empty paths"])
          return
        }
        let items: [Any] = paths.map { URL(fileURLWithPath: $0) }
        presentSystemShare(items: items, result: result)
      case "shareText":
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String, !text.isEmpty else {
          result(["success": false, "error": "empty text"])
          return
        }
        presentSystemShare(items: [text], result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

private func presentSystemShare(items: [Any], result: @escaping FlutterResult) {
  guard let scene = UIApplication.shared.connectedScenes
    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
        let rootViewController = scene.windows.first(where: { $0.isKeyWindow })?
    .rootViewController else {
    result(["success": false, "error": "no key window"])
    return
  }

  var presenter = rootViewController
  while let presentedViewController = presenter.presentedViewController {
    presenter = presentedViewController
  }

  let activityController = UIActivityViewController(
    activityItems: items,
    applicationActivities: nil
  )
  activityController.popoverPresentationController?.sourceView = presenter.view
  presenter.present(activityController, animated: true)
  result(["success": true])
}
