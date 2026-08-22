import { EventSink, StreamHandler } from "@ohos/flutter_ohos/src/main/ets/plugin/common/EventChannel";
import { SensorOrientation } from './SensorOrientation';
import { Any } from "@ohos/flutter_ohos";

export class SensorOrientationListener implements StreamHandler, SensorOrientation {
  private events: EventSink | null = null;

  onListen(args: Any, events: EventSink): void {
    this.events = events;
  }

  onCancel(args: Any): void {
    if (this.events) {
      this.events.endOfStream();
      this.events = null;
    }
  }

  onOrientationChanged(orientation: number): void {
    if (!this.events) {
      return;
    }

    switch (orientation) {
      case 0:
        this.events.success("PORTRAIT_UP");
        break;
      case 90:
        this.events.success("LANDSCAPE_LEFT");
        break;
      case 180:
        this.events.success("PORTRAIT_DOWN");
        break;
      case 270:
        this.events.success("LANDSCAPE_RIGHT");
        break;
    }
  }
}