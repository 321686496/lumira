import sensor from '@ohos.sensor';
import display from '@ohos.display';
import { SensorOrientation } from '../sensors/SensorOrientation';
import { BusinessError } from '@ohos.base';
import { camera } from '@kit.CameraKit';
import window from '@ohos.window';


export class OrientationStreamListener {
  private currentOrientation: number = 0;
  private listeners: SensorOrientation[] = [];
  private lastOrientation: number = 0;
  private _windowStatusType: window.WindowStatusType = window.WindowStatusType.UNDEFINED;
  // 记录上一次执行 realData 的时间
  private lastExecutionTime: number = 0;
  private _isSensorActive: boolean = true;

  constructor(listeners: SensorOrientation[]) {
    this.listeners = listeners;
    this.initOrientationSensor();
  }

  public set windowStatusType(windowStatusType: window.WindowStatusType) {
    this._windowStatusType = windowStatusType;
  }

  private initOrientationSensor(): void {

    sensor.getSensorList((error: BusinessError, sensors: Array<sensor.Sensor>) => {
      if (error) {
        console.error("Get getSensorList data error, error:" + error.data, ", msg:", error.message);
      } else {
        let isSupported = false;
        for (let i = 0; i < sensors.length; i++) {
          if (sensors[i].sensorId === sensor.SensorId.GRAVITY) {
            isSupported = true;
            break;
          }
        }

        if (isSupported === true) {
          try {
            sensor.on(sensor.SensorId.GRAVITY, (data: sensor.GravityResponse) => {
              this.realData(data);
            }, { interval: 'ui' });
          } catch (error) {
            console.error("Get sensor.SensorId.GRAVITY data error, error:" + error.data, ", msg:", error.message);
          }
        } else {
          try {
            sensor.on(sensor.SensorId.ACCELEROMETER, (data: sensor.AccelerometerResponse) => {
              this.realData(data as sensor.GravityResponse);
            }, { interval: 'ui' });
          } catch (error) {
            console.error("Get sensor.SensorId.ACCELEROMETER data error, error:" + error.data, ", msg:", error.message);
          }
        }
      }
    });
  }

  private realData(data: sensor.GravityResponse): void {
    if (!this._isSensorActive) {
      return;
    }
    const now = Date.now();
    if (now - this.lastExecutionTime < 500) {
      return;
    }
    this.lastExecutionTime = now;

    const displayRotation = display.getDefaultDisplaySync().rotation;
    const isLandscape = (this._windowStatusType == window.WindowStatusType.FLOATING ||
      this._windowStatusType == window.WindowStatusType.SPLIT_SCREEN) &&
      (displayRotation === display.Orientation.LANDSCAPE || displayRotation === display.Orientation.LANDSCAPE_INVERTED);

    if (isLandscape) {
      this.currentOrientation = 0;
      this.lastOrientation = 0;
    } else {
      const degree = this.calDegree(data);
      let newOrientation = 0;
      if (degree !== -1) {
        if (degree >= 0 && (degree <= 30 || degree >= 330)) {
          newOrientation = camera.ImageRotation.ROTATION_0;
        } else if (degree >= 65 && degree <= 120) {
          newOrientation = camera.ImageRotation.ROTATION_90;
        } else if (degree >= 150 && degree <= 210) {
          newOrientation = camera.ImageRotation.ROTATION_180;
        } else if (degree >= 245 && degree <= 300) {
          newOrientation = camera.ImageRotation.ROTATION_270;
        }

        if (displayRotation === display.Orientation.LANDSCAPE ||
          displayRotation === display.Orientation.LANDSCAPE_INVERTED ||
          displayRotation === display.Orientation.PORTRAIT_INVERTED) {
          let landscapeOrientation = 0;
          if (displayRotation === display.Orientation.LANDSCAPE) {
            landscapeOrientation = newOrientation - camera.ImageRotation.ROTATION_90;
          } else if (displayRotation === display.Orientation.LANDSCAPE_INVERTED) {
            landscapeOrientation = newOrientation + camera.ImageRotation.ROTATION_90;
          } else if (displayRotation === display.Orientation.PORTRAIT_INVERTED) {
            landscapeOrientation = newOrientation + camera.ImageRotation.ROTATION_180;
          }
          if (landscapeOrientation > camera.ImageRotation.ROTATION_270 || landscapeOrientation < 0) {
            newOrientation = 0;
          } else {
            newOrientation = landscapeOrientation;
          }
        }

        this.currentOrientation = newOrientation;
        this.lastOrientation = newOrientation;
      } else {
        this.currentOrientation = this.lastOrientation;
      }
    }
    this.listeners.forEach(listener => {
      listener.onOrientationChanged(this.currentOrientation);
    });
  }

  calDegree(data: sensor.GravityResponse): number {
    const x = data.x;
    const y = data.y;
    const z = data.z;

    let degree: number = -1;
    // 3为有效_增量_角度_阈值_系数
    const isDeviceHorizontal = (x * x + y * y) * 3 < z * z;
    if (isDeviceHorizontal) {
      return degree;
    }
    degree = 90 - (Number)(Math.round(Math.atan2(y, -x) / Math.PI * 180));
    return degree >= 0 ? degree % 360 : degree % 360 + 360;
  }

  public offSensor() {
    this._isSensorActive = false;
    try {
      sensor.off(sensor.SensorId.GRAVITY);
      sensor.off(sensor.SensorId.ACCELEROMETER);
    } catch (e) {
    }
  }

  public onSensor() {
    this._isSensorActive = true;
    this.initOrientationSensor();
  }
}