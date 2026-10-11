import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';

@Component
export struct PinmonyBoardSectionPage {
  onClose: () => void = () => {};
  @State private name: string = '';
  private paths: NavPathStack = new NavPathStack();
  private scroller: Scroller = new Scroller();
  aboutToAppear(): void { this.paths.pushPath({ name: 'section-create' }, false); }
  @Builder
  private destination(_name?: string, _param?: Object) {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 8 }) {
          Text('名称').fontSize(14).fontColor($r('app.color.primary_text')).width('100%')
          TextInput({ text: this.name }).maxLength(100).backgroundColor(Color.Transparent)
            .fontColor($r('app.color.primary_text')).accessibilityText('图板区块名称')
            .onChange((value: string) => { this.name = value; })
        }.width('100%').padding(16).border({ width: 1, color: $r('app.color.secondary_text'), radius: 16 })
          .margin({ top: 16 })
      }.width('100%').height('100%').padding({ left: 16, right: 16 }).align(Alignment.TopStart)
    }.titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: true,
      style: { scrollEffectOpts: { enableScrollEffect: false }, originalStyle: { backgroundStyle: {
        backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0 } } },
      content: { title: { mainTitle: '添加图板区块' }, backIcon: { isEnabled: true, action: () => this.onClose() },
        menu: { value: [{ content: { label: '下一步', isEnabled: this.name.trim().length > 0, action: () => {} } }] } } })
      .titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.scroller])
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .onBackPressed(() => { this.onClose(); return true; })
  }
  build() {
    HdsNavigation(this.paths) {}.width('100%').height('100%').hideTitleBar(true)
      .navDestination(this.destination).backgroundColor($r('app.color.page_background'))
  }
}
