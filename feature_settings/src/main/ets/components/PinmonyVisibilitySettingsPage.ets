import { PinmonyI18n } from 'common_foundation';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, HdsSnackBar, SnackBarOperationType, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
import { PinmonySettingsStore } from '../stores/PinmonySettingsStore';
import { PinmonyRuntimeLog } from 'common_foundation';
@Component
export struct PinmonyVisibilitySettingsPage {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
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
  private title(): string { return this.uiText("个人资料可见性"); }
  private available(): boolean { return !!this.store.data?.ready && !this.store.loading && !this.store.busy && !this.store.error; }
  private async request(action: string, value: string = ''): Promise<void> { if (!this.store.busy && !this.store.loading && this.onRequest) await this.onRequest(action, value); }
  private async confirmPrivacy(): Promise<void> {
    if (!this.available()) return;
    await this.request('privateProfile', this.store.pendingPrivate.toString());
    if (this.store.data?.saved && !this.store.error) this.store.confirmOpen = false;
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
        menu: { value: [] } } };
  }
  @Builder
  private visibilityContent() {
    Row() {
      Text(this.uiText("私密个人资料")).fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.store.data?.privateProfile || false }).enabled(this.available() && this.store.data?.canChangePrivacy)
        .onChange((value: boolean) => { if (this.available() && value !== this.store.data?.privateProfile) { this.store.pendingPrivate = value; this.store.confirmOpen = true; } })
        .accessibilityText(this.uiText("私密个人资料"))
    }.width('100%')
    Text(this.uiText("当你的个人资料为私密状态时，仅获得你批准的用户可以查看你的个人资料、Pin 图、图板、粉丝和关注列表。了解更多"))
      .fontSize(15).fontColor($r('app.color.secondary_text')).margin({ bottom: 24 })
    Row() {
      Text(this.uiText("搜索隐私")).fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.store.data?.searchPrivacy || false }).enabled(this.available() && this.store.data?.canEditSearchPrivacy)
        .onChange((value: boolean) => { if (this.available() && value !== this.store.data?.searchPrivacy) this.request('searchPrivacy', value.toString()); })
        .accessibilityText(this.uiText("搜索隐私"))
    }.width('100%')
    Text(this.uiText("在搜索引擎（例如，Google）中隐藏你的个人资料和图板。了解更多")).fontSize(15).fontColor($r('app.color.secondary_text'))
  }
  @Builder
  private privacySheet() {
    Scroll() {
      Column({ space: 24 }) {
        Text(this.store.pendingPrivate ? this.uiText("将个人资料设为私密？") : this.uiText("公开个人资料？")).width('100%').fontSize(23).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
        Row({ space: 16 }) {
          SymbolGlyph($r('sys.symbol.person_2')).fontSize(24).fontColor([$r('app.color.primary_text')])
          Text(this.store.pendingPrivate ? this.uiText("只有你的粉丝可以查看你的个人资料及其内容。") : this.uiText("任何人都可以查看你的个人资料、Pin 图、粉丝和图板。")).layoutWeight(1).fontSize(16).fontColor($r('app.color.primary_text'))
        }
        Row({ space: 16 }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(24).fontColor([$r('app.color.primary_text')])
          Text(this.store.pendingPrivate ? this.uiText("你的个人资料不会显示在 Pinterest 上的搜索结果中。") : this.uiText("你的个人资料将显示在 Pinterest 上的搜索结果中。")).layoutWeight(1).fontSize(16).fontColor($r('app.color.primary_text'))
        }
        if (this.store.error) {
          Text(PinmonyI18n.render(this.store.error, this.uiLanguage)).fontColor($r('app.color.secondary_text'))
          Button(this.uiText("重新读取")).enabled(!this.store.busy).onClick(() => { this.store.confirmOpen = false; this.request('read'); })
        }
        Button(this.store.busy ? this.uiText("正在保存…") : this.store.pendingPrivate ? this.uiText("设为私密") : this.uiText("公开"))
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
