// lumira-server/packages/backend/src/modules/points/iap.service.ts

import { Injectable, BadRequestException, ServiceUnavailableException } from '@nestjs/common';

/**
 * iOS 消耗型积分包商品 id → 到账积分（服务端真值源）。
 * 必须与客户端 kRechargeTiers（lib/features/points/data/points_recharge.dart）的
 * iosProductId / totalPoints 保持一致，防止客户端篡改「商品 ↔ 积分」对应关系。
 */
export const IAP_PRODUCT_POINTS: Record<string, number> = {
  'com.rh.lumira.points.600': 600,
  'com.rh.lumira.points.3300': 3300,
  'com.rh.lumira.points.7800': 7800,
  'com.rh.lumira.points.15300': 15300,
  'com.rh.lumira.points.42800': 42800,
};

// Apple 收据校验端点（生产 / 沙盒）
const APPLE_PROD_URL = 'https://buy.itunes.apple.com/verifyReceipt';
const APPLE_SANDBOX_URL = 'https://sandbox.itunes.apple.com/verifyReceipt';

// Apple 状态码：沙盒收据被发到了生产端点，需改用沙盒端点重试
const APPLE_STATUS_SANDBOX_RECEIPT = 21007;

interface AppleInAppItem {
  transaction_id?: string;
  original_transaction_id?: string;
  product_id?: string;
  quantity?: string;
}

interface AppleVerifyReceiptResponse {
  status?: number;
  environment?: string;
  receipt?: { in_app?: AppleInAppItem[]; bundle_id?: string };
}

export interface IapVerificationResult {
  productId: string;
  transactionId: string;
  points: number;
  environment: string;
}

/**
 * iOS App 内购买收据校验（StoreKit verifyReceipt）。
 *
 * 说明：verifyReceipt 已被 Apple 标记为软弃用，但仍在提供服务且未公布 EOL；
 * 为降低迁移成本，校验实现被隔离在本 service 内，日后可平滑切到 App Store Server API。
 * 仅 iOS 客户端会调用该链路，Android / OHOS 不受影响。
 */
@Injectable()
export class IapService {
  /**
   * 校验收据并返回该笔交易应发放的积分。
   * 任一步骤失败均抛错（不发奖），保证只有 Apple 确认过的交易才会到账。
   */
  async verify(
    receipt: string,
    productId: string,
    transactionId: string,
  ): Promise<IapVerificationResult> {
    const sharedSecret = process.env.APPLE_IAP_SHARED_SECRET;
    if (!sharedSecret) {
      throw new ServiceUnavailableException('APPLE_IAP_SHARED_SECRET is not configured');
    }

    const unitPoints = IAP_PRODUCT_POINTS[productId];
    if (!unitPoints) {
      throw new BadRequestException(`Unknown IAP product: ${productId}`);
    }

    let result = await this.postVerify(APPLE_PROD_URL, receipt, sharedSecret);
    // 21007：沙盒收据被发到生产端点 → 改发沙盒端点
    if (result.status === APPLE_STATUS_SANDBOX_RECEIPT) {
      result = await this.postVerify(APPLE_SANDBOX_URL, receipt, sharedSecret);
    }
    if (result.status !== 0) {
      throw new BadRequestException(`Apple receipt verification failed (status=${result.status})`);
    }

    const inApp = result.receipt?.in_app ?? [];
    const matched = inApp.find((item) => item.transaction_id === transactionId);
    if (!matched) {
      throw new BadRequestException('Transaction not found in receipt');
    }
    if (matched.product_id !== productId) {
      throw new BadRequestException('Product id mismatch in receipt');
    }

    const quantity = Math.max(parseInt(matched.quantity ?? '1', 10) || 1, 1);
    return {
      productId,
      transactionId,
      points: unitPoints * quantity,
      environment: result.environment ?? 'Production',
    };
  }

  private async postVerify(
    url: string,
    receipt: string,
    sharedSecret: string,
  ): Promise<AppleVerifyReceiptResponse> {
    let resp: Awaited<ReturnType<typeof fetch>>;
    try {
      resp = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          'receipt-data': receipt,
          password: sharedSecret,
          'exclude-old-transactions': true,
        }),
      });
    } catch (e) {
      throw new ServiceUnavailableException(`Apple verifyReceipt request failed: ${String(e)}`);
    }
    if (!resp.ok) {
      throw new ServiceUnavailableException(`Apple verifyReceipt HTTP ${resp.status}`);
    }
    return (await resp.json()) as AppleVerifyReceiptResponse;
  }
}