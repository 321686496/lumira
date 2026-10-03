import Foundation
import Flutter
import StoreKit
import UIKit

/// 如画 Lumira iOS 内购原生通道（**仅 iOS 生效**）。
///
/// 职责边界（刻意保持最小）：
/// 1. 拉取消耗型积分包商品（Product.products）；
/// 2. 发起购买（Product.purchase）；
/// 3. 监听交易（Transaction.updates / Transaction.unfinished），把交易推给 Flutter 侧；
/// 4. 展示 Apple 官方「优惠代码」兑换面板（AppStore.presentOfferCodeRedeemSheet）；
/// 5. 读取 App 收据（Bundle.main.appStoreReceiptURL）供后端校验。
///
/// 本类不做任何发奖：积分发放由 Flutter 层携带收据调用后端 /iap/verify 完成，
/// 校验成功后 Flutter 再回传 transactionId 调 finishTransaction 收尾，
/// 这样可避免「掉单」与「重复发奖」。
///
/// 为何走原生通道而非 pub 依赖（如 in_app_purchase）：本项目需同时兼顾 HarmonyOS
/// 构建，新增第三方插件会影响 OHOS 侧编译；这里只对 iOS 做增量实现，不改动 Android/OHOS。
@available(iOS 15.0, *)
final class LumiraIapChannel: NSObject {
  private static let channelName = "lumira/iap"

  /// 保持强引用：注册后若被释放，通道会随之失效
  private static var shared: LumiraIapChannel?
  /// 收据刷新请求的持有者（SKReceiptRefreshRequest 不持有 delegate）
  fileprivate static var receiptRefreshHelper: ReceiptRefreshHelper?

  private let channel: FlutterMethodChannel
  private var updatesTask: Task<Void, Never>?
  /// 尚未 finish 的交易缓存：key = transactionId，供 Dart 侧校验成功后 finish
  private var pendingTransactions: [String: Transaction] = [:]

