import { HdsNavigation, HdsNavigationTitleMode, HdsNavigationTitleBarOptions, IconStyleMode } from '@kit.UIDesignKit';
import { PinmonyHdsTitleBar } from '../services/PinmonyHdsTitleBar';
import { PinmonyI18n } from 'common_foundation';
@Component
export struct PinmonyOptionsNavigation {
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  @StorageLink('systemDarkMode') private hdsDarkMode: boolean = false;
  private menuScroller: Scroller = new Scroller();
  @State private menuContentHeight: number = 92;
  private bodyHeight(): number { return Math.min(520, Math.max(20, this.menuContentHeight)); }
  private updateContentHeight(area: Area): void {
    const measured: number = Number(area.height);
    if (Number.isFinite(measured) && measured > 0 && Math.abs(measured - this.menuContentHeight) > 0.5)
      this.menuContentHeight = measured;
  }
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop titleText: string = '';
  @BuilderParam content: () => void;
  onClose: () => void = (): void => {};
  private titleOptions(): HdsNavigationTitleBarOptions {
    return { avoidLayoutSafeArea: false, enableComponentSafeArea: true,
      content: {
        title: { mainTitle: this.titleText },
        menu: { value: [{ content: {
          type: IconStyleMode.SMALL, label: this.uiText('pm_close_3fd47edc'), action: () => this.onClose()
        } }] }
      },
      style: PinmonyHdsTitleBar.modalStyle(this.immersiveLightMode)
    };
  }
  build() {
    HdsNavigation() {
      Scroll(this.menuScroller) {
        Column() { this.content() }
          .width('100%')
          .onAreaChange((_previous: Area, current: Area) => this.updateContentHeight(current))
      }.width('100%').height('100%')
        .align(Alignment.TopStart).scrollBar(BarState.Off).edgeEffect(EdgeEffect.None)
    }
      // Official MODAL main-title backdrop: 56vp title plus 8vp top padding.
      .mode(NavigationMode.Stack).width('100%').height(this.bodyHeight() + 64)
      .titleMode(HdsNavigationTitleMode.MODAL).hideBackButton(true).hideToolBar(true)
      .titleBar(PinmonyHdsTitleBar.resolve(this.getUIContext(), this.titleOptions(), this.hdsDarkMode))
      .bindToScrollable([this.menuScroller])
      .backgroundColor($r('app.color.page_background'))
  }

}
