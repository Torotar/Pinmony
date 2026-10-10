import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { CapsuleSegmentButtonV2, SegmentButtonV2Items, SymbolGlyphModifier } from '@kit.ArkUI';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, HdsSnackBar, SnackBarOperationType } from '@kit.UIDesignKit';
import { PinmonySettingsStore } from '../stores/PinmonySettingsStore';
import { PinmonyAiTopic, PinmonyRecentActivity } from '../models/PinmonyAccountSettings';
@Component
export struct PinmonyPreferencesPage {
  @ObjectLink @Watch('syncErrorSnack') store: PinmonySettingsStore;
  onRequest?: (action: string, value: string) => Promise<void>;
  onBack?: () => void;
  @StorageLink('bottomBarScrollCollapseEnabled') private collapseEnabled: boolean = true;
  @StorageLink('themePreference') private themePreference: string = 'system';
  @State private viewportHeight: number = 700;
  private paths: NavPathStack = new NavPathStack();
  private scroller: Scroller = new Scroller();
  private errorSnack: HdsSnackBar | undefined = undefined;
  private errorSnackKey: string = '';
  private pageVisible: boolean = false;
  aboutToAppear(): void { this.pageVisible = true; this.paths.pushPath({ name: 'preferences' }, false); this.syncErrorSnack(); }
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
    this.errorSnack.show({}, { title: this.store.error }, {
      operationType: SnackBarOperationType.TEXT_ONLY,
      content: this.store.error.includes('未确认') ? '重新读取' : '重试',
      contentAccessibilityText: '重新读取当前设置',
      onContentClick: () => {
        if (!this.pageVisible || key !== this.errorSnackKey || this.store.busy || this.store.loading) return;
        this.dismissErrorSnack();
        this.request(this.store.screen === 'recommend' ? this.store.recommendationTab === 'ai' ? 'aiRead' : 'activityRead' : 'read');
      }
    }, { duration: 0, pressBackCallback: () => { this.dismissErrorSnack(); if (this.onBack) this.onBack(); return true; } });
  }
  private title(): string { return this.store.screen === 'display' ? '显示设置' : this.store.screen === 'theme' ? '主题' : this.store.screen === 'visibility' ? '个人资料可见性' : '优化你的推荐'; }
  private themeLabel(): string { return this.themePreference === 'dark' ? '深色' : this.themePreference === 'light' ? '浅色' : '跟随系统'; }
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
  private async confirmPrivacy(): Promise<void> {
    if (!this.available()) return;
    await this.request('privateProfile', this.store.pendingPrivate.toString());
    if (this.store.data?.saved && !this.store.error) this.store.confirmOpen = false;
  }
  private selectTheme(value: string): void {
    if (!['system', 'light', 'dark'].includes(value) || this.themePreference === value) return;
    const previous: string = this.themePreference;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.themePreference = value;
      context.getApplicationContext().setColorMode(value === 'dark' ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK : value === 'light' ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (_) {
      this.themePreference = previous;
      this.getUIContext().getPromptAction().showToast({ message: '主题切换失败，请重试', duration: 3000 });
    }
  }
  private options(): HdsNavigationTitleBarOptions {
    return { avoidLayoutSafeArea: true, enableComponentSafeArea: true,
      style: { scrollEffectOpts: { enableScrollEffect: false }, originalStyle: { backgroundStyle: { backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0 } } },
      content: { title: { mainTitle: this.title() }, backIcon: { isEnabled: !this.store.busy, action: () => { if (this.onBack) this.onBack(); } },
        menu: { value: this.store.screen === 'recommend' ? [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.exclamationmark_circle'))
            .fontSize(30).fontColor([$r('app.color.primary_text')]),
          label: '推荐说明', action: () => { this.showRecommendationInfo(); }
        } }] : [] } } };
  }
  private showRecommendationInfo(): void {
    this.getUIContext().showAlertDialog({
      title: '优化你的推荐',
      message: '让 Pinterest 更懂你。编辑详细信息，以便 Pinterest 利用这些信息向你推荐帖子。这些详细信息不会公开显示。',
      confirm: { value: '知道了', action: () => {} }
    });
  }
  @Builder
  private display() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Text('主题').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).layoutWeight(1)
        Text(this.themeLabel()).fontSize(15).fontColor($r('app.color.secondary_text'))
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([$r('app.color.primary_text')])
      }.width('100%').padding({ top: 16, bottom: 16 })
    }.width('100%').backgroundColor(Color.Transparent).onClick(() => {
      this.store.themeReturn = 'display'; this.store.screen = 'theme';
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
    })
    Row({ space: 16 }) {
      Column({ space: 6 }) {
        Text('底栏收起动画').fontSize(17).fontColor($r('app.color.primary_text'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: this.collapseEnabled }).onChange((value: boolean) => { this.collapseEnabled = value; })
        .accessibilityText('底栏收起动画')
    }.width('100%').padding({ top: 16, bottom: 16 })
  }
  @Builder
  private theme() {
    ForEach(['system', 'light', 'dark'], (value: string) => {
      Row() {
        Text(value === 'system' ? '跟随系统' : value === 'light' ? '浅色' : '深色').fontSize(18).fontColor($r('app.color.primary_text')).layoutWeight(1)
        Radio({ group: 'pinweb-theme', value }).checked(this.themePreference === value)
          .onChange((selected: boolean) => { if (selected) this.selectTheme(value); })
          .accessibilityText(value === 'system' ? '跟随系统' : value === 'light' ? '浅色' : '深色')
      }.width('100%').constraintSize({ minHeight: 56 })
    }, (value: string) => value)
  }
  @Builder
  private activityColumn(parity: number) {
    Column({ space: 12 }) {
      ForEach((this.store.data?.activities || []).filter((_pin: PinmonyRecentActivity, index: number) => index % 2 === parity), (pin: PinmonyRecentActivity) => {
        Stack({ alignContent: Alignment.BottomEnd }) {
          Image(pin.image).width('100%').aspectRatio(pin.width / pin.height).objectFit(ImageFit.Cover)
            .accessibilityText(pin.title || '最近浏览或收藏的 Pin 图')
          if (pin.recommendationClosed || pin.closeUncertain) {
            Column() {
              Text(pin.recommendationClosed ? '已关闭此 Pin 图推荐' : '关闭结果未确认')
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
            .accessibilityText((pin.title || '此 Pin 图') + (pin.recommendationClosed ? '，已关闭推荐' : pin.closeUncertain ? '，关闭结果未确认' : '，关闭推荐'))
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
      items: new SegmentButtonV2Items([{ text: 'AI 内容' }, { text: '动态' }]),
      selectedIndex: this.store.recommendationTab === 'ai' ? 0 : 1,
      $selectedIndex: (index: number) => { this.selectRecommendation(index); }
    }).width('100%').margin({ bottom: 12 }).enabled(!this.store.busy && !this.store.loading)
    if (this.store.recommendationTab === 'ai') {
      Text('调整商品目录源内的 AI 修改内容。你可以减少看到的 AI 修改内容，但后续仍可能会出现部分此类内容。').fontSize(15).fontColor($r('app.color.secondary_text'))
      Row({ space: 16 }) {
        Column({ space: 6 }) {
          Text('显示 AI 内容').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
          Text('关闭，以减少商品目录源内的 AI 内容。').fontSize(14).fontColor($r('app.color.secondary_text'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.store.data?.topics.some((t: PinmonyAiTopic) => t.enabled) || false })
          .enabled(this.available() && !!this.store.data?.topics.length)
          .onChange((enabled: boolean) => { if (this.available() && enabled !== this.store.data?.topics.some((t: PinmonyAiTopic) => t.enabled)) this.request('aiAll', enabled.toString()); })
          .accessibilityText('显示 AI 内容')
      }.width('100%').padding(16).borderRadius(18).backgroundColor($r('app.color.surface_muted')).margin({ top: 16, bottom: 16 })
      Text('按主题管理 AI 内容').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
      ForEach(this.store.data?.topics || [], (topic: PinmonyAiTopic) => { this.aiTopic(topic) }, (topic: PinmonyAiTopic) => topic.key)
      if (this.store.data?.ready && !this.store.loading && !this.store.error && !this.store.data.topics.length) {
        Text('暂无可调整的 AI 主题').fontColor($r('app.color.secondary_text'))
      }
    } else {
      Text('隐藏与你最近收藏或点击放大查看的 Pin 图相关的帖子。').width('100%').textAlign(TextAlign.Center).fontSize(15).fontColor($r('app.color.secondary_text')).margin({ bottom: 16 })
      if (this.store.data?.ready && !this.store.loading && !this.store.error && !this.store.data.activities.length) { Text('暂无近期动态').fontColor($r('app.color.secondary_text')) }
      Row({ space: 12 }) { this.activityColumn(0); this.activityColumn(1) }.width('100%').alignItems(VerticalAlign.Top)
    }
  }
  @Builder
  private visibilityContent() {
    Row() {
      Text('私密个人资料').fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.store.data?.privateProfile || false }).enabled(this.available() && this.store.data?.canChangePrivacy)
        .onChange((value: boolean) => { if (this.available() && value !== this.store.data?.privateProfile) { this.store.pendingPrivate = value; this.store.confirmOpen = true; } })
        .accessibilityText('私密个人资料')
    }.width('100%')
    Text('当你的个人资料为私密状态时，仅获得你批准的用户可以查看你的个人资料、Pin 图、图板、粉丝和关注列表。了解更多')
      .fontSize(15).fontColor($r('app.color.secondary_text')).margin({ bottom: 24 })
    Row() {
      Text('搜索隐私').fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.store.data?.searchPrivacy || false }).enabled(this.available() && this.store.data?.canEditSearchPrivacy)
        .onChange((value: boolean) => { if (this.available() && value !== this.store.data?.searchPrivacy) this.request('searchPrivacy', value.toString()); })
        .accessibilityText('搜索隐私')
    }.width('100%')
    Text('在搜索引擎（例如，Google）中隐藏你的个人资料和图板。了解更多').fontSize(15).fontColor($r('app.color.secondary_text'))
  }
  @Builder
  private privacySheet() {
    Scroll() {
      Column({ space: 24 }) {
        Text(this.store.pendingPrivate ? '将个人资料设为私密？' : '公开个人资料？').width('100%').fontSize(23).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
        Row({ space: 16 }) {
          SymbolGlyph($r('sys.symbol.person_2')).fontSize(24).fontColor([$r('app.color.primary_text')])
          Text(this.store.pendingPrivate ? '只有你的粉丝可以查看你的个人资料及其内容。' : '任何人都可以查看你的个人资料、Pin 图、粉丝和图板。').layoutWeight(1).fontSize(16).fontColor($r('app.color.primary_text'))
        }
        Row({ space: 16 }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(24).fontColor([$r('app.color.primary_text')])
          Text(this.store.pendingPrivate ? '你的个人资料不会显示在 Pinterest 上的搜索结果中。' : '你的个人资料将显示在 Pinterest 上的搜索结果中。').layoutWeight(1).fontSize(16).fontColor($r('app.color.primary_text'))
        }
        if (this.store.error) {
          Text(this.store.error).fontColor($r('app.color.secondary_text'))
          Button('重新读取').enabled(!this.store.busy).onClick(() => { this.store.confirmOpen = false; this.request('read'); })
        }
        Button(this.store.busy ? '正在保存…' : this.store.pendingPrivate ? '设为私密' : '公开')
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
          if (this.store.screen === 'display') { this.display() }
          else if (this.store.screen === 'theme') { this.theme() }
          else if (this.store.screen === 'recommend') { this.recommend() }
          else if (this.store.data?.ready) { this.visibilityContent() }
        }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 32 }).alignItems(HorizontalAlign.Start)
      }.width('100%').height('100%').align(Alignment.TopStart)
      if (this.store.loading || this.store.busy) {
        LoadingProgress().width(40).height(40).color($r('app.color.primary_text')).hitTestBehavior(HitTestMode.None)
      }
      }.width('100%').height('100%')
    }.titleBar(this.options()).titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
      .bindToScrollable([this.scroller]).onBackPressed(() => { if (this.onBack) this.onBack(); return true; })
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP]).backgroundColor($r('app.color.page_background'))
      .bindSheet($$this.store.confirmOpen, this.privacySheet(), {
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
