import { EventSink, StreamHandler } from "@ohos/flutter_ohos/src/main/ets/plugin/common/EventChannel";
import { Any } from "@ohos/flutter_ohos";
import Logger from '../utils/Logger';

export class CameraDeviceChangeListener implements StreamHandler{
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

  onChanged(cameraPosition: string): void {
    if (!this.events) {
      return
    }
    Logger.debug("DisplayRotationListener",`onChanged cameraPosition:${cameraPosition}`)
    this.events.success(cameraPosition);
  }
}