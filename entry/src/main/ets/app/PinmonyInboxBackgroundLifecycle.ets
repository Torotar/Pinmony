// Keep the ability startup path free of inbox, network and image dependencies.
export class PinmonyInboxBackgroundLifecycle {
  private static hidden: boolean = false;
  private static listener?: (background: boolean) => void;
  static bind(listener: (background: boolean) => void): void { PinmonyInboxBackgroundLifecycle.listener = listener; }
  static unbind(listener: (background: boolean) => void): void {
    if(PinmonyInboxBackgroundLifecycle.listener === listener)PinmonyInboxBackgroundLifecycle.listener = undefined;
  }
  static isBackground(): boolean { return PinmonyInboxBackgroundLifecycle.hidden; }
  static change(background: boolean): void {
    if(PinmonyInboxBackgroundLifecycle.hidden === background)return;
    PinmonyInboxBackgroundLifecycle.hidden = background;
    PinmonyInboxBackgroundLifecycle.listener?.(background);
  }
}
