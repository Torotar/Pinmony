import { PinmonyHdsTitleBar } from 'common_ui';
import { LengthMetrics } from '@kit.ArkUI';
import { PinmonyActionNotice } from 'common_ui';
import { BlurStrategy } from '@kit.UIDesignKit';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyUserAvatar } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyBoardInvitation, PinmonyBoardInvitations } from '../models/PinmonyBoardInvitation';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
@Component
export struct PinmonyBoardInvitationList {
  @StorageLink('systemDarkMode') private hdsDarkMode: boolean = false;
  @StorageLink('statusBarHeightPx') private statusBarHeightPx: number = 0;
  private titleContentInset(): number { return this.getUIContext().px2vp(this.statusBarHeightPx) + 56; }
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop snapshot: PinmonyBoardInvitations;
  @Prop all: boolean = false;
  @Prop interactionReady: boolean = true;
  @Prop refreshing: boolean = false;
  private invitationTime(item: PinmonyBoardInvitation): string {
    const date: Date = new Date(item.createdAt);
    if (!Number.isFinite(date.getTime())) return '';
    const now: Date = new Date();
    const clock: string = date.getHours().toString().padStart(2, '0') + ':' + date.getMinutes().toString().padStart(2, '0');
    return date.toDateString() === now.toDateString() ? clock :
      new Intl.DateTimeFormat(this.uiLanguage, { month: 'numeric', day: 'numeric' }).format(date) + '\n' + clock;
  }
  onPreview: (item: PinmonyBoardInvitation) => void = () => {};
  onDecline: (item: PinmonyBoardInvitation) => void = () => {};
  onAccept: (item: PinmonyBoardInvitation) => void = () => {};
  onReload: () => void = () => {};
  onAll: () => void = () => {};
  onBack: () => void = () => {};
  private stack: NavPathStack = new NavPathStack();
  private scroller: Scroller = new Scroller();
  aboutToAppear(): void { if (this.all) this.stack.pushPath({ name: 'board-requests' }, false); }
  private titleOptions(): HdsNavigationTitleBarOptions {
    return { avoidLayoutSafeArea: true, enableComponentSafeArea: false,
      style: { blurStrategy: (this.immersiveLightMode !== 'off') ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: (this.immersiveLightMode !== 'off'),
        scrollEffectOpts: { enableScrollEffect: (this.immersiveLightMode !== 'off'), scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        originalStyle: {
          backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: (this.immersiveLightMode !== 'off') ? 18 : 0 },
          contentStyle: {
            backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') },
            titleStyle: { mainTitleColor: $r('app.color.primary_text') }
          }
        },
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: (this.immersiveLightMode !== 'off') ? 18 : 0 },
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
      if (!this.all && this.snapshot.items.length > 0) {
        Button({ type: ButtonType.Normal, stateEffect: false }) {
          Row({ space: 8 }) {
            Text(this.uiText("pm_requests_393e1241")).fontSize(18).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_text')).layoutWeight(1).textAlign(TextAlign.Start)
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([$r('app.color.secondary_text')]).margin({ left: 8 })
          }.width('100%')
        }.width('100%').height(36).padding(0).backgroundColor(Color.Transparent)
          .accessibilityText(this.uiText('pm_view_all_b92c0ea9')).enabled(this.interactionReady).onClick(() => this.onAll())
      }
      if (this.snapshot.loading && !this.refreshing && this.snapshot.items.length === 0) { LoadingProgress().color($r('app.color.accent')).width(24).height(24) }
      if (this.snapshot.error) { PinmonyActionNotice({ active: this.interactionReady && !this.snapshot.busy,
        message: PinmonyI18n.render(this.snapshot.error, this.uiLanguage), actionText: this.uiText('pm_retry_b8784c8d'), onAction: () => this.onReload() }) }
      ForEach(this.all ? this.snapshot.items : this.snapshot.items.slice(0, 1), (item: PinmonyBoardInvitation) => {
        Row({ space: 12 }) {
          Stack({ alignContent: Alignment.BottomEnd }) {
            Image(item.imageUrl).width(52).height(52).borderRadius(10).objectFit(ImageFit.Cover)
            PinmonyUserAvatar({ username: item.inviterUsername || '', image: item.inviterAvatar, name: item.inviter, colorIndex: item.inviterAvatarColorIndex || 0, avatarSize: 24 })
          }.enabled(this.interactionReady && !this.snapshot.loading && !this.snapshot.busy)
            .onClick(() => this.onPreview(item))
          Column({ space: 4 }) {
            Text(this.all ? item.inviter : this.uiText('pm_board_invitations_c4c41664')).fontSize(15).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_text')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(item.boardName).fontSize(14).fontColor($r('app.color.secondary_text'))
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            .enabled(this.interactionReady && !this.snapshot.loading && !this.snapshot.busy)
            .onClick(() => this.onPreview(item))
          Row({ space: 6 }) {
            Button({ type: ButtonType.Normal }) {
              Text(this.uiText("pm_decline_136de7a8")).fontSize(14).fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.primary_text')).maxLines(2)
            }.padding({left:16,right:16,top:12,bottom:12}).constraintSize({maxWidth:128})
              .borderRadius(16).backgroundColor($r('app.color.surface_muted')).flexShrink(0)
              .enabled(this.interactionReady && !this.snapshot.loading && !this.snapshot.busy && !this.snapshot.uncertain && item.status === 'new')
              .onClick(() => this.onDecline(item))
            Button({ type: ButtonType.Normal }) {
              Text(this.uiText("pm_accept_329fcec6")).fontSize(14).fontWeight(FontWeight.Medium)
                .fontColor(Color.White).maxLines(2)
            }.padding({left:16,right:16,top:12,bottom:12}).constraintSize({maxWidth:128})
              .borderRadius(16).backgroundColor($r('app.color.accent')).flexShrink(0)
              .enabled(this.interactionReady && !this.snapshot.loading && !this.snapshot.busy && !this.snapshot.uncertain && item.status === 'new')
              .onClick(() => this.onAccept(item))
          }.flexShrink(0)
          Text(this.invitationTime(item)).fontSize(12).fontColor($r('app.color.secondary_text'))
            .textAlign(TextAlign.End).flexShrink(0).alignSelf(ItemAlign.Center)
        }.width('100%').alignItems(VerticalAlign.Center)
      }, (item: PinmonyBoardInvitation) => (item.boardId + ':' + item.invitedUser) + ':' + this.uiLanguage)
      if (this.all && !this.snapshot.loading && !this.snapshot.error && !this.snapshot.items.length) {
        Text(this.uiText("pm_no_board_invitations_48691bd4")).fontColor($r('app.color.secondary_text'))
      }
    }.width('100%').padding(20).alignItems(HorizontalAlign.Start).backgroundColor($r('app.color.page_background'))
  }
  @Builder private destination() {
        HdsNavDestination() {
          Scroll(this.scroller) {
            Column() { this.content() }.width('100%').padding({top:this.titleContentInset()})
          }.width('100%').height('100%').align(Alignment.Top)
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            .scrollBarMargin({start:LengthMetrics.vp(this.titleContentInset())})
        }.titleBar(PinmonyHdsTitleBar.resolve(this.getUIContext(), this.titleOptions(), this.hdsDarkMode)).titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.scroller])
          .onBackPressed(() => { this.onBack(); return true; })
          .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
  }
  build() {
    if (this.all) {
      HdsNavigation(this.stack) {
        Column().width('100%').height('100%').backgroundColor($r('app.color.page_background'))
      }.width('100%').height('100%').backgroundColor($r('app.color.page_background'))
        .hideTitleBar(true).navDestination(this.destination).mode(NavigationMode.Stack)
    } else { this.content() }
  }
}
