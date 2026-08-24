import { EventSink, StreamHandler } from "@ohos/flutter_ohos/src/main/ets/plugin/common/EventChannel";
import { Any } from "@ohos/flutter_ohos";
import { DisplayRotation } from "./DisplayRotation";
import Logger from '../utils/Logger';

export class DisplayRotationListener implements StreamHandler, DisplayRotation {
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

  onRotationChanged(rotation: number): void {
    if (!this.events) {
      return
    }
    switch (rotation) {
      case 0:
        this.events.success("PORTRAIT");
        break;
      case 1:
        this.events.success("LANDSCAPE");
        break;
      case 2:
        this.events.success("PORTRAIT_INVERTED");
        break;
      case 3:
        this.events.success("LANDSCAPE_INVERTED");
        break;
    }
  }
}