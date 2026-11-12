import { UIContext } from '@kit.ArkUI';

export class PinmonyPinViewTransition {
  static run(context: UIContext, update: () => void): void {
    context.animateTo({ duration: 280, curve: Curve.EaseOut }, update);
  }
}
