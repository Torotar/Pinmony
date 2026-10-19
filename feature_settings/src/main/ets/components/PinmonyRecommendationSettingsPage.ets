import { PinmonyI18n } from 'common_foundation';
import { CapsuleSegmentButtonV2, SegmentButtonV2Items, SymbolGlyphModifier } from '@kit.ArkUI';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, HdsSnackBar, SnackBarOperationType, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
import { PinmonySettingsStore } from '../stores/PinmonySettingsStore';
import { PinmonyAiTopic, PinmonyRecentActivity } from '../models/PinmonyAccountSettings';
import { PinmonyRuntimeLog } from 'common_foundation';
@Component
export struct PinmonyRecommendationSettingsPage {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @ObjectLink @Watch('syncErrorSnack') store: PinmonySettingsStore;
  onRequest?: (action: string, value: string) => Promise<void>;
  onBack?: () => void;
  private paths: NavPathStack = new NavPathStack();
  private scroller: Scroller = new Scroller();
  private errorSnack: HdsSnackBar | undefined = undefined;
  private errorSnackKey: string = '';
  private pageVisible: boolean = false;
  aboutToAppear(): void { this.pageVisible = true; this.paths.pushPath({ name: 'recommend' }, false); this.syncErrorSnack(); }
  aboutToDisappear(): void { this.pageVisible = false; this.dismissErrorSnack(); }
  private dismissErrorSnack(): void { this.errorSnack?.dismiss(); this.errorSnackKey = ''; }
  private syncErrorSnack(): void {
    if (!this.pageVisible || !this.store.error || this.store.loading || this.store.busy || this.store.confirmOpen) {
      this.dismissErrorSnack(); return;
    }
    const key: string = this.store.screen + ':' + this.store.recommendationTab + ':' + this.store.token.toString() + ':' + this.store.error;
    if (key === this.errorSnackKey) return;
    this.dismissErrorSnack(); this.errorSnackKey = key;
    if (!this.errorSnack) this.errorSnack = new HdsSnackBar(this.getUIContext());
    this.errorSnack.show({}, { title: PinmonyI18n.render(this.store.error, this.uiLanguage) }, {
      operationType: SnackBarOperationType.TEXT_ONLY,
      content: PinmonyI18n.isUnconfirmed(this.store.error) ? this.uiText("重新读取") : this.uiText("重试"),
      contentAccessibilityText: this.uiText("重新读取当前设置"),
      onContentClick: () => {
        if (!this.pageVisible || key !== this.errorSnackKey || this.store.busy || this.store.loading) return;
        this.dismissErrorSnack();
        this.request(this.store.screen === 'recommend' ? this.store.recommendationTab === 'ai' ? 'aiRead' : 'activityRead' : 'read');
      }
    }, { duration: 0, pressBackCallback: () => { this.dismissErrorSnack(); if (this.onBack) this.onBack(); return true; } });
  }
  private title(): string { return this.uiText("优化你的推荐"); }
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
      style: {
        scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE },
        originalStyle: {
          backgroundStyle: { backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0 },
          contentStyle: {
            backIconStyle: { iconColor: $r('app.color.primary_text') },
            menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') },
            titleStyle: { mainTitleColor: $r('app.color.primary_text') }
          }
        },
        scrollEffectStyle: {
          contentStyle: {
            backIconStyle: { iconColor: $r('app.color.primary_text') },
            menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') },
            titleStyle: { mainTitleColor: $r('app.color.primary_text') }
          }
        }
      },
      content: { title: { mainTitle: this.title() }, backIcon: { isEnabled: !this.store.busy, action: () => { if (this.onBack) this.onBack(); } },
        menu: { value: this.store.screen === 'recommend' ? [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.exclamationmark_circle'))
            .fontSize(30).fontColor([$r('app.color.primary_text')]),
          label: this.uiText("推荐说明"), action: () => { this.showRecommendationInfo(); }
        } }] : [] } } };
  }
  private showRecommendationInfo(): void {
    this.getUIContext().showAlertDialog({
      title: this.uiText("优化你的推荐"),
      message: this.uiText("让 Pinterest 更懂你。编辑详细信息，以便 Pinterest 利用这些信息向你推荐帖子。这些详细信息不会公开显示。"),
      confirm: { value: this.uiText("知道了"), action: () => {} }
    });
  }
  @Builder
  private activityColumn(parity: number) {
    Column({ space: 12 }) {
      ForEach((this.store.data?.activities || []).filter((_pin: PinmonyRecentActivity, index: number) => index % 2 === parity), (pin: PinmonyRecentActivity) => {
        Stack({ alignContent: Alignment.BottomEnd }) {
          Image(pin.image).width('100%').aspectRatio(pin.width / pin.height).objectFit(ImageFit.Cover)
            .accessibilityText(pin.title || this.uiText("最近浏览或收藏的 Pin 图"))
          if (pin.recommendationClosed || pin.closeUncertain) {
            Column() {
              Text(pin.recommendationClosed ? this.uiText("已关闭此 Pin 图推荐") : this.uiText("关闭结果未确认"))
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
            .accessibilityText((pin.title || this.uiText("此 Pin 图")) + (pin.recommendationClosed ? this.uiText("，已关闭推荐") : pin.closeUncertain ? this.uiText("，关闭结果未确认") : this.uiText("，关闭推荐")))
        }.width('100%').aspectRatio(pin.width / pin.height).borderRadius(16).clip(true)
      }, (pin: PinmonyRecentActivity) => pin.id)
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
      items: new SegmentButtonV2Items([{ text: this.uiText("AI 内容") }, { text: this.uiText("动态") }]),
      selectedIndex: this.store.recommendationTab === 'ai' ? 0 : 1,
      $selectedIndex: (index: number) => { this.selectRecommendation(index); }
    }).width('100%').margin({ bottom: 12 }).enabled(!this.store.busy && !this.store.loading)
    if (this.store.recommendationTab === 'ai') {
      Text(this.uiText("调整商品目录源内的 AI 修改内容。你可以减少看到的 AI 修改内容，但后续仍可能会出现部分此类内容。")).fontSize(15).fontColor($r('app.color.secondary_text'))
      Row({ space: 16 }) {
        Column({ space: 6 }) {
          Text(this.uiText("显示 AI 内容")).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
          Text(this.uiText("关闭，以减少商品目录源内的 AI 内容。")).fontSize(14).fontColor($r('app.color.secondary_text'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.store.data?.topics.some((t: PinmonyAiTopic) => t.enabled) || false })
          .enabled(this.available() && !!this.store.data?.topics.length)
          .onChange((enabled: boolean) => { if (this.available() && enabled !== this.store.data?.topics.some((t: PinmonyAiTopic) => t.enabled)) this.request('aiAll', enabled.toString()); })
          .accessibilityText(this.uiText("显示 AI 内容"))
      }.width('100%').padding(16).borderRadius(18).backgroundColor($r('app.color.surface_muted')).margin({ top: 16, bottom: 16 })
      Text(this.uiText("按主题管理 AI 内容")).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
      ForEach(this.store.data?.topics || [], (topic: PinmonyAiTopic) => { this.aiTopic(topic) }, (topic: PinmonyAiTopic) => topic.key)
      if (this.store.data?.ready && !this.store.loading && !this.store.error && !this.store.data.topics.length) {
        Text(this.uiText("暂无可调整的 AI 主题")).fontColor($r('app.color.secondary_text'))
      }
    } else {
      Text(this.uiText("隐藏与你最近收藏或点击放大查看的 Pin 图相关的帖子。")).width('100%').textAlign(TextAlign.Center).fontSize(15).fontColor($r('app.color.secondary_text')).margin({ bottom: 16 })
      if (this.store.data?.ready && !this.store.loading && !this.store.error && !this.store.data.activities.length) { Text(this.uiText("暂无近期动态")).fontColor($r('app.color.secondary_text')) }
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
