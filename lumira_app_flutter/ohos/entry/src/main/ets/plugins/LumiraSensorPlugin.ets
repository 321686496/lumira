import { EventSink, StreamHandler } from '@ohos/flutter_ohos/src/main/ets/plugin/common/EventChannel';
import { Any, EventChannel, FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos';
import sensor from '@ohos.sensor';
import { BusinessError } from '@ohos.base';

/**
 * HarmonyOS 原生加速度传感器插件（水平仪）。
 *
 * 通过 EventChannel "lumira/level_sensor" 向 Flutter 推送加速度计原始数据，
 * 事件载荷为 [x, y, z]（单位 m/s²）。sensors_plus 无 ohos 实现，故自研此插件。
 *
 * 订阅/取消订阅跟随 Flutter 侧 StreamProvider.autoDispose 生命周期：
 * - onListen：sensor.on(ACCELEROMETER) 开始订阅
 * - onCancel：sensor.off(ACCELEROMETER) 停止（省电）
 *
 * ⚠️ 需在 module.json5 声明 ohos.permission.ACCELEROMETER（普通权限，自动授予）。
 */
export default class LumiraSensorPlugin implements FlutterPlugin, StreamHandler {
  private channel: EventChannel | null = null;
  private events: EventSink | null = null;

  getUniqueClassName(): string {
    return 'LumiraSensorPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new EventChannel(binding.getBinaryMessenger(), 'lumira/level_sensor');
    this.channel.setStreamHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.stopSensor();
    this.channel?.setStreamHandler(null);
    this.channel = null;
  }

  onListen(args: Any, events: EventSink): void {
    this.events = events;
    this.startSensor();
  }

  onCancel(args: Any): void {
    this.stopSensor();
    if (this.events) {
      this.events.endOfStream();
      this.events = null;
    }
  }

  /** 订阅加速度计，回调推送 [x, y, z] 到 Flutter。 */
  private startSensor(): void {
    try {
      sensor.on(sensor.SensorId.ACCELEROMETER, (data: sensor.AccelerometerResponse) => {
        if (!this.events) {
          return;
        }
        this.events.success([data.x, data.y, data.z]);
      }, { interval: 'ui' });
    } catch (err) {
      // 无传感器 / 权限受限：上报错误让 Flutter 侧降级为气泡回中
      const e = err as BusinessError;
      this.events?.error(e.code.toString(), e.message ?? 'accelerometer unavailable', null);
    }
  }

  /** 停止订阅加速度计。 */
  private stopSensor(): void {
    try {
      sensor.off(sensor.SensorId.ACCELEROMETER);
    } catch (e) {
      // 忽略：卸载时传感器可能已不可用
    }
  }
}
