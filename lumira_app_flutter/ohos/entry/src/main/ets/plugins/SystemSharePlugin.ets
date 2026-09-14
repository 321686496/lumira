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
import { systemShare } from '@kit.ShareKit';
import { fileUri } from '@kit.CoreFileKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { common, UIAbility } from '@kit.AbilityKit';

export default class SystemSharePlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private channel: MethodChannel | null = null;
  private uiAbility: UIAbility | null = null;

  getUniqueClassName(): string {
    return 'SystemSharePlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'lumira/system_share');
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
    switch (call.method) {
      case 'shareFiles':
        this.shareFiles(call, result);
        break;
      case 'shareText':
        this.shareText(call, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private async shareFiles(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      const paths = call.argument('paths') as string[];
      const text = call.argument('text') as string | null;
      if (!paths || paths.length === 0) {
        result.success({ success: false, error: 'path empty' });
        return;
      }

      const sharedData = new systemShare.SharedData({
        utd: uniformTypeDescriptor.UniformDataType.IMAGE,
        uri: fileUri.getUriFromPath(paths[0])
      });
      for (let index = 1; index < paths.length; index++) {
        sharedData.addRecord({
          utd: uniformTypeDescriptor.UniformDataType.IMAGE,
          uri: fileUri.getUriFromPath(paths[index])
        });
      }
      if (text && text.length > 0) {
        sharedData.addRecord({
          utd: uniformTypeDescriptor.UniformDataType.TEXT,
          content: text
        });
      }

      const controller = new systemShare.ShareController(sharedData);
      await controller.show(this.requireContext(), {
        previewMode: systemShare.SharePreviewMode.DETAIL,
        selectionMode: systemShare.SelectionMode.SINGLE
      });
      result.success({ success: true });
    } catch (e) {
      console.error(`[SystemSharePlugin] shareFiles failed: ${e}`);
      result.success({ success: false, error: String(e) });
    }
  }

  private async shareText(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      const text = call.argument('text') as string;
      if (!text) {
        result.success({ success: false, error: 'text empty' });
        return;
      }

      const sharedData = new systemShare.SharedData({
        utd: uniformTypeDescriptor.UniformDataType.TEXT,
        content: text
      });
      const controller = new systemShare.ShareController(sharedData);
      await controller.show(this.requireContext(), {
        previewMode: systemShare.SharePreviewMode.DETAIL,
        selectionMode: systemShare.SelectionMode.SINGLE
      });
      result.success({ success: true });
    } catch (e) {
      console.error(`[SystemSharePlugin] shareText failed: ${e}`);
      result.success({ success: false, error: String(e) });
    }
  }

  private requireContext(): common.UIAbilityContext {
    if (!this.uiAbility) {
      throw new Error('UIAbility context is unavailable');
    }
    return this.uiAbility.context;
  }
}
