import { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { PinmonyRuntimeLog } from 'common_foundation';

export class PinmonySearchHeaderMaterial {
  static supported(): boolean {
    try {
      if (deviceInfo.apiAvailable('26.0.0')) {
        return uiMaterial.isImmersiveMaterialSupported();
      }
    } catch (_) {}
    return false;
  }

  static active(mode: string): boolean {
    return mode !== 'off' && PinmonySearchHeaderMaterial.supported();
  }

  static apply(attribute: CommonAttribute, mode: string, dark: boolean): void {
    if (deviceInfo.apiAvailable('26.0.0')) {
      attribute.systemMaterial(PinmonySearchHeaderMaterial.active(mode) ?
        new uiMaterial.ImmersiveMaterial({
          style: mode === 'gentle' ? uiMaterial.ImmersiveStyle.THICK : uiMaterial.ImmersiveStyle.ULTRA_THIN,
          materialColor: dark ? '#301C2022' : '#30FFFFFF',
          colorInvert: false,
          applyShadow: false,
          interactive: true,
          lightEffect: { color: Color.White }
        }) : uiMaterial.Material.empty);
    }
  }
}

export class PinmonySearchFieldMaterial implements AttributeModifier<SearchAttribute> {
  private mode: string;
  private dark: boolean;

  constructor(mode: string, dark: boolean) {
    this.mode = mode;
    this.dark = dark;
  }

  applyNormalAttribute(attribute: SearchAttribute): void {
    PinmonySearchHeaderMaterial.apply(attribute, this.mode, this.dark);
  }
}

export class PinmonySearchButtonMaterial implements AttributeModifier<ButtonAttribute> {
  private mode: string;
  private dark: boolean;

  constructor(mode: string, dark: boolean) {
    this.mode = mode;
    this.dark = dark;
  }

  applyNormalAttribute(attribute: ButtonAttribute): void {
    PinmonySearchHeaderMaterial.apply(attribute, this.mode, this.dark);
  }
}

// As in PuraPily HeaderGlassControl, material surfaces must be descendants of
// Navigation's custom title. This host owns no business routes or back actions.
@Component
export struct PinmonySearchHeaderMaterialScope {
  @BuilderParam content: () => void;
  @State private supported: boolean = false;

  aboutToAppear(): void {
    this.supported = PinmonySearchHeaderMaterial.supported();
  }

  @Builder
  private titleContent() {
    Column() {
      this.content()
    }.width('100%').height(88).padding({ top: 16, bottom: 16 })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.supported) {
        Navigation() { Column().height(0) }
          .width('100%').height(88).position({ x: 0, y: -16 })
          .mode(NavigationMode.Stack)
          .title({ builder: this.titleContent, height: 88 }, {
            barStyle: BarStyle.STACK,
            backgroundColor: Color.Transparent,
            backgroundBlurStyle: BlurStyle.NONE
          })
          .hideBackButton(true).hideToolBar(true)
          .backgroundColor(Color.Transparent).clip(false)
      } else {
        this.content()
      }
    }.width('100%').height(56).clip(false)
  }
}

export class PinmonySearchPhotoMenuMaterial {
  static options(mode: string, options: MenuOptions): MenuOptions {
    if (deviceInfo.apiAvailable('26.0.0')) {
      PinmonyRuntimeLog.info('UiMaterialTrace: target=search-photo-menu api26=true mode=' + mode);
      if (mode === 'off') {
        options.systemMaterial = uiMaterial.Material.empty;
      } else {
        options.systemMaterial = new uiMaterial.ImmersiveMaterial({
          style: mode === 'gentle' ? uiMaterial.ImmersiveStyle.THICK : uiMaterial.ImmersiveStyle.REGULAR,
          applyShadow: true
        });
      }
    }
    return options;
  }
}