  private init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    startObservingTransactions()
  }

  /// 在 AppDelegate 中调用，注册原生通道
  static func register(with registrar: FlutterPluginRegistrar) {
    shared = LumiraIapChannel(messenger: registrar.messenger())
  }

  // MARK: - 交易监听 / 补单

  private func startObservingTransactions() {
    if updatesTask != nil { return }
    updatesTask = Task { [weak self] in
      // 1) 先补发启动前未完成的交易（含「App 外兑换优惠代码」后在 App 内首次启动的场景）
      for await result in Transaction.unfinished {
        await self?.emit(result)
      }
      // 2) 再持续监听运行期产生的新交易
      for await result in Transaction.updates {
        await self?.emit(result)
      }
    }
  }

  /// 把交易推送给 Flutter 侧（Dart 收到后调后端校验并回传 finishTransaction）
  private func emit(_ result: VerificationResult<Transaction>) async {
    let payload = Self.encode(result)
    if case .verified(let tx) = result {
      pendingTransactions["\(tx.id)"] = tx
    }
    await MainActor.run {
      self.channel.invokeMethod("onTransaction", arguments: payload)
    }
  }

  // MARK: - 方法分发

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      reply(result, ["available": true])
    case "getProducts":
      handleGetProducts(call, result: result)
    case "purchase":
      handlePurchase(call, result: result)
    case "finishTransaction":
      handleFinishTransaction(call, result: result)
    case "presentOfferCodeSheet":
      handleOfferCodeSheet(result: result)
    case "getReceipt":
      handleGetReceipt(result: result)
    default:
      reply(result, FlutterMethodNotImplemented)
    }
  }

  /// 统一在主线程回调（FlutterResult 必须在主线程调用）
  private func reply(_ result: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async { result(value) }
  }

  // MARK: - 商品

  private func handleGetProducts(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let ids = args["ids"] as? [String], !ids.isEmpty else {
      reply(result, FlutterError(code: "bad_args", message: "缺少商品 id 列表", details: nil))
      return
    }
    Task {
      do {
        let products = try await Product.products(for: ids)
        let list: [[String: Any]] = products.map { Self.encode($0) }
        self.reply(result, ["products": list])
      } catch {
        self.reply(result, FlutterError(code: "products_failed", message: error.localizedDescription, details: nil))
      }
    }
  }

  private static func encode(_ product: Product) -> [String: Any] {
    // displayPrice 已带货币符号（如 ¥6.00），Flutter 侧直接展示即可
    return [
      "id": product.id,
      "displayName": product.displayName,
      "description": product.description,
      "displayPrice": product.displayPrice,
    ]
  }

  // MARK: - 购买

  private func handlePurchase(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let productId = args["id"] as? String, !productId.isEmpty else {
      reply(result, FlutterError(code: "bad_args", message: "缺少商品 id", details: nil))
      return
    }
    Task {
      do {
        guard let product = try await Product.products(for: [productId]).first else {
          self.reply(result, FlutterError(code: "product_not_found", message: "商品不存在：\(productId)", details: nil))
          return
        }
        let purchaseResult = try await self.purchase(product)
        switch purchaseResult {
        case .success(let verification):
          let payload = Self.encode(verification)
          if case .verified(let tx) = verification {
            self.pendingTransactions["\(tx.id)"] = tx
          }
          self.reply(result, ["status": "success", "transaction": payload])
        case .userCancelled:
          self.reply(result, ["status": "cancelled"])
        case .pending:
          self.reply(result, ["status": "pending"])
        @unknown default:
          self.reply(result, ["status": "unknown"])
        }
      } catch {
        self.reply(result, FlutterError(code: "purchase_failed", message: error.localizedDescription, details: nil))
      }
    }
  }

  /// iOS 17+ 多窗口场景需显式指定 confirmIn，否则可能拿不到购买确认弹窗
  private func purchase(_ product: Product) async throws -> Product.PurchaseResult {
    if #available(iOS 17.0, *) {
      if let scene = await MainActor.run(body: { Self.activeScene() }) {
        return try await product.purchase(confirmIn: scene)
      }
    }
    return try await product.purchase()
  }

  // MARK: - 交易收尾

  private func handleFinishTransaction(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let id = args["transactionId"] as? String, !id.isEmpty else {
      reply(result, FlutterError(code: "bad_args", message: "缺少 transactionId", details: nil))
      return
    }
    if let tx = pendingTransactions.removeValue(forKey: id) {
      Task {
        await tx.finish()
        self.reply(result, ["finished": true])
      }
      return
    }
    // 缓存中没有（如进程重启后丢失引用）：从未完成交易中匹配
    Task {
      for await item in Transaction.unfinished {
        if case .verified(let tx) = item, "\(tx.id)" == id {
          await tx.finish()
          self.reply(result, ["finished": true])
          return
        }
      }
      self.reply(result, ["finished": false])
    }
  }

  // MARK: - 优惠代码兑换面板（Apple 官方 Offer Codes）

  private func handleOfferCodeSheet(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      if #available(iOS 16.0, *), let scene = Self.activeScene() {
        Task {
          do {
            try await AppStore.presentOfferCodeRedeemSheet(in: scene)
            self.reply(result, ["presented": true])
          } catch {
            self.reply(result, FlutterError(code: "offer_code_failed", message: error.localizedDescription, details: nil))
          }
        }
      } else {
        // iOS 15：使用兼容 API（iOS 14+ 可用）
        SKPaymentQueue.default().presentCodeRedemptionSheet()
        self.reply(result, ["presented": true])
      }
    }
  }

  // MARK: - 收据

  private func handleGetReceipt(result: @escaping FlutterResult) {
    if let data = Self.appReceiptData() {
      reply(result, ["receipt": data.base64EncodedString()])
      return
    }
    // 本地尚无收据（全新安装且从未产生交易）：主动刷新一次
    Self.refreshReceipt { data in
      self.reply(result, ["receipt": data?.base64EncodedString() ?? ""])
    }
  }

  fileprivate static func appReceiptData() -> Data? {
    guard let url = Bundle.main.appStoreReceiptURL,
          FileManager.default.fileExists(atPath: url.path) else { return nil }
    return try? Data(contentsOf: url)
  }

  private static func refreshReceipt(completion: @escaping (Data?) -> Void) {
    let helper = ReceiptRefreshHelper(completion: completion)
    let request = SKReceiptRefreshRequest()
    request.delegate = helper
    receiptRefreshHelper = helper
    request.start()
  }

  // MARK: - 工具

  private static func activeScene() -> UIWindowScene? {
    UIApplication.shared.connectedScenes
      .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
  }

  private static func encode(_ result: VerificationResult<Transaction>) -> [String: Any] {
    switch result {
    case .verified(let tx):
      var dict = encode(tx)
      dict["verified"] = true
      return dict
    case .unverified(let tx, let error):
      var dict = encode(tx)
      dict["verified"] = false
      dict["error"] = error.localizedDescription
      return dict
    }
  }

  private static func encode(_ tx: Transaction) -> [String: Any] {
    return [
      "transactionId": "\(tx.id)",
      "originalTransactionId": "\(tx.originalID)",
      "productId": tx.productID,
      "quantity": tx.purchasedQuantity,
      "environment": "\(tx.environment)",
      "jws": tx.jsonRepresentation.base64EncodedString(),
      "purchaseTime": tx.purchaseDate.timeIntervalSince1970 * 1000,
    ]
  }
}

/// 收据刷新回调桥接（SKReceiptRefreshRequest 不持有 delegate，需外部持有）
@available(iOS 15.0, *)
private final class ReceiptRefreshHelper: NSObject, SKRequestDelegate {
  private let completion: (Data?) -> Void

  init(completion: @escaping (Data?) -> Void) {
    self.completion = completion
  }

  func requestDidFinish(_ request: SKRequest) {
    completion(LumiraIapChannel.appReceiptData())
  }

  func request(_ request: SKRequest, didFailWithError error: Error) {
    completion(nil)
  }
}