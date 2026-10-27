import { PinmonyActionNotice } from 'common_ui';
import { HdsSnackBar } from '@kit.UIDesignKit';
import { BlurStrategy } from '@kit.UIDesignKit';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, SnackBarIconType, SnackBarOperationType, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
import { PinmonySettingsStore } from '../stores/PinmonySettingsStore';
import { PinmonyRuntimeLog } from 'common_foundation';
@Component
export struct PinmonyVisibilitySettingsPage {
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  private get immersiveLightEnabled(): boolean { return this.immersiveLightMode !== 'off'; }
  @StorageLink('pinmonyLanguage') @Watch('syncErrorSnack') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @ObjectLink @Watch('syncErrorSnack') store: PinmonySettingsStore;
  onRequest?: (action: string, value: string) => Promise<void>;
  onBack?: () => void;
  @State private viewportHeight: number = 700;
  private paths: NavPathStack = new NavPathStack();
  private scroller: Scroller = new Scroller();
  private errorSnack: HdsSnackBar | undefined = undefined;
  private errorSnackKey: string = '';
  private pageVisible: boolean = false;
  aboutToAppear(): void { this.pageVisible = true; this.paths.pushPath({ name: 'visibility' }, false); this.syncErrorSnack(); }
  aboutToDisappear(): void { this.pageVisible = false; this.dismissErrorSnack(); }
  private dismissErrorSnack(): void { this.errorSnack?.dismiss(); this.errorSnackKey = ''; }
  private syncErrorSnack(): void {
    if (!this.pageVisible || !this.store.error || this.store.loading || this.store.busy || this.store.confirmOpen) {
      this.dismissErrorSnack(); return;
    }
    const key: string = this.store.screen + ':' + this.store.recommendationTab + ':' + this.store.token.toString() + ':' + this.store.error + ':' + this.uiLanguage;
    if (key === this.errorSnackKey) return;
    this.dismissErrorSnack(); this.errorSnackKey = key;
    if (!this.errorSnack) this.errorSnack = new HdsSnackBar(this.getUIContext());
    this.errorSnack.show({ icon: $r('sys.symbol.exclamationmark_circle'), iconType: SnackBarIconType.NORMAL }, { title: PinmonyI18n.render(this.store.error, this.uiLanguage) }, {
      operationType: SnackBarOperationType.TEXT_ONLY,
      content: PinmonyI18n.isUnconfirmed(this.store.error) ? this.uiText("pm_reload_df7392cc") : this.uiText("pm_retry_b8784c8d"),
      contentAccessibilityText: this.uiText("pm_reload_current_settings_d2b82d8a"),
      onContentClick: () => {
        if (!this.pageVisible || key !== this.errorSnackKey || this.store.busy || this.store.loading) return;
        this.dismissErrorSnack();
        this.request(this.store.screen === 'recommend' ? this.store.recommendationTab === 'ai' ? 'aiRead' : 'activityRead' : 'read');
      }
    }, { duration: 4000, pressBackCallback: () => { this.dismissErrorSnack(); if (this.onBack) this.onBack(); return true; } });
  }
  private title(): string { return this.uiText("pm_profile_visibility_6fedc091"); }
  private available(): boolean { return !!this.store.data?.ready && !this.store.loading && !this.store.busy && !this.store.error; }
  private async request(action: string, value: string = ''): Promise<void> { if (!this.store.busy && !this.store.loading && this.onRequest) await this.onRequest(action, value); }
  private async confirmPrivacy(): Promise<void> {
    if (!this.available()) return;
    await this.request('privateProfile', this.store.pendingPrivate.toString());
    if (this.store.data?.saved && !this.store.error) this.store.confirmOpen = false;
  }
  private options(): HdsNavigationTitleBarOptions {
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
      content: { title: { mainTitle: this.title() }, backIcon: { isEnabled: !this.store.busy, action: () => { if (this.onBack) this.onBack(); } },
        menu: { value: [] } } };
  }
  @Builder
  private visibilityContent() {
    Row() {
      Text(this.uiText("pm_private_profile_b16cc2bf")).fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).layoutWeight(1)
      Checkbox().select(this.store.data?.privateProfile || false).shape(CheckBoxShape.CIRCLE)
          .selectedColor($r('app.color.accent')).unselectedColor($r('app.color.secondary_text'))
          .mark({ strokeColor: Color.White }).width(24).height(24).margin(12).enabled(this.available() && this.store.data?.canChangePrivacy)
        .onChange((value: boolean) => { if (this.available() && value !== this.store.data?.privateProfile) { this.store.pendingPrivate = value; this.store.confirmOpen = true; } })
        .accessibilityText(this.uiText("pm_private_profile_b16cc2bf"))
    }.width('100%')
    Text(this.uiText("pm_with_a_private_profile_only_people_you_approve_can_see_your_prof_5be21c6f"))
      .fontSize(15).fontColor($r('app.color.secondary_text')).margin({ bottom: 24 })
    Row() {
      Text(this.uiText("pm_search_privacy_d041067d")).fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).layoutWeight(1)
      Checkbox().select(this.store.data?.searchPrivacy || false).shape(CheckBoxShape.CIRCLE)
          .selectedColor($r('app.color.accent')).unselectedColor($r('app.color.secondary_text'))
          .mark({ strokeColor: Color.White }).width(24).height(24).margin(12).enabled(this.available() && this.store.data?.canEditSearchPrivacy)
        .onChange((value: boolean) => { if (this.available() && value !== this.store.data?.searchPrivacy) this.request('searchPrivacy', value.toString()); })
        .accessibilityText(this.uiText("pm_search_privacy_d041067d"))
    }.width('100%')
    Text(this.uiText("pm_hide_your_profile_and_boards_from_search_engines_such_as_google__8bb0a7fb")).fontSize(15).fontColor($r('app.color.secondary_text'))
  }
  @Builder
  private privacySheet() {
    Scroll() {
      Column({ space: 24 }) {
        Text(this.store.pendingPrivate ? this.uiText("pm_make_profile_private_5d577229") : this.uiText("pm_make_profile_public_147d123a")).width('100%').fontSize(23).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
        Row({ space: 16 }) {
          SymbolGlyph($r('sys.symbol.person_2')).fontSize(24).fontColor([$r('app.color.primary_text')])
          Text(this.store.pendingPrivate ? this.uiText("pm_only_your_followers_can_see_your_profile_and_its_content_0ca3b7cb") : this.uiText("pm_anyone_can_see_your_profile_pins_followers_and_boards_44055147")).layoutWeight(1).fontSize(16).fontColor($r('app.color.primary_text'))
        }
        Row({ space: 16 }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(24).fontColor([$r('app.color.primary_text')])
          Text(this.store.pendingPrivate ? this.uiText("pm_your_profile_will_not_appear_in_pinterest_search_results_20307e8e") : this.uiText("pm_your_profile_will_appear_in_pinterest_search_results_ca924e80")).layoutWeight(1).fontSize(16).fontColor($r('app.color.primary_text'))
        }
        if (this.store.error) {
          PinmonyActionNotice({ message: PinmonyI18n.render(this.store.error, this.uiLanguage), actionText: this.uiText("pm_reload_df7392cc"), onAction: () => { this.store.confirmOpen = false; this.request('read'); }, actionEnabled: !this.store.busy })
        }
        Button(this.store.busy ? this.uiText("pm_saving_6bdb4435") : this.store.pendingPrivate ? this.uiText("pm_make_private_c25c078d") : this.uiText("pm_make_public_7a73baf0"))
          .width('100%').height(48).backgroundColor($r('app.color.accent')).fontColor($r('app.color.detail_on_accent'))
          .enabled(this.available()).onClick(() => { this.confirmPrivacy(); })
      }.width('100%').padding({ left: 20, right: 20, top: 48, bottom: 24 }).alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%')
  }
  @Builder
  private destination(_name?: string, _param?: Object) {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Center }) {
      Scroll(this.scroller) {
        Column({ space: 8 }) {
          if (this.store.data?.ready) { this.visibilityContent() }
        }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 32 }).alignItems(HorizontalAlign.Start)
      }.width('100%').height('100%').align(Alignment.TopStart)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      if (this.store.loading || this.store.busy) {
        LoadingProgress().width(40).height(40).color($r('app.color.primary_text')).hitTestBehavior(HitTestMode.None)
      }
      }.width('100%').height('100%')
    }.titleBar(this.options()).titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
      .bindToScrollable([this.scroller]).onBackPressed(() => { if (this.onBack) this.onBack(); return true; })
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP]).backgroundColor($r('app.color.page_background'))
      .bindSheet($$this.store.confirmOpen, this.privacySheet(), {
        radius: { topLeft: 32, topRight: 32, bottomLeft: 32, bottomRight: 32 },
        onWillAppear: (): void => { PinmonyRuntimeLog.info('SheetTrace: event=will-appear source=PinmonyVisibilitySettingsPage.store.confirmOpen radius=four-corners-32vp'); },
        height: Math.min(380, this.viewportHeight * 0.8), showClose: true, dragBar: false,
        backgroundColor: $r('app.color.page_background'), maskColor: '#66000000',
        onWillDismiss: (action: DismissSheetAction) => { if (this.store.busy) return; this.store.confirmOpen = false; action.dismiss(); }
      })
  }
  build() {
    HdsNavigation(this.paths) { Column().width('100%').height('100%') }
      .width('100%').height('100%').hideTitleBar(true).navDestination(this.destination).backgroundColor($r('app.color.page_background'))
      .onAreaChange((_old: Area, area: Area) => { const height: number = Number.parseFloat(area.height.toString()); if (Number.isFinite(height)) this.viewportHeight = Math.max(200, height); })
  }
}
