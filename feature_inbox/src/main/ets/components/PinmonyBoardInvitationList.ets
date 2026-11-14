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
  @State private invitationCardWidth: number = 0;
  private measuredLabelWidth(text: string, size: number, weight: FontWeight): number {
    const measured: SizeOptions = this.getUIContext().getMeasureUtils().measureTextSize({
      textContent: text, fontSize: size, fontWeight: weight
    });
    return Math.ceil(this.getUIContext().px2vp(Number(measured.width)));
  }
  private invitationActionWidth(key: string): number {
    const natural: number = this.measuredLabelWidth(this.uiText(key), 14, FontWeight.Medium) + 32;
    return Math.min(128, this.invitationCardWidth > 0 ? Math.min(natural, Math.max(0, (this.invitationCardWidth - 6) / 2)) : natural);
  }
  private invitationActionsInline(item: PinmonyBoardInvitation): boolean {
    const title: string = this.all ? item.inviter : this.uiText('pm_board_invitations_c4c41664');
    const label: number = Math.max(48, this.measuredLabelWidth(title, 15, FontWeight.Bold));
    const actions: number = this.measuredLabelWidth(this.uiText('pm_decline_136de7a8'), 14, FontWeight.Medium) +
      this.measuredLabelWidth(this.uiText('pm_accept_329fcec6'), 14, FontWeight.Medium) + 70;
    const time: number = this.invitationTime(item).split('\n').reduce((width: number, line: string): number =>
      Math.max(width, this.measuredLabelWidth(line, 12, FontWeight.Normal)), 0);
    return this.invitationCardWidth >= 52 + 36 + label + actions + time;
  }
  private invitationTime(item: PinmonyBoardInvitation): string {
    const date: Date = new Date(item.createdAt);
    if (!Number.isFinite(date.getTime())) return '';
    const now: Date = new Date();
    const clock: string = this.uiLanguage === 'ar' ?
      new Intl.DateTimeFormat('ar', { hour: 'numeric', minute: '2-digit' }).format(date) :
      date.getHours().toString().padStart(2, '0') + ':' + date.getMinutes().toString().padStart(2, '0');
    const age: number = (Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()) -
      Date.UTC(date.getFullYear(), date.getMonth(), date.getDate())) / 86400000;
    const weekdays: string[] = ['pm_sunday_7e06f314', 'pm_monday_56451fdf', 'pm_tuesday_8621c00d',
      'pm_wednesday_23ae0a11', 'pm_thursday_478911d2', 'pm_friday_6e5969e5', 'pm_saturday_7bb2f5ec'];
    const calendar: string = age >= 0 && age < 7 ? this.uiText(weekdays[date.getDay()]) :
      new Intl.DateTimeFormat(this.uiLanguage, { year: date.getFullYear() === now.getFullYear() ? undefined : 'numeric', month: 'numeric', day: 'numeric' }).format(date);
    return clock + '\n' + calendar;
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
  @Builder private invitationActions(item: PinmonyBoardInvitation) {
          Row({ space: 6 }) {
            Button({ type: ButtonType.Normal }) {
              Text(this.uiText("pm_decline_136de7a8")).fontSize(14).fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.primary_text')).wordBreak(WordBreak.BREAK_WORD).textAlign(TextAlign.Center)
            }.padding({left:16,right:16,top:12,bottom:12}).width(this.invitationActionWidth('pm_decline_136de7a8'))
              .borderRadius(16).backgroundColor($r('app.color.surface_muted')).flexShrink(0)
              .enabled(this.interactionReady && !this.snapshot.loading && !this.snapshot.busy && !this.snapshot.uncertain && item.status === 'new')
              .onClick(() => this.onDecline(item))
            Button({ type: ButtonType.Normal }) {
              Text(this.uiText("pm_accept_329fcec6")).fontSize(14).fontWeight(FontWeight.Medium)
                .fontColor(Color.White).wordBreak(WordBreak.BREAK_WORD).textAlign(TextAlign.Center)
            }.padding({left:16,right:16,top:12,bottom:12}).width(this.invitationActionWidth('pm_accept_329fcec6'))
              .borderRadius(16).backgroundColor($r('app.color.accent')).flexShrink(0)
              .enabled(this.interactionReady && !this.snapshot.loading && !this.snapshot.busy && !this.snapshot.uncertain && item.status === 'new')
              .onClick(() => this.onAccept(item))
          }.flexShrink(0)
  }
  @Builder private content() {
    Column({ space: 12 }) {
      if (!this.all && this.snapshot.items.length > 0) {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 8 }) {
            Text(this.uiText("pm_requests_393e1241")).fontSize(18).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_text')).layoutWeight(1).textAlign(TextAlign.Start)
            SymbolGlyph(PinmonyI18n.isRtl(this.uiLanguage) ? $r('sys.symbol.chevron_left') : $r('sys.symbol.chevron_right')).fontSize(18).fontColor([$r('app.color.secondary_text')]).margin({ left: PinmonyI18n.isRtl(this.uiLanguage) ? 0 : 8, right: PinmonyI18n.isRtl(this.uiLanguage) ? 8 : 0 })
          }.width('100%')
        }.width('100%').constraintSize({ minHeight: 36 }).padding(0).backgroundColor(Color.Transparent)
          .accessibilityText(this.uiText('pm_view_all_b92c0ea9')).enabled(this.interactionReady).onClick(() => this.onAll())
      }
      if (this.snapshot.loading && !this.refreshing && this.snapshot.items.length === 0) { LoadingProgress().color($r('app.color.accent')).width(24).height(24) }
      if (this.snapshot.error) { PinmonyActionNotice({ active: this.interactionReady && !this.snapshot.busy,
        message: PinmonyI18n.render(this.snapshot.error, this.uiLanguage), actionText: this.uiText('pm_retry_b8784c8d'), onAction: () => this.onReload() }) }
      ForEach(this.all ? this.snapshot.items : this.snapshot.items.slice(0, 1), (item: PinmonyBoardInvitation) => {
        Column({ space: 12 }) {
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
          if (this.invitationActionsInline(item)) { this.invitationActions(item) }
          Column({ space: 4 }) {
            Text(this.invitationTime(item).split('\n')[0]).fontSize(12)
              .fontColor($r('app.color.secondary_text')).maxLines(1)
            if (this.invitationTime(item).includes('\n')) {
              Text(this.invitationTime(item).split('\n')[1]).fontSize(12)
                .fontColor($r('app.color.secondary_text')).maxLines(1)
            }
          }.alignItems(HorizontalAlign.End).flexShrink(0).alignSelf(ItemAlign.Center)
          }.width('100%').alignItems(VerticalAlign.Center)
          if (!this.invitationActionsInline(item)) {
            Row() { this.invitationActions(item) }.width('100%').justifyContent(FlexAlign.End)
          }
        }.width('100%').alignItems(HorizontalAlign.Start)
          .onAreaChange((_old: Area, area: Area) => {
            const width: number = Number(area.width);
            if (Number.isFinite(width) && width > 0 && Math.abs(width - this.invitationCardWidth) > 0.5) this.invitationCardWidth = width;
          })
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
