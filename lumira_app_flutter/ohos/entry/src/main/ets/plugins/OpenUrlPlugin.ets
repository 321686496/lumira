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
import { common, UIAbility } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * HarmonyOS 原生链接打开插件（绉 url_launcher 在 OHOS 无原生实现，
 * 改为使用 HarmonyOS 应用间跳转能力 uiAbility.context.openLink 拉起系统浏览器）。
 * 通过 MethodChannel "lumira/open_url" 与 Flutter 层通信。
 *
 * 方法：openUrl
 * - 参数：{ url: string }
 * - 成功：result.success({ success: true })
 * - 失败：result.success({ success: false, error: '...' })
 *
 * openLink（API 12+）说明：
 * - 传入 http/https 链接等，由系统选择合适的浏览器应用打开；
 * - 若系统中无匹配应用，结果 LinkResult.code 为非 0；
 * - 该接口为拉起指定应用（浏览器）的推荐方式，见官方「应用间跳转」文档。
 */
export default class OpenUrlPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private channel: MethodChannel | null = null;
  private uiAbility: UIAbility | null = null;

  getUniqueClassName(): string {
    return 'OpenUrlPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'lumira/open_url');
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
    if (call.method === 'openUrl') {
      this.openUrl(call, result);
    } else {
      result.notImplemented();
    }
  }

  /// 用系统浏览器打开外部链接（context.openLink）
  private openUrl(call: MethodCall, result: MethodResult): void {
    const raw = call.argument('url') as string | null;
    if (!raw || raw.length === 0) {
      result.success({ success: false, error: 'url empty' });
      return;
    }
    const uri = raw.startsWith('http://') || raw.startsWith('https://') ? raw : `https://${raw}`;
    try {
      const context = this.requireContext();
      const options: common.OpenLinkOptions = { appLinkingOnly: false };
      // openLink 结果回调：LinkResult.code 为 0 表示成功
      context.openLink(uri, options, (err: BusinessError, data: common.LinkResult) => {
        if (err) {
          console.error(`[OpenUrlPlugin] openLink error: code=${err.code}, msg=${err.message}`);
          result.success({ success: false, error: `code=${err.code}, msg=${err.message}` });
          return;
        }
        if (data.code === 0) {
          console.info(`[OpenUrlPlugin] openLink success: ${uri}`);
          result.success({ success: true });
        } else {
          console.error(`[OpenUrlPlugin] openLink result code=${data.code}`);
          result.success({ success: false, error: `code=${data.code}` });
        }
      });
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      console.error(`[OpenUrlPlugin] openUrl exception: code=${err.code}, msg=${err.message}`);
      result.success({ success: false, error: `code=${err.code}, msg=${err.message}` });
    }
  }

  private requireContext(): common.UIAbilityContext {
    if (!this.uiAbility) {
      throw new Error('UIAbility context is unavailable');
    }
    return this.uiAbility.context;
  }
}