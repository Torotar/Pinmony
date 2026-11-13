import { promptAction, uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { hdsMaterial, SystemMaterialParams } from '@kit.UIDesignKit';

export class PinmonyImmersiveLight {
  public static toastOptions(options: promptAction.ShowToastOptions): promptAction.ShowToastOptions {
    // ShowToastOptions.systemMaterial is available from API 26; keep API 24 options intact.
    // Retain the official Toast material style (THICK), with the app's material switch.
    if (deviceInfo.apiAvailable('26.0.0')) {
      const mode: string = AppStorage.get<string>('immersiveLightMode') ?? 'immersive';
      options.systemMaterial = mode !== 'off' && uiMaterial.isImmersiveMaterialSupported() ?
        new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.THICK,
          colorInvert: false, applyShadow: true
        }) : uiMaterial.Material.empty;
    }
    return options;
  }

  public static sheetOptions(options: SheetOptions, mode: string, enabled: boolean = true): SheetOptions {
    // Modal menus share one dim level; interactive visual search retains its explicit transparent mask.
    if (options.maskColor === undefined && options.enableOutsideInteractive !== true) options.maskColor = '#66000000';
    if (!enabled) return options;
    if (deviceInfo.apiAvailable('26.0.0')) {
      const active: boolean = mode !== 'off' && uiMaterial.isImmersiveMaterialSupported();
      options.systemMaterial = active ? new uiMaterial.ImmersiveMaterial({
        style: mode === 'gentle' ? uiMaterial.ImmersiveStyle.THICK : uiMaterial.ImmersiveStyle.REGULAR,
        colorInvert: false, applyShadow: true
      }) : uiMaterial.Material.empty;
      if (active) options.backgroundColor = '#00000000';
    }
    return options;
  }

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
    let api26: boolean = false;
    if (mode !== 'gentle') {
      try {
        // HDS chrome accepts SystemMaterialParams, not ArkUI ImmersiveMaterial.
        // On API 26 honor both capability reports; never probe uiMaterial on API 24/25.
        api26 = typeof deviceInfo.apiAvailable === 'function' && deviceInfo.apiAvailable('26.0.0');
        if ((!api26 || uiMaterial.isImmersiveMaterialSupported()) &&
          hdsMaterial.getSystemMaterialTypes().includes(hdsMaterial.MaterialType.IMMERSIVE)) {
          materialType = hdsMaterial.MaterialType.IMMERSIVE;
        }
      } catch (_) { /* Use the system adaptive material when capability lookup is unavailable. */ }
    }
    return { materialType: materialType, materialLevel: mode === 'gentle' ||
      (api26 && materialType !== hdsMaterial.MaterialType.IMMERSIVE) ? hdsMaterial.MaterialLevel.SMOOTH :
      mode === 'exquisite' ? hdsMaterial.MaterialLevel.EXQUISITE : hdsMaterial.MaterialLevel.GENTLE };
  }
}
