
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { Want, AbilityConstant } from '@kit.AbilityKit';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import PhotoSaverPlugin from '../plugins/PhotoSaverPlugin';
import FileReaderPlugin from '../plugins/FileReaderPlugin';
import DeepLinkPlugin from '../plugins/DeepLinkPlugin';

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    // 注册原生照片保存插件（saver_gallery 不支持 HarmonyOS）
    flutterEngine.getPlugins()?.add(new PhotoSaverPlugin());
    // 注册原生文件读取插件（file_picker_ohos 返回截断数据，dart:io File 在 OHOS 上可能失败）
    flutterEngine.getPlugins()?.add(new FileReaderPlugin());
    // 注册原生深链插件（uni_links 无 ohos 实现）
    flutterEngine.getPlugins()?.add(new DeepLinkPlugin());
  }

  // ⚠️ best-effort：flutter_ohos 的 onCreate 返回 Promise，须以 async 方式重写；
  // super.onCreate 会 attach 插件并读取 latestLaunchUri，故先记录 uri 再调用。
  override async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    DeepLinkPlugin.notifyNewLink(this.extractUri(want));
    await super.onCreate(want, launchParam);
  }

  override onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onNewWant(want, launchParam);
    DeepLinkPlugin.notifyNewLink(this.extractUri(want));
  }

  private extractUri(want: Want): string {
    // 从 want 中取 uri 字段（深链 want 的 uri 在 want.uri）
    const uri: string | undefined = want.uri;
    return (uri && uri.length > 0) ? uri : '';
  }
}
