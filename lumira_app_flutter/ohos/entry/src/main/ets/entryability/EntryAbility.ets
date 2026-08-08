
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import PhotoSaverPlugin from '../plugins/PhotoSaverPlugin';
import FileReaderPlugin from '../plugins/FileReaderPlugin';

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    // 注册原生照片保存插件（saver_gallery 不支持 HarmonyOS）
    flutterEngine.getPlugins()?.add(new PhotoSaverPlugin());
    // 注册原生文件读取插件（file_picker_ohos 返回截断数据，dart:io File 在 OHOS 上可能失败）
    flutterEngine.getPlugins()?.add(new FileReaderPlugin());
  }
}
