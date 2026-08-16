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
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common, abilityAccessCtrl, Permissions, UIAbility } from '@kit.AbilityKit';
import { BusinessError } from '@ohos.base';

/**
 * HarmonyOS 原生照片保存插件
 * 通过 MethodChannel "lumira/photo_saver" 与 Flutter 层通信
 * 使用 photoAccessHelper API 将照片保存到系统相册
 *
 * 修复：createAsset 是媒体库特权接口，需要 WRITE_IMAGEVIDEO 权限（user_grant）。
 * 在保存前通过 abilityAccessCtrl.requestPermissionsFromUser 请求用户授权。
 */
export default class PhotoSaverPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private context: common.Context | null = null;
  private channel: MethodChannel | null = null;
  private uiAbility: UIAbility | null = null;

  getUniqueClassName(): string {
    return 'PhotoSaverPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.context = binding.getApplicationContext();
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'lumira/photo_saver');
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
    this.context = null;
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.uiAbility = binding.getAbility();
  }

  onDetachedFromAbility(): void {
    this.uiAbility = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'saveToAlbum':
        this.saveToAlbum(call, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  /**
   * 请求 WRITE_IMAGEVIDEO 权限
   * 返回 true 表示已授权
   */
  private async ensureWritePermission(): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const permissions: Array<Permissions> = ['ohos.permission.WRITE_IMAGEVIDEO'];
      const reqResult = await atManager.requestPermissionsFromUser(this.uiAbility!.context, permissions);
      for (const auth of reqResult.authResults) {
        if (auth === 0) return true;
      }
      return false;
    } catch (e) {
      const err = e as BusinessError;
      console.error(`[PhotoSaver] requestPermissions failed: ${err.code} ${err.message}`);
      return false;
    }
  }

  /**
   * 将本地文件保存到系统相册
   * 参数: { path: string } - 本地文件路径
   * 返回: { success: boolean, error?: string }
   */
  private async saveToAlbum(call: MethodCall, result: MethodResult) {
    try {
      const srcPath: string = call.argument('path');
      if (!srcPath) {
        result.success({ success: false, error: '路径为空' });
        return;
      }

      // 1. 请求 WRITE_IMAGEVIDEO 权限（user_grant）
      const granted = await this.ensureWritePermission();
      if (!granted) {
        result.success({ success: false, error: '用户未授权写入媒体库' });
        return;
      }

      // 2. 读取源文件
      const srcFile = fs.openSync(srcPath, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(srcFile.fd);
      const buffer = new ArrayBuffer(stat.size);
      fs.readSync(srcFile.fd, buffer);
      fs.closeSync(srcFile);

      // 3. 获取 PhotoAccessHelper 并创建图片资源
      // 注意：getPhotoAccessHelper 需要 UIAbility context（而非 application context），
      // 否则返回 undefined，导致 createAsset 调用失败。
      if (!this.uiAbility) {
        result.success({ success: false, error: '未获取到 UIAbility 上下文（onAttachedToAbility 未触发）' });
        return;
      }
      const helper = photoAccessHelper.getPhotoAccessHelper(this.uiAbility.context);
      if (!helper) {
        result.success({ success: false, error: 'getPhotoAccessHelper 返回 undefined，请检查传入的 context 是否为 UIAbility context' });
        return;
      }
      const uri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg');
      const destFile = fs.openSync(uri, fs.OpenMode.WRITE_ONLY);
      fs.writeSync(destFile.fd, buffer);
      fs.closeSync(destFile);

      result.success({ success: true });
    } catch (e) {
      const err = e as Error;
      result.success({ success: false, error: err.message || String(e) });
    }
  }
}
