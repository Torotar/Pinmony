import { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { hdsMaterial, SystemMaterialParams } from '@kit.UIDesignKit';

export class PinmonyImmersiveLight {
  public static alertOptions(options: AlertDialogParamWithButtons): AlertDialogParamWithButtons {
    if (deviceInfo.apiAvailable('26.0.0')) {
      const mode: string = AppStorage.get<string>('immersiveLightMode') ?? 'immersive';
      options.systemMaterial = mode !== 'off' && uiMaterial.isImmersiveMaterialSupported() ?
        new uiMaterial.ImmersiveMaterial({
          style: mode === 'gentle' ? uiMaterial.ImmersiveStyle.THICK : uiMaterial.ImmersiveStyle.REGULAR,
          colorInvert: false, applyShadow: true
        }) : uiMaterial.Material.empty;
    }
    return options;
  }

  public static effect(mode: string): SystemMaterialParams | undefined {
    if (mode === 'off') return undefined;
    let materialType: hdsMaterial.MaterialType = hdsMaterial.MaterialType.ADAPTIVE;
    if (mode !== 'gentle') {
      try {
        if (hdsMaterial.getSystemMaterialTypes().includes(hdsMaterial.MaterialType.IMMERSIVE)) {
          materialType = hdsMaterial.MaterialType.IMMERSIVE;
        }
      } catch (_) { /* Use the system adaptive material when capability lookup is unavailable. */ }
    }
    return { materialType: materialType, materialLevel: mode === 'gentle' ? hdsMaterial.MaterialLevel.SMOOTH :
      mode === 'exquisite' ? hdsMaterial.MaterialLevel.EXQUISITE : hdsMaterial.MaterialLevel.GENTLE };
  }
}
