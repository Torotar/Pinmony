import { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';

// Select popup materials are independent of the closed control's background.
export class PinmonyDisplaySelectMenuMaterial implements AttributeModifier<SelectAttribute> {
  private mode: string;
  constructor(mode: string) { this.mode = mode; }

  applyNormalAttribute(instance: SelectAttribute): void {
    if (deviceInfo.apiAvailable('26.0.0')) {
      let supported: boolean = false;
      if (this.mode !== 'off') {
        try { supported = uiMaterial.isImmersiveMaterialSupported(); } catch (_) {}
      }
      instance.menuSystemMaterial(supported ? new uiMaterial.ImmersiveMaterial({
        style: this.mode === 'gentle' ? uiMaterial.ImmersiveStyle.THICK : uiMaterial.ImmersiveStyle.REGULAR,
        colorInvert: false, interactive: true, applyShadow: true,
        lightEffect: { color: $r('app.color.immersive_interaction_light') }
      }) : uiMaterial.Material.empty);
    }
  }
}
