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
import { fileIo as fs } from '@kit.CoreFileKit';
import { common, UIAbility } from '@kit.AbilityKit';
import { BusinessError } from '@ohos.base';

/**
 * HarmonyOS 原生文件读取插件
 *
 * 通过 MethodChannel "lumira/file_reader" 与 Flutter 层通信。
 *
 * 解决问题：
 * file_picker_ohos 原生端 FileUtils.loadData 只读取前 4096 字节，
 * 而 dart:io File.readAsBytes() 在 OHOS 上可能因路径格式或权限问题失败。
 * 本插件使用 OHOS 原生 fileIo API 直接读取文件完整字节，作为 ensureFullBytes 的兜底方案。
 */
export default class FileReaderPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private context: common.Context | null = null;
  private channel: MethodChannel | null = null;
  private uiAbility: UIAbility | null = null;

  getUniqueClassName(): string {
    return 'FileReaderPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.context = binding.getApplicationContext();
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'lumira/file_reader');
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
      case 'readBytes':
        this.readBytes(call, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  /**
   * 读取文件完整字节
   * 参数: { path: string } - 文件路径（沙箱路径或 file:// URI）
   * 返回: Uint8Array - 文件完整字节内容
   */
  private async readBytes(call: MethodCall, result: MethodResult) {
    let filePath: string = call.argument('path');
    if (!filePath || filePath.length === 0) {
      result.error('invalid_path', 'File path is null or empty', null);
      return;
    }

    // 去除 file:// 前缀（dart:io File 不支持 URI scheme，但 OHOS fs.openSync 支持）
    // 保留原始路径供 fs.openSync 使用，它能处理 file:// 格式
    let openPath = filePath;
    if (!openPath.startsWith('file://') && !openPath.startsWith('/')) {
      // 相对路径，拼接沙箱前缀
      openPath = this.context?.filesDir + '/' + openPath;
    }

    let file: fs.File | null = null;
    try {
      file = fs.openSync(openPath, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      const size = stat.size;

      if (size === 0) {
        fs.closeSync(file);
        result.error('empty_file', 'File is empty', null);
        return;
      }

      // 分块读取完整文件内容
      const buffer = new ArrayBuffer(size);
      let totalRead = 0;
      while (totalRead < size) {
        const bytesRead = fs.readSync(file.fd, buffer, {
          offset: totalRead,
          length: size - totalRead
        });
        if (bytesRead <= 0) break;
        totalRead += bytesRead;
      }

      fs.closeSync(file);
      file = null;

      if (totalRead === 0) {
        result.error('read_failed', 'Failed to read any bytes from file', null);
        return;
      }

      // 返回 Uint8Array
      const bytes = new Uint8Array(buffer, 0, totalRead);
      result.success(bytes);
    } catch (e) {
      if (file) {
        try { fs.closeSync(file); } catch (_) {}
      }
      const err = e as BusinessError;
      console.error(`[FileReader] readBytes failed: path=${openPath}, code=${err.code}, msg=${err.message}`);
      result.error('read_error', `Failed to read file: ${err.message || String(e)}`, null);
    }
  }
}
