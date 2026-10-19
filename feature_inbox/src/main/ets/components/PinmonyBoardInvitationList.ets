import { PinmonyBoardInvitation, PinmonyBoardInvitations } from '../models/PinmonyBoardInvitation';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
@Component
export struct PinmonyBoardInvitationList {
  @Prop snapshot: PinmonyBoardInvitations;
  @Prop all: boolean = false;
  onPreview: (item: PinmonyBoardInvitation) => void = () => {};
  onAll: () => void = () => {};
  onBack: () => void = () => {};
  private stack: NavPathStack = new NavPathStack();
  private scroller: Scroller = new Scroller();
  aboutToAppear(): void { if (this.all) this.stack.pushPath({ name: 'board-requests' }, false); }
  private titleOptions(): HdsNavigationTitleBarOptions {
    return { avoidLayoutSafeArea: true, enableComponentSafeArea: true,
      style: {
        scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE },
        originalStyle: {
          backgroundStyle: { backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0 },
          contentStyle: {
            backIconStyle: { iconColor: $r('app.color.primary_text') },
            titleStyle: { mainTitleColor: $r('app.color.primary_text') }
          }
        },
        scrollEffectStyle: {
          contentStyle: {
            backIconStyle: { iconColor: $r('app.color.primary_text') },
            titleStyle: { mainTitleColor: $r('app.color.primary_text') }
          }
        }
      },
      content: { title: { mainTitle: '请求' }, backIcon: { action: () => this.onBack() } } };
  }
  @Builder private content() {
    Column({ space: 12 }) {
      Row() {
        Text(this.all ? '图板邀请' : '请求').fontSize(18).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary_text')).layoutWeight(1)
        if (!this.all) { Button('查看全部 ›').backgroundColor(Color.Transparent).fontColor($r('app.color.primary_text')).onClick(() => this.onAll()) }
      }.width('100%')
      if (this.snapshot.loading) { LoadingProgress().width(24).height(24) }
      if (this.snapshot.error) { Text(this.snapshot.error).fontColor($r('app.color.secondary_text')) }
      ForEach(this.all ? this.snapshot.items : this.snapshot.items.slice(0, 1), (item: PinmonyBoardInvitation) => {
        Row({ space: 12 }) {
          Stack({ alignContent: Alignment.BottomEnd }) {
            Image(item.imageUrl).width(52).height(52).borderRadius(10).objectFit(ImageFit.Cover)
            Image(item.inviterAvatar).width(24).height(24).borderRadius(12)
          }
          Column({ space: 8 }) {
            Text(this.all ? item.inviter : '图板邀请').fontSize(16).fontColor($r('app.color.primary_text'))
            Text(item.boardName).fontSize(15).fontColor($r('app.color.secondary_text'))
            Row({ space: 8 }) {
              Button('拒绝').backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text')).enabled(false)
              Button('预览').backgroundColor($r('app.color.accent')).fontColor(Color.White).onClick(() => this.onPreview(item))
            }
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        }.width('100%').alignItems(VerticalAlign.Top)
      }, (item: PinmonyBoardInvitation) => item.boardId + ':' + item.invitedUser)
      if (this.all && !this.snapshot.loading && !this.snapshot.error && !this.snapshot.items.length) {
        Text('暂无图板邀请').fontColor($r('app.color.secondary_text'))
      }
    }.width('100%').padding(20).alignItems(HorizontalAlign.Start).backgroundColor($r('app.color.page_background'))
  }
  build() {
    if (this.all) {
      HdsNavigation(this.stack) {
        HdsNavDestination() {
          Scroll(this.scroller) { this.content() }.width('100%').height('100%').align(Alignment.Top)
        }.titleBar(this.titleOptions()).titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.scroller])
          .onBackPressed(() => { this.onBack(); return true; })
          .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      }.width('100%').height('100%').backgroundColor($r('app.color.page_background'))
    } else { this.content() }
  }
}
