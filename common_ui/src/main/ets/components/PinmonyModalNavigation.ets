import { HdsNavigation, HdsNavigationTitleMode, HdsNavigationTitleBarOptions, IconStyleMode } from '@kit.UIDesignKit';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyHdsTitleBar } from '../services/PinmonyHdsTitleBar';

// HDS owns both the title bar and its content area, as in its MODAL example.
@Component
export struct PinmonyModalNavigation {
  @StorageLink('immersiveLightMode') private materialMode: string = 'immersive';
  @StorageLink('systemDarkMode') private darkMode: boolean = false;
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  @Prop titleText: string = '';
  @Prop fillContent: boolean = false;
  @Prop closeEnabled: boolean = true;
  @Prop keyboardAvoidedBySheet: boolean = false;
  @Prop immersiveScroll: boolean = false;
  scrollControllers: Scroller[] = [];
  private readonly contentScroller: Scroller = new Scroller();
  @State private contentHeight: number = 1;
  @BuilderParam content: () => void;
  onClose: () => void = (): void => {};
  private updateContentHeight(area: Area): void {
    const measured: number = Number(area.height);
    if (Number.isFinite(measured) && measured >= 0 && Math.abs(measured - this.contentHeight) > 0.5) {
      this.contentHeight = measured;
    }
  }

  private titleOptions(): HdsNavigationTitleBarOptions {
    return { avoidLayoutSafeArea: false, enableComponentSafeArea: !this.immersiveScroll,
      content: {
        title: { mainTitle: this.titleText },
        menu: { value: [{ content: {
          type: IconStyleMode.SMALL,
          isEnabled: this.closeEnabled,
          label: PinmonyI18n.text('pm_close_3fd47edc', this.uiLanguage),
          action: () => { if (this.closeEnabled) this.onClose(); }
        } }] }
      },
      style: PinmonyHdsTitleBar.modalStyle(this.materialMode, this.immersiveScroll)
    };
  }

  build() {
    HdsNavigation() {
      if (this.fillContent) {
        if (this.keyboardAvoidedBySheet) {
          Column() { this.content() }.width('100%').height('100%')
            .expandSafeArea([SafeAreaType.KEYBOARD], [SafeAreaEdge.BOTTOM])
        } else {
          Column() { this.content() }.width('100%').height('100%')
        }
      } else {
        Scroll(this.contentScroller) {
          Column() { this.content() }
            .width('100%')
            .onAreaChange((_previous: Area, current: Area) => this.updateContentHeight(current))
        }.width('100%').height('100%')
          .align(Alignment.TopStart).scrollBar(BarState.Off).edgeEffect(EdgeEffect.None)
      }
    }
      // Official main-title-only MODAL backdrop: 56vp + 8vp top padding.
      // Size the complete navigation, never an empty standalone title host.
      .mode(NavigationMode.Stack).width('100%').height(this.fillContent ? '100%' : this.contentHeight + 64)
      // The comments Sheet already resizes its viewport above the keyboard.
      // Retain that viewport instead of applying keyboard avoidance again inside it.
      .expandSafeArea(this.keyboardAvoidedBySheet ? [SafeAreaType.KEYBOARD] :
        [SafeAreaType.SYSTEM, SafeAreaType.KEYBOARD, SafeAreaType.CUTOUT],
        this.keyboardAvoidedBySheet ? [SafeAreaEdge.BOTTOM] : [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .titleMode(HdsNavigationTitleMode.MODAL).hideBackButton(true).hideToolBar(true)
      .titleBar(PinmonyHdsTitleBar.resolve(this.getUIContext(), this.titleOptions(), this.darkMode))
      .bindToScrollable(this.fillContent ? this.scrollControllers : [this.contentScroller])
      .backgroundColor($r('app.color.page_background'))
  }
}
