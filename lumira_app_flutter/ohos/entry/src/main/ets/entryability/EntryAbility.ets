
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import PhotoSaverPlugin from '../plugins/PhotoSaverPlugin';

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    // 注册原生照片保存插件（saver_gallery 不支持 HarmonyOS）
    flutterEngine.getPlugins()?.add(new PhotoSaverPlugin());
  }
}
