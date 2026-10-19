import { SymbolGlyphModifier } from '@kit.ArkUI';
import { PinmonyLoadingOverlay } from 'common_ui';
import { PinmonyPublishFlow } from '../models/PinmonyPublishFlow';
import { PinmonyPublishBoardPage } from './PinmonyPublishBoardPage';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';

@Component
export struct PinmonyPublishPage {
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
      content: { title: { mainTitle: this.state.phase === 'empty' ? '选择图片' : this.state.kind === 'photo' ? '照片' : '网站' },
        backIcon: { label: '返回', isEnabled: !this.state.busy, action: () => this.act(this.state.phase === 'empty' ? 'back' : 'close') },
        menu: { value: this.state.phase === 'website' ? [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.arrow_right')).fontColor([$r('app.color.primary_text')]),
          label: '选择图片', isEnabled: this.canReadWebsite(),
          action: () => { if (this.canReadWebsite()) this.submitWebsite(); }
        } }] : [] } } };
  }

  @Builder
  private websiteSheet() {
    Column() {
      TextInput({ text: this.link, placeholder: '输入链接以创建 Pin 图，https://…' })
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
          PinmonyLoadingOverlay({ message: this.state.kind === 'photo' ? '正在读取照片…' : '正在读取网站图片…' })
        }
      }.width('100%').height('100%')
    }
  }
}
