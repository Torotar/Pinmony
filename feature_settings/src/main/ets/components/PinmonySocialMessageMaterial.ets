import { ChipItemStyle, ColorMetrics, uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';

// Official capsule subtabs use ChipGroup's own unselected/selected material APIs.
export class PinmonySocialMessageMaterial {
  static enabled(mode: string): boolean {
    if (mode === 'off') return false;
    try {
      if (deviceInfo.apiAvailable('26.0.0')) return uiMaterial.isImmersiveMaterialSupported();
    }
    catch (_) { return false; }
    return false;
  }

  static itemStyle(mode: string, size: SizeOptions): ChipItemStyle {
    const active: boolean = PinmonySocialMessageMaterial.enabled(mode);
    return { size: size, backgroundColor: active ? Color.Transparent : $r('app.color.input_surface'),
      selectedBackgroundColor: active ? Color.Transparent : $r('app.color.detail_save_accent'),
      fontColor: $r('app.color.primary_text'), selectedFontColor: Color.White };
  }

  static create(mode: string, selected: boolean): uiMaterial.Material | undefined {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (!PinmonySocialMessageMaterial.enabled(mode)) return uiMaterial.Material.empty;
      let tint: ResourceColor | undefined = undefined;
      if (selected) {
        try {
          const accent: ColorMetrics = ColorMetrics.resourceColor($r('app.color.detail_save_accent'));
          tint = ColorMetrics.rgba(accent.red, accent.green, accent.blue, 0.9).color;
        } catch (_) {
          tint = $r('app.color.detail_save_accent');
        }
      }
      return new uiMaterial.ImmersiveMaterial({
      style: mode === 'gentle' ? uiMaterial.ImmersiveStyle.THICK : uiMaterial.ImmersiveStyle.REGULAR,
      materialColor: tint,
      colorInvert: false, applyShadow: true, interactive: true,
      lightEffect: { color: $r('app.color.immersive_interaction_light') }
      });
    }
    return undefined;
  }
}
