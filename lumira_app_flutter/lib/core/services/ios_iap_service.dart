import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

/// 内购商品（由 StoreKit 返回，价格文案直接使用 [displayPrice]）
class IapProduct {
  const IapProduct({
    required this.id,
    required this.displayName,
    required this.description,
    required this.displayPrice,
  });

  final String id;
  final String displayName;
  final String description;
  final String displayPrice;

  static IapProduct? fromMap(Map<dynamic, dynamic> map) {
    final id = map['id'];
    if (id is! String || id.isEmpty) return null;
    return IapProduct(
      id: id,
      displayName: map['displayName'] as String? ?? '',
      description: map['description'] as String? ?? '',
      displayPrice: map['displayPrice'] as String? ?? '',
    );
  }
}

/// 一笔 StoreKit 交易（购买成功回调 / 补单 / App 外兑换优惠代码）
class IapTransaction {
  const IapTransaction({
    required this.transactionId,
    required this.originalTransactionId,
    required this.productId,
    required this.verified,
    required this.quantity,
    this.error,
  });

  final String transactionId;
  final String originalTransactionId;
  final String productId;

  /// StoreKit 签名校验是否通过（未通过不应发奖）
  final bool verified;
  final int quantity;
  final String? error;

  static IapTransaction? fromMap(Map<dynamic, dynamic> map) {
    final id = map['transactionId'];
    final productId = map['productId'];
    if (id is! String || id.isEmpty) return null;
    if (productId is! String || productId.isEmpty) return null;
    return IapTransaction(
      transactionId: id,
      originalTransactionId: map['originalTransactionId'] as String? ?? '',
      productId: productId,
      verified: map['verified'] as bool? ?? false,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      error: map['error'] as String?,
    );
  }
}

/// 购买结果状态
enum IapPurchaseStatus { success, cancelled, pending, unknown }

class IapPurchaseResult {
  const IapPurchaseResult(this.status, [this.transaction]);

  final IapPurchaseStatus status;
  final IapTransaction? transaction;

  static IapPurchaseResult fromMap(Map<dynamic, dynamic> map) {
    final raw = map['status'] as String? ?? 'unknown';
    final txMap = map['transaction'];
    final tx = txMap is Map ? IapTransaction.fromMap(txMap) : null;
    switch (raw) {
      case 'success':
        return IapPurchaseResult(IapPurchaseStatus.success, tx);
      case 'cancelled':
        return IapPurchaseResult(IapPurchaseStatus.cancelled);
      case 'pending':
        return IapPurchaseResult(IapPurchaseStatus.pending);
      default:
        return const IapPurchaseResult(IapPurchaseStatus.unknown);
    }
  }
}

/// 后端校验结果
class IapVerifyResult {
  const IapVerifyResult({
    required this.granted,
    required this.points,
    required this.balance,
  });

  /// 本次是否新发放（false 表示该交易此前已发放，幂等命中）
  final bool granted;
  final int points;
  final int balance;

  static IapVerifyResult fromMap(Map<dynamic, dynamic> map) {
    return IapVerifyResult(
      granted: map['granted'] as bool? ?? false,
      points: (map['points'] as num?)?.toInt() ?? 0,
      balance: (map['balance'] as num?)?.toInt() ?? 0,
    );
  }
}

/// iOS App 内购买（StoreKit）封装。
///
/// **严格门控**：只有 iOS 才启用；Android / OHOS / Web 一律短路（[isSupported] 为 false），
/// 不注册通道、不发起任何调用，保证不影响其他平台的既有能力。
///
/// 发奖链路：native 购买/监听 → 本 service 携带收据调后端 /points/iap/verify 校验 →
/// 后端幂等发积分 → 成功后回传 native finishTransaction 收尾。
class IosIapService {
  IosIapService(this._api) {
    if (!IosIapService.isSupported) return;
    _channel.setMethodCallHandler(_onNativeCall);
  }

  static const MethodChannel _channel = MethodChannel('lumira/iap');

