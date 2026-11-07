import { Want } from '@kit.AbilityKit';

// Small ability-to-mounted-scene bridge. Intents never carry account IDs or conversation IDs.
export class PinmonyInboxNoticeTap {
  private static listener: ((token: string) => void) | undefined = undefined;
  static bind(listener: (token: string) => void): void { PinmonyInboxNoticeTap.listener = listener; }
  static receive(want: Want): void {
    const token: Object | undefined = want.parameters?.pinmonyMessageNotice;
    if(typeof token === 'string' && token.length > 0 && token.length <= 128)PinmonyInboxNoticeTap.listener?.(token);
  }
}
