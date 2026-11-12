import { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';

// Component-specific CapsuleSegmentButtonV2 API, available since API 26.
export class PinmonyInboxSegmentMaterial {
  static enabled(mode: string): boolean {
    if (mode === 'off') return false;
    try {
      if (deviceInfo.apiAvailable('26.0.0')) return uiMaterial.isImmersiveMaterialSupported();
    } catch (_) {}
    return false;
  }

  static create(mode: string): uiMaterial.Material | undefined {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (PinmonyInboxSegmentMaterial.enabled(mode)) {
        return new uiMaterial.ImmersiveMaterial({
          style: mode === 'gentle' ? uiMaterial.ImmersiveStyle.THICK : uiMaterial.ImmersiveStyle.REGULAR,
          interactive: true,
          applyShadow: false,
          lightEffect: { color: $r('app.color.immersive_interaction_light') }
        });
      }
      return uiMaterial.Material.empty;
    }
    return undefined;
  }
}
