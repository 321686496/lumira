import {
  FlutterPlugin,
  FlutterPluginBinding,
  AbilityAware,
  AbilityPluginBinding
} from '@ohos/flutter_ohos';
import MethodChannel, {
  MethodCallHandler,
  MethodResult
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { common, UIAbility } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * HarmonyOS 原生扫码插件（Scan Kit 系统扫码界面）。
 * 通过 MethodChannel "lumira/scan" 与 Flutter 层通信。
 *
 * 能力：
 * - startScan：启动 Scan Kit 默认扫码界面（scanBarcode.startScanForResult），
 *   相机权限由系统扫码界面预授权，调用期间处于安全访问状态，无需应用自行申请；
 *   扫码界面自带相册识码入口（enableAlbum: true）。
 *
 * 方法：startScan
 * - 成功：result.success(originalValue)
 * - 用户取消（错误码 1000500002）：result.error('USER_CANCELED', '用户取消扫码', null)
 * - 启动/识别失败：result.error('SCAN_FAILED', ...)
 */
export default class ScanPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private channel: MethodChannel | null = null;
  private uiAbility: UIAbility | null = null;

  getUniqueClassName(): string {
    return 'ScanPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'lumira/scan');
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.uiAbility = binding.getAbility();
  }

  onDetachedFromAbility(): void {
    this.uiAbility = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method === 'startScan') {
      this.startScan(result);
    } else {
      result.notImplemented();
    }
  }

  /// 启动系统扫码界面
  private startScan(result: MethodResult): void {
    try {
      const options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.ALL],
        enableMultiMode: true,
        enableAlbum: true,
      };
      scanBarcode.startScanForResult(this.uiAbility!.context, options,
        (err: BusinessError, data: scanBarcode.ScanResult) => {
          if (err) {
            console.error(`[Lumira] ScanKit 扫码失败: code=${err.code}, msg=${err.message}`);
            // 1000500002：用户取消扫码
            if (err.code === 1000500002) {
              result.error('USER_CANCELED', '用户取消扫码', null);
            } else {
              result.error('SCAN_FAILED', `code=${err.code}, msg=${err.message}`, null);
            }
            return;
          }
          const raw: string = data.originalValue;
          console.info(`[Lumira] ScanKit 扫码成功, len=${raw.length}`);
          result.success(raw);
        });
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      console.error(`[Lumira] ScanKit 启动扫码异常: code=${err.code}, msg=${err.message}`);
      result.error('SCAN_FAILED', `code=${err.code}, msg=${err.message}`, null);
    }
  }
}
