import { BlurStrategy } from '@kit.UIDesignKit';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { PinmonyLoadingOverlay } from 'common_ui';
import { PinmonyPublishFlow } from '../models/PinmonyPublishFlow';
import { PinmonyPublishBoardPage } from './PinmonyPublishBoardPage';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';

@Component
export struct PinmonyPublishPage {
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  private get immersiveLightEnabled(): boolean { return this.immersiveLightMode !== 'off'; }
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop state: PinmonyPublishFlow;
  @State private link: string = '';
  private readonly stack: NavPathStack = new NavPathStack();
  private readonly scroller: Scroller = new Scroller();
  onAction: (action: string, value: string, secret: boolean) => void = () => {};
  aboutToAppear(): void { this.stack.pushPath({ name: 'publish' }, false); }

  private act(action: string): void { this.onAction(action, this.link.trim(), false); }
  private submitWebsite(): void {
    if (!this.canReadWebsite()) return;
    this.act('scrape');
  }

  private canReadWebsite(): boolean {
    return /^https?:\/\//i.test(this.link.trim()) && !this.state.loading && !this.state.busy;
  }

  private titleBar(): HdsNavigationTitleBarOptions {
    return { avoidLayoutSafeArea: true, enableComponentSafeArea: true,
      style: { blurStrategy: this.immersiveLightEnabled ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: this.immersiveLightEnabled,
        scrollEffectOpts: { enableScrollEffect: this.immersiveLightEnabled, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        originalStyle: {
          backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 },
          contentStyle: {
            backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') },
            menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') },
            titleStyle: { mainTitleColor: $r('app.color.primary_text') }
          }
        },
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 },
          contentStyle: {
            backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') },
            menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') },
            titleStyle: { mainTitleColor: $r('app.color.primary_text') }
          }
        }
      },
      content: { title: { mainTitle: this.state.phase === 'empty' ? this.uiText("pm_choose_image_9ad12a1a") : this.state.kind === 'photo' ? this.uiText("pm_photos_7b50017a") : this.uiText("pm_website_fb8d739d") },
        backIcon: { label: this.uiText("pm_back_572cf45b"), isEnabled: !this.state.busy, action: () => this.act(this.state.phase === 'empty' ? 'back' : 'close') },
        menu: { value: this.state.phase === 'website' ? [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.arrow_right')).fontColor([$r('app.color.primary_text')]),
          label: this.uiText("pm_choose_image_9ad12a1a"), isEnabled: this.canReadWebsite(),
          action: () => { if (this.canReadWebsite()) this.submitWebsite(); }
        } }] : [] } } };
  }

  @Builder
  private websiteSheet() {
    Column() {
      TextInput({ text: this.link, placeholder: this.uiText("pm_enter_a_link_to_create_a_pin_https_89a0cd78") })
        .maxLength(4096).enabled(!this.state.loading)
        .onChange((v: string) => { this.link = v; })
    }.width('100%').backgroundColor($r('app.color.page_background'))
  }
  @Builder
  private destination(_name?: string, _param?: Object) {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 20 }) {
          if (this.state.phase === 'website') {
            this.websiteSheet()
          } else if (this.state.phase === 'empty') {
            Text(this.uiText("pm_no_images_available_to_create_a_pin_b7fe6e0c")).fontSize(17).fontColor($r('app.color.primary_text'))
            Button(this.uiText("pm_go_back_and_retry_fa25b166")).onClick(() => this.act('back'))
          } else if (this.state.phase === 'photo' && !this.state.loading) {
            Button(this.uiText("pm_choose_photo_cae3ab4b")).enabled(!this.state.loading).onClick(() => this.act('pickPhoto'))
          }
          if (this.state.error) {
            Text(PinmonyI18n.render(this.state.error, this.uiLanguage)).fontColor($r('app.color.secondary_text'))
            Button(this.uiText("pm_back_572cf45b")).onClick(() => this.act('close'))
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding(20)
      }.width('100%').height('100%').align(Alignment.TopStart).scrollBar(BarState.Off)
    }.titleBar(this.titleBar()).titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.scroller])
      .onBackPressed(() => { this.act(this.state.phase === 'empty' ? 'back' : 'close'); return true; })
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .backgroundColor($r('app.color.page_background'))
  }
  build() {
    if (['select', 'boards', 'create'].includes(this.state.phase)) {
      PinmonyPublishBoardPage({ state: this.state, pins: this.state.pins, pinsLoading: this.state.loading,
        onAction: this.onAction })
    } else {
      Stack({ alignContent: Alignment.Center }) {
        HdsNavigation(this.stack) { Column().width('100%').height('100%') }
          .width('100%').height('100%').hideTitleBar(true).navDestination(this.destination)
          .backgroundColor($r('app.color.page_background'))
          .accessibilityLevel(this.state.loading || this.state.busy ? 'no-hide-descendants' : 'auto')
        if (this.state.loading || this.state.busy) {
          PinmonyLoadingOverlay({ message: this.state.kind === 'photo' ? this.uiText("pm_loading_photos_35b3ef9b") : this.uiText("pm_loading_website_images_4300f2d6") })
        }
      }.width('100%').height('100%')
    }
  }
}
