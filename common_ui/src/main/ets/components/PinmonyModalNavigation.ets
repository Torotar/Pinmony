import { HdsNavigation, HdsNavigationTitleMode, HdsNavigationTitleBarOptions, BlurStrategy, IconStyleMode } from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyHdsTitleBar } from '../services/PinmonyHdsTitleBar';
import { PinmonyImmersiveLight } from '../services/PinmonyImmersiveLight';

// Official HDS title owns the theme and close action; content remains intrinsic.
@Component
export struct PinmonyModalNavigation {
  @StorageLink('immersiveLightMode') private materialMode: string = 'immersive';
  @StorageLink('systemDarkMode') private darkMode: boolean = false;
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  @Prop titleText: string = '';
  @Prop fillContent: boolean = false;
  @Prop closeEnabled: boolean = true;
  @BuilderParam content: () => void;
  onClose: () => void = (): void => {};
  private titleOptions(): HdsNavigationTitleBarOptions {
    return { avoidLayoutSafeArea: false, enableComponentSafeArea: true,
      content: {
        title: { mainTitle: this.titleText },
        menu: { value: [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.xmark')).fontColor([$r('app.color.primary_text')]),
          type: IconStyleMode.SMALL,
          isEnabled: this.closeEnabled,
          label: PinmonyI18n.text('pm_close_3fd47edc', this.uiLanguage),
          action: () => { if (this.closeEnabled) this.onClose(); }
        } }] }
      },
      style: {
        blurStrategy: BlurStrategy.DISABLE, thermoCtrl: false,
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.materialMode),
        scrollEffectOpts: { enableScrollEffect: false },
        originalStyle: {
          backgroundStyle: { backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0, blurRadius: 0 },
          contentStyle: {
            titleStyle: { mainTitleColor: $r('app.color.primary_text') },
            menuStyle: { iconColor: $r('app.color.primary_text'),
              backgroundColor: this.materialMode === 'off' ? $r('app.color.input_surface') : undefined }
          }
        }
      }
    };
  }

  build() {
    Column() {
      HdsNavigation() {}
      // HDS MODAL main-title backdrop is 56vp + 8vp top padding.
      .mode(NavigationMode.Stack).width('100%').height(64)
      .titleMode(HdsNavigationTitleMode.MODAL).hideBackButton(true).hideToolBar(true)
      .titleBar(PinmonyHdsTitleBar.resolve(this.getUIContext(), this.titleOptions(), this.darkMode))
      .backgroundColor($r('app.color.page_background'))
      Column() { this.content() }
        .width('100%').layoutWeight(this.fillContent ? 1 : 0)
    }
    .width('100%').backgroundColor($r('app.color.page_background'))
    .height(this.fillContent ? '100%' : undefined)
  }
}
