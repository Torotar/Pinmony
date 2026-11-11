import { BlurStrategy, HdsNavigation, HdsNavigationTitleMode, HdsNavigationTitleBarOptions, ScrollEffectType, IconStyleMode } from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { PinmonyActionNotice, PinmonyHdsTitleBar, PinmonyImmersiveLight } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyPinStore } from '../stores/PinmonyPinStore';
import { MoreSheetOption } from '../models/PinmonySheets';
@Component
export struct PinmonyMoreSheet {
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
  @ObjectLink pinStore: PinmonyPinStore;
  onAction: (id: string) => void = (): void => {};
  onRetry: () => void = (): void => {};
  onClose: () => void = (): void => {};
  private titleOptions(): HdsNavigationTitleBarOptions {
    return { avoidLayoutSafeArea: false, enableComponentSafeArea: true,
      content: {
        title: { mainTitle: this.uiText('pm_options_bb7486f4') },
        menu: { value: [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.xmark')).fontColor([$r('app.color.primary_text')]),
          type: IconStyleMode.SMALL, label: this.uiText('pm_close_3fd47edc'), action: () => this.onClose()
        } }] }
      },
      style: {
        blurStrategy: this.immersiveLightMode !== 'off' ? BlurStrategy.ENABLE : BlurStrategy.DISABLE,
        thermoCtrl: this.immersiveLightMode !== 'off',
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        scrollEffectOpts: { enableScrollEffect: this.immersiveLightMode !== 'off', scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        originalStyle: {
          backgroundStyle: { backgroundColor: this.immersiveLightMode !== 'off' ? Color.Transparent : $r('app.color.page_background'), maskExtraHeight: 0 },
          contentStyle: { titleStyle: { mainTitleColor: $r('app.color.primary_text') }, menuStyle: { iconColor: $r('app.color.primary_text') } }
        },
        scrollEffectStyle: {
          backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: this.immersiveLightMode !== 'off' ? 18 : 0 },
          contentStyle: { titleStyle: { mainTitleColor: $r('app.color.primary_text') }, menuStyle: { iconColor: $r('app.color.primary_text') } }
        }
      }
    };
  }
  build() {
    HdsNavigation() { this.menuBody() }
      // Official MODAL main-title backdrop: 56vp title plus 8vp top padding.
      .mode(NavigationMode.Stack).width('100%').height(this.bodyHeight() + 64)
      .titleMode(HdsNavigationTitleMode.MODAL).hideBackButton(true).hideToolBar(true)
      .titleBar(PinmonyHdsTitleBar.resolve(this.getUIContext(), this.titleOptions(), this.hdsDarkMode))
      .bindToScrollable([this.menuScroller])
      .backgroundColor($r('app.color.page_background')).clip(true)
  }

  @Builder
  private menuBody() {
    Scroll(this.menuScroller) {
    Column() {
      if (this.pinStore.moreLoading) {
        Row({ space: 12 }) {
          LoadingProgress().color($r('app.color.accent'))
            .width(24)
            .height(24)
          Text(this.uiText("pm_loading_options_a22ab0b2"))
            .fontSize(14)
            .fontColor($r('app.color.secondary_text'))
        }
        .height(72)
        .padding({ left: 20, right: 20 })
      } else {
          Column() {
            ForEach(this.pinStore.moreOptions.filter((option: MoreSheetOption): boolean => option.id !== 'detail-favorite'), (option: MoreSheetOption, index: number) => {
              if (index > 0 && option.group !== this.pinStore.moreOptions[index - 1].group) {
                Divider()
                  .color('#4D8A8A8A')
                  .margin({ left: 20, right: 20, top: 6, bottom: 6 })
              }
              Row({ space: 14 }) {
                if (/^detail-(download|see-more|see-less|share)$/.test(option.id)) {
                  Image(option.id === 'detail-download' ? $r('app.media.lucide_download') :
                    option.id === 'detail-see-more' ? $r('app.media.lucide_heart') :
                    option.id === 'detail-see-less' ? $r('app.media.lucide_eye_off') : $r('app.media.lucide_share_2'))
                    .width(28).height(28).objectFit(ImageFit.Contain)

                } else if (option.id === 'detail-edit') {
                  Image($r('app.media.lucide_pencil')).width(28).height(28)
                    .objectFit(ImageFit.Contain)
                } else if (option.id === 'detail-ai-help') {
                  SymbolGlyph($r('sys.symbol.info_circle'))
                    .fontSize(28).fontColor([$r('app.color.primary_text')])
                } else if (option.icon) {
                  Image(option.icon)
                    .width(28)
                    .height(28)
                    .objectFit(ImageFit.Contain)
                }
                Column() {
                  Text(PinmonyI18n.optionLabel(option.id, option.label, this.uiLanguage))
                    .fontSize(17)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.primary_text'))
                    .maxLines(2)
                  if (option.subtitle && !/详细了解.*AI|learn more.*AI/i.test(option.label)) {
                    Text(PinmonyI18n.render(option.subtitle, this.uiLanguage))
                      .fontSize(12)
                      .fontColor($r('app.color.secondary_text'))
                      .maxLines(3)
                      .margin({ top: 3 })
                  }
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding({ left: 24, right: 20, top: 14, bottom: 14 })
              .opacity(option.enabled ? 1 : 0.4)
              .accessibilityText(PinmonyI18n.optionLabel(option.id, option.label, this.uiLanguage))
              .onClick(() => {
                if (option.enabled) this.onAction(option.id);
              })
            }, (option: MoreSheetOption) => option.id + ':' + option.enabled.toString() + ':' + this.uiLanguage)
          }
          .width('100%')
      }
      if (this.pinStore.moreError) {
        Row({ space: 12 }) {
          PinmonyActionNotice({ message: PinmonyI18n.render(this.pinStore.moreError, this.uiLanguage), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => this.onRetry() })
        }
        .margin({ left: 20, right: 20, top: 12 })
      }
    }
    .width('100%')
    .padding({ bottom: 20 })
    .backgroundColor($r('app.color.page_background'))
    .onAreaChange((_previous: Area, current: Area) => this.updateContentHeight(current))
    }
    .width('100%')
    .height(this.bodyHeight())
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .clip(false)
  }


}
