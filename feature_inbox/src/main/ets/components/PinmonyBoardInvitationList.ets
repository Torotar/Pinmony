import { PinmonyActionNotice } from 'common_ui';
import { BlurStrategy } from '@kit.UIDesignKit';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyUserAvatar } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyBoardInvitation, PinmonyBoardInvitations } from '../models/PinmonyBoardInvitation';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
@Component
export struct PinmonyBoardInvitationList {
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  private get immersiveLightEnabled(): boolean { return this.immersiveLightMode !== 'off'; }
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
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
      style: { blurStrategy: this.immersiveLightEnabled ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: this.immersiveLightEnabled,
        scrollEffectOpts: { enableScrollEffect: this.immersiveLightEnabled, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        originalStyle: {
          backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 },
          contentStyle: {
            backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') },
            titleStyle: { mainTitleColor: $r('app.color.primary_text') }
          }
        },
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 },
          contentStyle: {
            backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') },
            titleStyle: { mainTitleColor: $r('app.color.primary_text') }
          }
        }
      },
      content: { title: { mainTitle: this.uiText("pm_requests_393e1241") }, backIcon: { action: () => this.onBack() } } };
  }
  @Builder private content() {
    Column({ space: 12 }) {
      Row() {
        Text(this.all ? this.uiText("pm_board_invitations_c4c41664") : this.uiText("pm_requests_393e1241")).fontSize(18).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary_text')).layoutWeight(1)
        if (!this.all) { Button(this.uiText("pm_view_all_b92c0ea9")).backgroundColor(Color.Transparent).fontColor($r('app.color.primary_text')).onClick(() => this.onAll()) }
      }.width('100%')
      if (this.snapshot.loading) { LoadingProgress().width(24).height(24) }
      if (this.snapshot.error) { PinmonyActionNotice({ message: PinmonyI18n.render(this.snapshot.error, this.uiLanguage) }) }
      ForEach(this.all ? this.snapshot.items : this.snapshot.items.slice(0, 1), (item: PinmonyBoardInvitation) => {
        Row({ space: 12 }) {
          Stack({ alignContent: Alignment.BottomEnd }) {
            Image(item.imageUrl).width(52).height(52).borderRadius(10).objectFit(ImageFit.Cover)
            PinmonyUserAvatar({ image: item.inviterAvatar, name: item.inviter, avatarSize: 24 })
          }
          Column({ space: 8 }) {
            Text(this.all ? item.inviter : this.uiText("pm_board_invitations_c4c41664")).fontSize(16).fontColor($r('app.color.primary_text'))
            Text(item.boardName).fontSize(15).fontColor($r('app.color.secondary_text'))
            Row({ space: 8 }) {
              Button(this.uiText("pm_decline_136de7a8")).backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text')).enabled(false)
              Button(this.uiText("pm_preview_13d61fea")).backgroundColor($r('app.color.accent')).fontColor(Color.White).onClick(() => this.onPreview(item))
            }
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        }.width('100%').alignItems(VerticalAlign.Top)
      }, (item: PinmonyBoardInvitation) => (item.boardId + ':' + item.invitedUser) + ':' + this.uiLanguage)
      if (this.all && !this.snapshot.loading && !this.snapshot.error && !this.snapshot.items.length) {
        Text(this.uiText("pm_no_board_invitations_48691bd4")).fontColor($r('app.color.secondary_text'))
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
