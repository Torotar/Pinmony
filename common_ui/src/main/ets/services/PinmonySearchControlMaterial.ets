import { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';

export class PinmonySearchControlMaterial {
  static supported(): boolean {
    try {
      if (deviceInfo.apiAvailable('26.0.0')) {
        return uiMaterial.isImmersiveMaterialSupported();
      }
    } catch (_) {}
    return false;
  }

  static active(mode: string): boolean {
    return mode !== 'off' && PinmonySearchControlMaterial.supported();
  }

  static apply(attribute: CommonAttribute, mode: string, dark: boolean): void {
    if (deviceInfo.apiAvailable('26.0.0')) {
      attribute.systemMaterial(PinmonySearchControlMaterial.active(mode) ?
        new uiMaterial.ImmersiveMaterial({
          style: mode === 'gentle' ? uiMaterial.ImmersiveStyle.THICK : uiMaterial.ImmersiveStyle.ULTRA_THIN,
          materialColor: dark ? '#301C2022' : '#30FFFFFF',
          colorInvert: false,
          applyShadow: false,
          interactive: true,
          lightEffect: { color: $r('app.color.immersive_interaction_light') }
        }) : uiMaterial.Material.empty);
    }
  }
}

export class PinmonySearchControlModifier implements AttributeModifier<SearchAttribute> {
  private mode: string;
  private dark: boolean;

  constructor(mode: string, dark: boolean) {
    this.mode = mode;
    this.dark = dark;
  }

  applyNormalAttribute(attribute: SearchAttribute): void {
    PinmonySearchControlMaterial.apply(attribute, this.mode, this.dark);
  }
}
