import { SymbolGlyphModifier } from '@kit.ArkUI';
import { PinmonyLoadingOverlay } from 'common_ui';
import { PinmonyPublishFlow } from '../models/PinmonyPublishFlow';
import { PinmonyPublishBoardPage } from './PinmonyPublishBoardPage';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';

@Component
export struct PinmonyPublishPage {
  @Prop state: PinmonyPublishFlow;
  @State private link: string = '';
  @State private websiteVisible: boolean = false;
  private readonly stack: NavPathStack = new NavPathStack();
  private readonly scroller: Scroller = new Scroller();
  onAction: (action: string, value: string, secret: boolean) => void = () => {};
  aboutToAppear(): void { this.stack.pushPath({ name: 'publish' }, false); this.websiteVisible = this.state.phase === 'website'; }

  private act(action: string): void { this.onAction(action, this.link.trim(), false); }
  private submitWebsite(): void {
    if (!this.canReadWebsite()) return;
    this.websiteVisible = false;
    this.act('scrape');
  }

  private canReadWebsite(): boolean {
    return /^https?:\/\//i.test(this.link.trim()) && !this.state.loading && !this.state.busy;
  }

  private titleBar(): HdsNavigationTitleBarOptions {
    return { avoidLayoutSafeArea: true, enableComponentSafeArea: true,
      style: { scrollEffectOpts: { enableScrollEffect: false }, originalStyle: { backgroundStyle: {
        backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0 } } },
      content: { title: { mainTitle: this.state.phase === 'empty' ? '选择图片' : this.state.kind === 'photo' ? '照片' : '网站' },
        backIcon: { label: '返回', isEnabled: !this.state.busy, action: () => this.act(this.state.phase === 'empty' ? 'back' : 'close') },
        menu: { value: this.state.phase === 'website' ? [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]),
          label: '选择图片', isEnabled: this.canReadWebsite(),
          action: () => { if (this.canReadWebsite()) this.submitWebsite(); }
        } }] : [] } } };
  }

  @Builder
  private websiteSheet() {
    Column() {
      Row() {
        Text('网站').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).layoutWeight(1)
        SymbolGlyph($r('sys.symbol.checkmark')).fontSize(24).fontColor([$r('app.color.primary_text')])
          .accessibilityText('选择图片').enabled(this.canReadWebsite())
          .onClick(() => { if (this.canReadWebsite()) this.act('scrape'); })
      }.width('100%').height(56).padding({ left: 20, right: 20 })
      TextInput({ text: this.link, placeholder: '输入链接以创建 Pin 图，https://…' })
        .maxLength(4096).enabled(!this.state.loading).margin({ left: 20, right: 20 })
        .onChange((v: string) => { this.link = v; })
      if (this.state.error) {
        Text(this.state.error).fontColor($r('app.color.secondary_text')).margin(20)
      }
    }.width('100%').backgroundColor($r('app.color.page_background'))
  }
  @Builder
  private destination(_name?: string, _param?: Object) {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 20 }) {
          if (this.state.phase === 'empty') {
            Text('没有读取到可创建 Pin 的图片').fontSize(17).fontColor($r('app.color.primary_text'))
            Button('返回并重试').onClick(() => this.act('back'))
          } else if (this.state.phase === 'photo' && !this.state.loading) {
            Button('选择照片').enabled(!this.state.loading).onClick(() => this.act('pickPhoto'))
          }
          if (this.state.error) {
            Text(this.state.error).fontColor($r('app.color.secondary_text'))
            Button('返回').onClick(() => this.act('close'))
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding(20)
      }.width('100%').height('100%').align(Alignment.TopStart).scrollBar(BarState.Off)
    }.titleBar(this.titleBar()).titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.scroller])
      .onBackPressed(() => { this.act(this.state.phase === 'empty' ? 'back' : 'close'); return true; })
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .backgroundColor($r('app.color.page_background'))
  }
  build() {
    if (this.state.phase === 'website') {
      Stack() {
        Column().width('100%').height('100%').backgroundColor($r('app.color.page_background'))
      }.width('100%').height('100%').backgroundColor($r('app.color.page_background'))
        .bindSheet($$this.websiteVisible, this.websiteSheet(), {
          height: '50%', dragBar: true, showClose: false,
          backgroundColor: $r('app.color.page_background'), maskColor: '#66000000',
          onWillDismiss: () => { this.websiteVisible = false; this.act('close'); }
        })
    } else if (['select', 'boards', 'create'].includes(this.state.phase)) {
      PinmonyPublishBoardPage({ state: this.state, pins: this.state.pins, pinsLoading: this.state.loading,
        onAction: this.onAction })
    } else {
      Stack({ alignContent: Alignment.Center }) {
        HdsNavigation(this.stack) { Column().width('100%').height('100%') }
          .width('100%').height('100%').hideTitleBar(true).navDestination(this.destination)
          .backgroundColor($r('app.color.page_background'))
          .accessibilityLevel(this.state.loading || this.state.busy ? 'no-hide-descendants' : 'auto')
        if (this.state.loading || this.state.busy) {
          PinmonyLoadingOverlay({ message: this.state.kind === 'photo' ? '正在读取照片…' : '正在读取网站图片…' })
        }
      }.width('100%').height('100%')
    }
  }
}
