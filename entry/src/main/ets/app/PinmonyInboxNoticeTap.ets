import { Want } from '@kit.AbilityKit';

// Small ability-to-mounted-scene bridge. Intents never carry account IDs or conversation IDs.
export class PinmonyInboxNoticeTap {
  private static listener: ((token: string) => void) | undefined = undefined;
  private static pending: string = '';
  static bind(listener: (token: string) => void): void {
    PinmonyInboxNoticeTap.listener = listener;
    const token: string = PinmonyInboxNoticeTap.pending;
    PinmonyInboxNoticeTap.pending = '';
    if (token) listener(token);
  }
  static unbind(): void { PinmonyInboxNoticeTap.listener = undefined; }
  static receive(want: Want): void {
    const token: Object | undefined = want.parameters?.pinmonyMessageNotice;
    if (typeof token !== 'string' || !/^[a-z0-9-]{1,128}$/.test(token)) return;
    if (PinmonyInboxNoticeTap.listener) PinmonyInboxNoticeTap.listener(token);
    else PinmonyInboxNoticeTap.pending = token;
  }
}
