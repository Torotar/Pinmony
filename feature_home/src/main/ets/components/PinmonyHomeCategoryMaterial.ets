import { ColorMetrics, uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';

/** Apply new material only on supported systems; keep the API 24 button palette. */
export class PinmonyHomeCategoryMaterial implements AttributeModifier<ButtonAttribute> {
  private mode: string;
  private selected: boolean;

  private dark: boolean = false;
  private material: uiMaterial.ImmersiveMaterial | undefined = undefined;

  constructor(mode: string, selected: boolean, dark: boolean = false) {
    this.dark = dark;
    this.mode = mode;
    this.selected = selected;
  }

  update(mode: string, selected: boolean, dark: boolean): void {
    if (mode !== this.mode || selected !== this.selected || dark !== this.dark) this.material = undefined;
    this.mode = mode;
    this.selected = selected;
    this.dark = dark;
  }

  applyNormalAttribute(instance: ButtonAttribute): void {
    // Hvigor lowers this intrinsic to version-field comparisons, including on API 24.
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.mode === 'off') {
        this.material = undefined;
        instance.systemMaterial(undefined);
        instance.backgroundColor(this.selected ? $r('app.color.detail_save_accent') : $r('app.color.input_surface'));
        return;
      }
      if (this.material) {
        instance.systemMaterial(this.material);
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
      this.material = new uiMaterial.ImmersiveMaterial({
        style: this.mode === 'gentle' ? uiMaterial.ImmersiveStyle.THICK : uiMaterial.ImmersiveStyle.REGULAR,
        materialColor: tint,
        applyShadow: false,
        interactive: true,
        lightEffect: { color: $r('app.color.immersive_interaction_light') }
      });
      instance.systemMaterial(this.material);
    }
  }
}
