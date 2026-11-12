import { ColorMetrics, uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';

// Component-specific CapsuleSegmentButtonV2 API, available since API 26.
export class PinmonyFollowingSegmentMaterial {
  static background(): ColorMetrics | undefined {
    try { return ColorMetrics.resourceColor($r('app.color.surface_muted')); } catch (_) { return undefined; }
  }

  static enabled(mode: string): boolean {
    if (mode === 'off') return false;
    try {
      if (deviceInfo.apiAvailable('26.0.0')) return uiMaterial.isImmersiveMaterialSupported();
    } catch (_) {}
    return false;
  }

  static create(mode: string): uiMaterial.Material | undefined {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (PinmonyFollowingSegmentMaterial.enabled(mode)) {
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

// Use the same capability gate and material mode as the Following capsule.
export class PinmonyFollowingSearchMaterial implements AttributeModifier<SearchAttribute> {
  private mode: string;

  private dark: boolean;

  constructor(mode: string, dark: boolean) { this.mode = mode; this.dark = dark; }

  applyNormalAttribute(instance: SearchAttribute): void {
    if (deviceInfo.apiAvailable('26.0.0')) {
      instance.systemMaterial(PinmonyFollowingSegmentMaterial.enabled(this.mode) ?
        new uiMaterial.ImmersiveMaterial({
          style: this.mode === 'gentle' ? uiMaterial.ImmersiveStyle.THICK : uiMaterial.ImmersiveStyle.ULTRA_THIN,
          materialColor: this.dark ? '#301C2022' : '#30FFFFFF',
          colorInvert: false,
          applyShadow: false,
          interactive: true,
          lightEffect: { color: $r('app.color.immersive_interaction_light') }
        }) : uiMaterial.Material.empty);
    }
  }
}
