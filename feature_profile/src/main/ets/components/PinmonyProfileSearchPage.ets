import { PinmonyActionNotice } from 'common_ui';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, BlurStrategy, ScrollEffectType } from '@kit.UIDesignKit';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyProfileSearchSnapshot, PinmonyProfileSearchPin, PinmonyProfileSearchSuggestion } from '../models/PinmonyProfileSearch';

@Component
export struct PinmonyProfileSearchPage {
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  private get immersiveLightEnabled(): boolean { return this.immersiveLightMode !== 'off'; }
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  @Prop snapshot: PinmonyProfileSearchSnapshot;
  onResume: () => void = () => {};
  onPause: () => void = () => {};
  aboutToDisappear(): void { this.onPause(); }
  onBack: () => void = () => {};
  onInput: (query: string) => void = () => {};
  onSubmit: (query: string) => void = () => {};
  onPin: (id: string) => void = () => {};
  onMore: () => void = () => {};
  onRetry: () => void = () => {};
  onDeleteHistory: (query: string) => void = () => {};
  private paths: NavPathStack = new NavPathStack();
  private scroller: Scroller = new Scroller();
  private inputController: SearchController = new SearchController();
  aboutToAppear(): void { this.paths.pushPath({ name: 'profile-search' }, false); this.onResume(); }
  private text(key: string): string { return PinmonyI18n.text(key, this.uiLanguage); }
  private submit(query: string): void { this.inputController.stopEditing(); this.scroller.scrollTo({ xOffset: 0, yOffset: 0 }); this.onSubmit(query); }
  @Builder private pin(pin: PinmonyProfileSearchPin) {
    Column({ space: 6 }) {
      Image(pin.image).width('100%').aspectRatio(0.75).objectFit(ImageFit.Cover).borderRadius(14)
      if (pin.title) { Text(PinmonyI18n.render(pin.title, this.uiLanguage)).fontSize(14).fontColor($r('app.color.primary_text')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }) }
    }.width('100%').onClick(() => this.onPin(pin.id)).accessibilityText(pin.title || this.text('pm_profile_search_your_pins'))
  }
  @Builder private destination() {
    HdsNavDestination() {
      Column() {
        Search({ value: this.snapshot.query, placeholder: this.text('pm_search_44ce7ae9'), controller: this.inputController })
          .cancelButton({ style: CancelButtonStyle.INPUT })
          .fontColor($r('app.color.primary_text')).placeholderColor($r('app.color.secondary_text'))
          .onChange((value: string) => { this.scroller.scrollTo({ xOffset: 0, yOffset: 0 }); this.onInput(value); })
          .onSubmit((value: string) => this.submit(value)).margin({ left: 20, right: 20, bottom: 12 })
        Scroll(this.scroller) {
          Column({ space: 16 }) {
            if (this.snapshot.editing) {
              if (!this.snapshot.query.trim()) { Text(this.text('pm_profile_search_recent')).fontSize(18).fontColor($r('app.color.primary_text')).width('100%') }
              ForEach(this.snapshot.suggestions, (item: PinmonyProfileSearchSuggestion) => {
                Column({ space: 10 }) {
                  Row({ space: 14 }) {
                    Row({ space: 14 }) {
                    Image($r('app.media.inbox_search_outline')).width(20).height(20).fillColor($r('app.color.primary_text'))
                    Text(item.query).fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text')).layoutWeight(1)
                    }.layoutWeight(1).constraintSize({ minHeight: 44 }).onClick(() => { if (!item.deleting) this.submit(item.query); })
                    if (!this.snapshot.query.trim()) {
                      Button({ type: ButtonType.Circle }) {
                        if (item.deleting) { LoadingProgress().width(16).height(16) }
                        else { SymbolGlyph($r('sys.symbol.xmark')).fontSize(14).fontColor([$r('app.color.secondary_text')]) }
                      }.width(36).height(36).padding(0).backgroundColor(Color.Transparent)
                        .enabled(item.deletable === true && !item.deleting)
                        .accessibilityText(this.text(item.deleting ? 'pm_deleting_search_history_2674b330' : 'pm_delete_search_history_80b537e5'))
                        .onClick(() => this.onDeleteHistory(item.query))
                    }
                  }.width('100%').constraintSize({ minHeight: 44 })
                  if (item.pins.length) {
                    Row({ space: 8 }) {
                      ForEach(item.pins, (pin: PinmonyProfileSearchPin) => {
                        Image(pin.image).width(70).height(90).borderRadius(12).objectFit(ImageFit.Cover).onClick(() => this.onPin(pin.id))
                      }, (pin: PinmonyProfileSearchPin) => pin.id)
                    }.width('100%')
                  }
                }.width('100%')
              }, (item: PinmonyProfileSearchSuggestion) => item.query)
              if (this.snapshot.query.trim()) {
                Button({ type: ButtonType.Normal }) {
                  Row({ space: 12 }) {
                    Stack({ alignContent: Alignment.Center }) {
                      Image($r('app.media.inbox_search_outline')).width(18).height(18).fillColor($r('app.color.primary_text'))
                    }.width(44).height(44).borderRadius(22).backgroundColor($r('app.color.surface_muted'))
                    Text(this.text('pm_profile_search_your_pins')).fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
                  }.width('100%').constraintSize({ minHeight: 48 })
                }.width('100%').padding(0).backgroundColor(Color.Transparent)
                  .onClick(() => this.submit(this.snapshot.query))
              }
            } else {
              GridRow({ columns: { xs: 2, sm: 3, md: 4, lg: 5 }, gutter: 12 }) {
                ForEach(this.snapshot.pins, (pin: PinmonyProfileSearchPin) => { GridCol() { this.pin(pin) } }, (pin: PinmonyProfileSearchPin) => pin.id)
              }.width('100%')
            }
            if (this.snapshot.loading) { LoadingProgress().width(28).height(28) }
            if (this.snapshot.error) {
              PinmonyActionNotice({ message: PinmonyI18n.render(this.snapshot.error, this.uiLanguage), actionText: this.text('pm_retry_b8784c8d'), onAction: () => this.onRetry() })
            } else if (!this.snapshot.editing && !this.snapshot.loading && !this.snapshot.pins.length) {
              Text(this.text('pm_profile_search_empty')).fontColor($r('app.color.secondary_text'))
            } else if (!this.snapshot.editing && !this.snapshot.ended && !this.snapshot.loading) {
              Button(this.text('pm_load_more_af90a08f')).onClick(() => this.onMore())
            }
          }.width('100%').constraintSize({ maxWidth: 1000 }).justifyContent(FlexAlign.Start)
            .padding({ left: 20, right: 20, bottom: 32 })
        }.layoutWeight(1).width('100%').align(Alignment.TopStart)
          .onReachEnd(() => { if (!this.snapshot.editing && !this.snapshot.error) this.onMore(); })
      }.width('100%').height('100%').backgroundColor($r('app.color.page_background'))
    }.width('100%').height('100%')
      .titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: true,
      style: { blurStrategy: this.immersiveLightEnabled ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: this.immersiveLightEnabled, scrollEffectOpts: { enableScrollEffect: this.immersiveLightEnabled, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 }, contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },  backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 } } },
        content: { title: { mainTitle: this.text('pm_search_44ce7ae9') },
          backIcon: { isEnabled: true, action: () => this.onBack() },
          menu: { value: [] } } })
      .titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
      .bindToScrollable([this.scroller]).backgroundColor($r('app.color.page_background'))
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .onBackPressed(() => { this.onBack(); return true; })
  }
  build() {
    HdsNavigation(this.paths) { Column().width('100%').height('100%').backgroundColor($r('app.color.page_background')) }
      .width('100%').height('100%').hideTitleBar(true).navDestination(this.destination).mode(NavigationMode.Stack)
      .backgroundColor($r('app.color.page_background'))
  }
}
