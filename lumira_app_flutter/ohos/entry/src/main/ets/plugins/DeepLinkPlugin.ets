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

/**
 * HarmonyOS 原生深链插件。
 * 通过 MethodChannel "lumira/deep_link" 与 Flutter 层通信。
 *
 * 能力：
 * - getInitialLink：返回 Ability 冷启动时携带的 lumira:// uri。
 *
 * ⚠️ best-effort：flutter_ohos 引擎对 onNewWant / want 透传的支持需真机验证；
 * 若受限，仅 getInitialLink（冷启动）生效，热启动自动拉起降级为「App 内手动粘贴」
 * （粘贴导入通路已由 TemplateShareCode/TemplateImportService 保证，不阻塞其余功能）。
 */
export default class DeepLinkPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private channel: MethodChannel | null = null;
  private pendingLink: string | null = null;
  // 记录 EntryAbility 启动/热启动时收到的 uri（插件在 configureFlutterEngine 中创建，晚于 onCreate）
  static latestLaunchUri: string | null = null;

  getUniqueClassName(): string {
    return 'DeepLinkPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'lumira/deep_link');
    this.channel.setMethodCallHandler(this);
    // 冷启动 want 在 onCreate 时已记录
    if (DeepLinkPlugin.latestLaunchUri) {
      this.pendingLink = DeepLinkPlugin.latestLaunchUri;
    }
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    // 无额外处理；uri 通过静态 latestLaunchUri 传递
  }

  onDetachedFromAbility(): void {
    // 无额外处理
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'getInitialLink':
        result.success(this.pendingLink ?? '');
        this.pendingLink = null;
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  /** 由 EntryAbility 在收到启动/热启动 want 时调用，记录 uri */
  static notifyNewLink(uri: string): void {
    DeepLinkPlugin.latestLaunchUri = uri;
  }
}
