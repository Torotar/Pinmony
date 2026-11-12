import { ColorMetrics, uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';

/** Apply new material only on supported systems; keep the API 24 button palette. */
export class PinmonyHomeCategoryMaterial implements AttributeModifier<ButtonAttribute> {
  private mode: string;
  private selected: boolean;

  constructor(mode: string, selected: boolean) {
    this.mode = mode;
    this.selected = selected;
  }

  applyNormalAttribute(instance: ButtonAttribute): void {
    // Hvigor lowers this intrinsic to version-field comparisons, including on API 24.
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.mode === 'off') {
        instance.systemMaterial(undefined);
        instance.backgroundColor(this.selected ? $r('app.color.detail_save_accent') : $r('app.color.input_surface'));
        return;
      }
      let tint: ResourceColor | undefined = undefined;
      if (this.selected) {
        try {
          const accent: ColorMetrics = ColorMetrics.resourceColor($r('app.color.detail_save_accent'));
          tint = ColorMetrics.rgba(accent.red, accent.green, accent.blue, 0.9).color;
        } catch (_) {
          instance.systemMaterial(undefined);
          instance.backgroundColor($r('app.color.detail_save_accent'));
          return;
        }
      }
      instance.systemMaterial(new uiMaterial.ImmersiveMaterial({
        style: this.mode === 'gentle' ? uiMaterial.ImmersiveStyle.THICK : uiMaterial.ImmersiveStyle.REGULAR,
        materialColor: tint,
        applyShadow: false,
        interactive: true,
        lightEffect: { color: $r('app.color.immersive_interaction_light') }
      }));
    }
  }
}
