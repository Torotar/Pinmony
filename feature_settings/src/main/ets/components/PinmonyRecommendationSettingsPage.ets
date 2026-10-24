import { BlurStrategy } from '@kit.UIDesignKit';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { CapsuleSegmentButtonV2, SegmentButtonV2Items, SymbolGlyphModifier, ComponentContent } from '@kit.ArkUI';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, HdsSnackBar, SnackBarIconType, SnackBarOperationType, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
import { PinmonySettingsStore } from '../stores/PinmonySettingsStore';
import { PinmonyAiTopic, PinmonyRecentActivity } from '../models/PinmonyAccountSettings';
import { PinmonyRuntimeLog } from 'common_foundation';
interface RecommendationInfoOptions { source: string; }
@Component
struct RecommendationInfoContent {
  @StorageLink('pinmonyLanguage') private language: string = 'zh';
  source: string = '';
  build() {
    Text(PinmonyI18n.text(this.source, this.language))
      .fontSize(16).fontColor($r('app.color.primary_text'))
      .padding(16).constraintSize({ maxWidth: 300 })
  }
}
@Builder
function buildRecommendationInfo(options: RecommendationInfoOptions) {
  RecommendationInfoContent({ source: options.source })
}
@Component
export struct PinmonyRecommendationSettingsPage {
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  private get immersiveLightEnabled(): boolean { return this.immersiveLightMode !== 'off'; }
  @StorageLink('pinmonyLanguage') @Watch('syncErrorSnack') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @ObjectLink @Watch('syncErrorSnack') store: PinmonySettingsStore;
  onRequest?: (action: string, value: string) => Promise<void>;
  onBack?: () => void;
  private paths: NavPathStack = new NavPathStack();
  private scroller: Scroller = new Scroller();
  private errorSnack: HdsSnackBar | undefined = undefined;
  private errorSnackKey: string = '';
  private pageVisible: boolean = false;
  private infoContent: ComponentContent<RecommendationInfoOptions> | undefined = undefined;
  private infoOpen: boolean = false;
  aboutToAppear(): void { this.pageVisible = true; this.paths.pushPath({ name: 'recommend' }, false); this.syncErrorSnack(); }
  aboutToDisappear(): void { this.pageVisible = false; this.dismissRecommendationInfo(); this.dismissErrorSnack(); }
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
    }, { duration: 0, pressBackCallback: () => { this.dismissErrorSnack(); if (this.onBack) this.onBack(); return true; } });
  }
  private title(): string { return this.uiText("pm_refine_your_recommendations_92ce2929"); }
  private available(): boolean { return !!this.store.data?.ready && !this.store.loading && !this.store.busy && !this.store.error; }
  private async request(action: string, value: string = ''): Promise<void> { if (!this.store.busy && !this.store.loading && this.onRequest) await this.onRequest(action, value); }
  private selectRecommendation(index: number): void {
    if (this.store.busy || this.store.loading || (index !== 0 && index !== 1)) return;
    const tab: string = index === 0 ? 'ai' : 'activity';
    if (this.store.recommendationTab === tab) return;
    this.store.recommendationTab = tab;
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
    this.request(index === 0 ? 'aiRead' : 'activityRead');
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
        menu: { value: this.store.screen === 'recommend' ? [{ content: {
          componentId: 'pinmony-recommendation-info',
          icon: new SymbolGlyphModifier($r('sys.symbol.exclamationmark_circle'))
            .fontColor([$r('app.color.primary_text')]),
          label: this.uiText("pm_about_recommendations_03c3b26e"), action: () => { this.showRecommendationInfo(); }
        } }] : [] } } };
  }
  private async showRecommendationInfo(): Promise<void> {
    if (!this.pageVisible) return;
    if (this.infoOpen) { await this.dismissRecommendationInfo(); return; }
    this.infoOpen = true;
    try {
      const options: RecommendationInfoOptions = { source: 'pm_help_pinterest_understand_you_better_edit_the_details_used_to_re_20d62659' };
      if (!this.infoContent) this.infoContent = new ComponentContent(this.getUIContext(), wrapBuilder(buildRecommendationInfo), options);
      await this.getUIContext().getPromptAction().openPopup(this.infoContent, { id: 'pinmony-recommendation-info' }, {
        placement: Placement.BottomRight, enableArrow: true, autoCancel: true,
        popupColor: $r('app.color.page_background'),
        onStateChange: (event: PopupStateChangeParam) => { this.infoOpen = event.isVisible; }
      });
      if (!this.pageVisible) await this.dismissRecommendationInfo();
    } catch (_) { this.infoOpen = false; }
  }
  private async dismissRecommendationInfo(): Promise<void> {
    if (this.infoContent && this.infoOpen) {
      try { await this.getUIContext().getPromptAction().closePopup(this.infoContent); }
      catch (_) { /* The system may already have dismissed the popup. */ }
    }
    this.infoOpen = false;
  }
  @Builder
  private activityColumn(parity: number) {
    Column({ space: 12 }) {
      ForEach((this.store.data?.activities || []).filter((_pin: PinmonyRecentActivity, index: number) => index % 2 === parity), (pin: PinmonyRecentActivity) => {
        Stack({ alignContent: Alignment.BottomEnd }) {
          Image(pin.image).width('100%').aspectRatio(pin.width / pin.height).objectFit(ImageFit.Cover)
            .accessibilityText(pin.title || this.uiText("pm_recently_viewed_or_saved_pins_b669376f"))
          if (pin.recommendationClosed || pin.closeUncertain) {
            Column() {
              Text(pin.recommendationClosed ? this.uiText("pm_recommendations_turned_off_for_this_pin_4355c3b5") : this.uiText("pm_change_not_confirmed_0bb5d703"))
                .width('100%').fontSize(14).fontColor(Color.White).padding(12)
            }.width('100%').height('100%').backgroundColor('#66000000').alignItems(HorizontalAlign.Start)
          }
          Button({ type: ButtonType.Normal }) {
            Stack() {
              if (!pin.recommendationClosed) {
                SymbolGlyph($r('sys.symbol.checkmark')).fontSize(18).fontColor([Color.White])
              }
            }.width(26).height(26).borderRadius(8)
              .backgroundColor(pin.recommendationClosed || pin.closeUncertain ? Color.White : $r('app.color.recommendation_selection'))
          }.width(44).height(44).backgroundColor(Color.Transparent).margin(4)
            .enabled(this.available() && !pin.recommendationClosed && !pin.closeUncertain)
            .onClick(() => { if (this.available() && !pin.recommendationClosed && !pin.closeUncertain) this.request('activityClose', pin.id); })
            .accessibilityText((pin.title || this.uiText("pm_this_pin_05e8eaee")) + (pin.recommendationClosed ? this.uiText("pm_recommendations_off_7dd43c85") : pin.closeUncertain ? this.uiText("pm_change_not_confirmed_ccc2d77c") : this.uiText("pm_turn_off_recommendations_629265e0")))
        }.width('100%').aspectRatio(pin.width / pin.height).borderRadius(16).clip(true)
      }, (pin: PinmonyRecentActivity) => (pin.id) + ':' + this.uiLanguage)
    }.layoutWeight(1)
  }
  @Builder
  private aiTopic(topic: PinmonyAiTopic) {
    Row() {
      Text(topic.text).fontSize(17).fontColor($r('app.color.primary_text')).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: topic.enabled }).enabled(this.available())
        .onChange((enabled: boolean) => { if (this.available() && topic.enabled !== enabled) this.request('aiTopic', JSON.stringify({ key: topic.key, enabled })); })
        .accessibilityText(topic.text)
    }.width('100%').constraintSize({ minHeight: 52 })
  }
  @Builder
  private recommend() {
    CapsuleSegmentButtonV2({
      items: new SegmentButtonV2Items([{ text: this.uiText("pm_ai_content_7cdf4844") }, { text: this.uiText("pm_activity_780353e5") }]),
      selectedIndex: this.store.recommendationTab === 'ai' ? 0 : 1,
      $selectedIndex: (index: number) => { this.selectRecommendation(index); }
    }).width('100%').margin({ bottom: 12 }).enabled(!this.store.busy && !this.store.loading)
    if (this.store.recommendationTab === 'ai') {
      Text(this.uiText("pm_adjust_ai_modified_content_in_product_feeds_you_can_see_less_of__6f514185")).fontSize(15).fontColor($r('app.color.secondary_text'))
      Row({ space: 16 }) {
        Column({ space: 6 }) {
          Text(this.uiText("pm_show_ai_content_409fe4d8")).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
          Text(this.uiText("pm_turn_off_to_see_less_ai_content_in_product_feeds_b51424cd")).fontSize(14).fontColor($r('app.color.secondary_text'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.store.data?.topics.some((t: PinmonyAiTopic) => t.enabled) || false })
          .enabled(this.available() && !!this.store.data?.topics.length)
          .onChange((enabled: boolean) => { if (this.available() && enabled !== this.store.data?.topics.some((t: PinmonyAiTopic) => t.enabled)) this.request('aiAll', enabled.toString()); })
          .accessibilityText(this.uiText("pm_show_ai_content_409fe4d8"))
      }.width('100%').padding(16).borderRadius(18).backgroundColor($r('app.color.surface_muted')).margin({ top: 16, bottom: 16 })
      Text(this.uiText("pm_manage_ai_content_by_topic_ed79d1c5")).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
      ForEach(this.store.data?.topics || [], (topic: PinmonyAiTopic) => { this.aiTopic(topic) }, (topic: PinmonyAiTopic) => topic.key)
      if (this.store.data?.ready && !this.store.loading && !this.store.error && !this.store.data.topics.length) {
        Text(this.uiText("pm_no_ai_topics_available_to_adjust_2f24acde")).fontColor($r('app.color.secondary_text'))
      }
    } else {
      Text(this.uiText("pm_hide_pins_related_to_those_you_recently_saved_or_opened_2e744f08")).width('100%').textAlign(TextAlign.Center).fontSize(15).fontColor($r('app.color.secondary_text')).margin({ bottom: 16 })
      if (this.store.data?.ready && !this.store.loading && !this.store.error && !this.store.data.activities.length) { Text(this.uiText("pm_no_recent_activity_360e0904")).fontColor($r('app.color.secondary_text')) }
      Row({ space: 12 }) { this.activityColumn(0); this.activityColumn(1) }.width('100%').alignItems(VerticalAlign.Top)
    }
  }
  @Builder
  private destination(_name?: string, _param?: Object) {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Center }) {
      Scroll(this.scroller) {
        Column({ space: 8 }) {
          this.recommend()
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
  }
  build() {
    HdsNavigation(this.paths) { Column().width('100%').height('100%') }
      .width('100%').height('100%').hideTitleBar(true).navDestination(this.destination).backgroundColor($r('app.color.page_background'))
  }
}