  /// 只有 iOS 原生平台返回 true（Web 上 Platform 不可用，需先短路）
  static bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isIOS;
  }

  final ApiClient _api;

  final StreamController<IapTransaction> _txController =
      StreamController<IapTransaction>.broadcast();

  /// 交易流：包含购买成功、补单、以及用户通过 Apple 优惠代码兑换产生的交易
  Stream<IapTransaction> get transactions => _txController.stream;

  void dispose() {
    _txController.close();
  }

  Future<void> _onNativeCall(MethodCall call) async {
    if (call.method != 'onTransaction') return;
    final map = _asMap(call.arguments);
    if (map == null) return;
    final tx = IapTransaction.fromMap(map);
    if (tx != null) _txController.add(tx);
  }

  /// 拉取商品（价格文案由 StoreKit 提供，避免与 App Store 定价不一致）
  Future<List<IapProduct>> loadProducts(List<String> ids) async {
    if (!isSupported || ids.isEmpty) return const <IapProduct>[];
    final raw = await _channel.invokeMethod<dynamic>('getProducts', {'ids': ids});
    final map = _asMap(raw);
    final list = map?['products'];
    if (list is! List) return const <IapProduct>[];
    final result = <IapProduct>[];
    for (final item in list) {
      if (item is Map) {
        final product = IapProduct.fromMap(item);
        if (product != null) result.add(product);
      }
    }
    return result;
  }

  /// 发起购买。返回 success 时需调用 [deliver] 完成发奖与收尾。
  Future<IapPurchaseResult> purchase(String productId) async {
    if (!isSupported) {
      return const IapPurchaseResult(IapPurchaseStatus.unknown);
    }
    final raw = await _channel.invokeMethod<dynamic>('purchase', {'id': productId});
    final map = _asMap(raw);
    if (map == null) return const IapPurchaseResult(IapPurchaseStatus.unknown);
    return IapPurchaseResult.fromMap(map);
  }

  /// 展示 Apple 官方「优惠代码」兑换面板（Offer Codes，非自建兑换码）
  Future<void> presentOfferCodeSheet() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('presentOfferCodeSheet');
  }

  /// 送后端校验并发积分；成功后 finish 交易，避免重复补单。
  Future<IapVerifyResult> deliver(IapTransaction tx) async {
    final receipt = await _fetchReceipt();
    final result = await _api.post(
      '/points/iap/verify',
      body: {
        'productId': tx.productId,
        'transactionId': tx.transactionId,
        'receipt': receipt,
      },
      fromJson: (json) => IapVerifyResult.fromMap(_asMap(json) ?? const {}),
    );
    // 无论本次是否新发放（幂等命中），该交易都已落库，可以安全 finish
    await finishTransaction(tx.transactionId);
    return result;
  }

  Future<void> finishTransaction(String transactionId) async {
    if (!isSupported) return;
    try {
      await _channel
          .invokeMethod<void>('finishTransaction', {'transactionId': transactionId});
    } on PlatformException catch (e) {
      debugPrint('[ios_iap] finishTransaction 失败: ${e.message}');
    }
  }

  Future<String> _fetchReceipt() async {
    if (!isSupported) return '';
    try {
      final raw = await _channel.invokeMethod<dynamic>('getReceipt');
      return _asMap(raw)?['receipt'] as String? ?? '';
    } on PlatformException catch (e) {
      debugPrint('[ios_iap] getReceipt 失败: ${e.message}');
      return '';
    }
  }

  static Map<dynamic, dynamic>? _asMap(Object? value) {
    if (value is Map) return value;
    return null;
  }
}

final iosIapServiceProvider = FutureProvider<IosIapService>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  final service = IosIapService(api);
  ref.onDispose(service.dispose);
  return service;
});

/// 统一入口：打开 App Store 官方「优惠 / 促销代码」兑换面板（仅 iOS）。
///
/// App 内各「兑换码」入口在 iOS 上统一调用此函数：不再使用自建兑换码，
/// 而是走 Apple 官方兑换面板（App Store 3.1.1 认可的替代方案）。
/// 非 iOS 直接返回 false，调用方据此保留原有自建兑换码流程。
/// 返回 false 也可能表示面板打开失败，调用方可自行提示。
Future<bool> presentIosOfferCodeSheet(WidgetRef ref) async {
  if (!IosIapService.isSupported) return false;
  try {
    final service = await ref.read(iosIapServiceProvider.future);
    await service.presentOfferCodeSheet();
    return true;
  } catch (_) {
    return false;
  }
}

/// 启动即挂上交易监听（iOS 专用）。
///
/// 覆盖两类场景：用户在 App 外兑换了优惠代码、以及上次未完成交易的补单。
/// 非 iOS 平台直接返回，不做任何事。
Future<void> startIosIapTransactionListener(
  ProviderContainer container, {
  void Function(IapVerifyResult result)? onDelivered,
}) async {
  if (!IosIapService.isSupported) return;
  final service = await container.read(iosIapServiceProvider.future);
  service.transactions.listen((tx) async {
    if (!tx.verified) return; // 签名校验未通过，不发奖
    try {
      final result = await service.deliver(tx);
      onDelivered?.call(result);
    } catch (e) {
      debugPrint('[ios_iap] 交易补单失败: $e');
    }
  });
}