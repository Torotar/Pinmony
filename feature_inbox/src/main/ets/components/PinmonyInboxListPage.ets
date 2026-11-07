import { PinmonyHdsTitleBar } from 'common_ui';
import { PinmonyInboxActivityRow } from './PinmonyInboxActivityRow';
import { PinmonyInboxConversationSwipe } from './PinmonyInboxConversationSwipe';
import { LengthMetrics } from '@kit.ArkUI';
import { PinmonyActionNotice } from 'common_ui';
import { CapsuleSegmentButtonV2, SegmentButtonV2Items } from '@kit.ArkUI';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, BlurStrategy, ScrollEffectType } from '@kit.UIDesignKit';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyUserAvatar, PinmonyImmersiveLight } from 'common_ui';
import { PinmonyInboxItem, PinmonyInboxSnapshot } from '../models/PinmonyInbox';

@Component
export struct PinmonyInboxListPage {
  @StorageLink('systemDarkMode') private hdsDarkMode: boolean = false;
  @StorageLink('statusBarHeightPx') private statusBarHeightPx: number = 0;
  @State private listHeaderHeight: number = 0;
  @State private searchHeaderHeight: number = 0;
  private titleContentInset(): number { return this.getUIContext().px2vp(this.statusBarHeightPx) + 56; }
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  @StorageLink('pinmonyLanguage') @Watch('syncLabels') private uiLanguage: string = 'zh';
  @Prop snapshot: PinmonyInboxSnapshot;
  @Prop section: string = 'messages';
  @Prop actionsReady: boolean = false;
  @Prop @Watch('closeConversationActions') backActive: boolean = true;
  onCoveredBack?: () => boolean;
  onSection: (section: string) => void = () => {};
  onBack: () => void = () => {};
  onAction: (id: string) => void = () => {};
  onUser: (url: string) => void = () => {};
  onSearchBackChange: (handler: (() => boolean) | undefined) => void = () => {};
  onSearchClosed: () => void = () => {};
  onRetry: () => void = () => {};
  onContactsRetry: () => void = () => {};
  @State private searching: boolean = false;
  @State private messageQuery: string = '';
  @State private contactQuery: string = '';
  private readonly scroller: ListScroller = new ListScroller();
  private swipeReleaseTimer: number = -1;
  private conversationSwipeActive: boolean = false;
  private readonly searchScroller: ListScroller = new ListScroller();
  private readonly paths: NavPathStack = new NavPathStack();
  private readonly segments: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: this.text('pm_messages_4da199fa') }, { text: this.text('pm_contacts_3303b569') }
  ]);

  private text(key: string): string { return PinmonyI18n.text(key, this.uiLanguage); }
  private syncLabels(): void {
    this.segments[0].text = this.text('pm_messages_4da199fa');
    this.segments[1].text = this.text('pm_contacts_3303b569');
  }
  aboutToAppear(): void {
    this.syncLabels(); this.paths.pushPath({ name: 'inbox-list' }, false);
    this.onSearchBackChange((): boolean => {
      if (!this.searching) return false;
      this.closeSearch(); return true;
    });
  }
  aboutToDisappear(): void { this.closeConversationActions(); this.onSearchBackChange(undefined); }
  private openSearch(): void {
    if (this.searching) return;
    this.closeConversationActions();
    this.searching = true;
    this.paths.pushPath({ name: 'inbox-search' }, true);
  }
  private closeSearch(): void {
    if (!this.searching) return;
    this.closeConversationActions();
    this.onSearchClosed();
    this.searching = false;
    this.paths.pop(true);
  }
  private query(): string { return this.section === 'contacts' ? this.contactQuery : this.messageQuery; }
  private rows(search: boolean = true): PinmonyInboxItem[] {
    const query: string = (search ? this.query() : '').trim().replace(/^@/, '').toLowerCase();
    const rows: PinmonyInboxItem[] = this.section === 'activity' ? this.snapshot.activities || [] : this.section === 'contacts' ? this.snapshot.contacts : this.snapshot.items;
    if (!query) return rows;
    return rows.filter((item: PinmonyInboxItem): boolean => {
      const names: string[] = item.usernames || (this.section === 'contacts' && item.subtitle.startsWith('@') ?
        [item.subtitle.slice(1)] : item.profileUrl ? [item.profileUrl.split('/').filter((part: string): boolean => !!part).pop() || ''] : []);
      return names.some((name: string): boolean => name.toLowerCase().includes(query));
    });
  }
  private error(): string {
    return this.section === 'activity' ? this.snapshot.activityError || '' : this.section === 'contacts' ? this.snapshot.contactsError || '' : this.snapshot.apiError || '';
  }
  private loading(): boolean { return this.section === 'activity' ? !!this.snapshot.activityLoading : this.section === 'contacts' && !!this.snapshot.contactsLoading; }

  private selectSection(section: string): void {
    if (this.section === 'activity' || section === this.section) return;
    this.closeConversationActions();
    this.onSection(section);
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
  }

  private swipeSection(offsetX: number, offsetY: number): void {
    if(this.conversationSwipeActive)return;
    if (this.section === 'activity') return;
    if (Math.abs(offsetX) < 48 || Math.abs(offsetX) <= Math.abs(offsetY)) return;
    if (offsetX < 0 && this.section === 'messages') this.selectSection('contacts');
    else if (offsetX > 0 && this.section === 'contacts') this.selectSection('messages');
  }

  private openItemAvatar(item: PinmonyInboxItem): void {
    if(this.actionsReady && item.enabled && item.profileUrl)this.onUser(item.profileUrl);
  }

  @Builder
  private row(item: PinmonyInboxItem) {
    if (this.section === 'activity') {
      PinmonyInboxActivityRow({item:item,interactionReady:this.actionsReady,onAction:this.onAction,onUser:this.onUser})
    } else {
    Row({ space: 14 }) {
      Button({ type: ButtonType.Normal }) {
        PinmonyUserAvatar({ profileUrl: item.profileUrl || '', image: item.imageUrl, colorIndex: item.avatarColorIndex || 0, name: item.title, avatarSize: 48 })
      }.padding(0).borderRadius(24).backgroundColor(Color.Transparent).enabled(!!item.profileUrl)
        .accessibilityText(item.title).onClick(() => this.openItemAvatar(item))
      Button({ type: ButtonType.Normal }) {
      Row({ space: 14 }) {
        Column({ space: 4 }) {
          Text(PinmonyI18n.render(item.title, this.uiLanguage)).fontSize(16).fontWeight(item.unread ? FontWeight.Bold : FontWeight.Medium)
            .fontColor($r('app.color.primary_text')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (item.subtitle) {
            Text(PinmonyI18n.render(item.subtitle, this.uiLanguage)).fontSize(14).fontColor($r('app.color.secondary_text'))
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (this.section === 'messages' && item.timeLabel) {
          Column({ space: 4 }) {
            Text(PinmonyI18n.render(item.timeLabel.split('\n')[0], this.uiLanguage)).fontSize(12)
              .fontColor($r('app.color.secondary_text')).maxLines(1)
            if (item.timeLabel.includes('\n')) {
              Text(item.timeLabel.split('\n')[1]).fontSize(12).fontColor($r('app.color.secondary_text')).maxLines(1)
            }
          }.alignItems(HorizontalAlign.End).flexShrink(0)
        }
        if (this.section === 'contacts') {
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([$r('app.color.secondary_text')])
        }
      }.width('100%').alignItems(VerticalAlign.Center)
      }.layoutWeight(1).padding(0).backgroundColor(Color.Transparent)
        .accessibilityText(item.title + ' ' + item.subtitle).onClick(() => this.onAction(item.id))
    }.width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 })
      .backgroundColor(Color.Transparent).enabled(this.actionsReady && item.enabled)
    }
  }

  private closeConversationActions(): void {
    if (this.swipeReleaseTimer >= 0) clearTimeout(this.swipeReleaseTimer);
    this.swipeReleaseTimer = -1;
    this.conversationSwipeActive = false;
    try { this.scroller.closeAllSwipeActions(); this.searchScroller.closeAllSwipeActions(); }
    catch (_) { console.warn('Pinmony: inbox list swipe close unavailable'); }
  }

  private trackConversationTouch(event: TouchEvent, item: PinmonyInboxItem): void {
    if (event.type === TouchType.Down && this.backActive && this.actionsReady && item.enabled && /^conversation:\d{1,40}$/.test(item.id)) {
      if (this.swipeReleaseTimer >= 0) clearTimeout(this.swipeReleaseTimer);
      this.conversationSwipeActive = true;
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.swipeReleaseTimer = setTimeout(() => { this.conversationSwipeActive = false; this.swipeReleaseTimer = -1; }, 0);
    }
  }

  @Builder
  private removeConversationAction(item: PinmonyInboxItem) {
    PinmonyInboxConversationSwipe({ active: this.backActive && this.actionsReady && item.enabled,
      onRemove: () => { this.closeConversationActions(); this.onAction('conversation-remove:' + item.id.slice('conversation:'.length)); } })
  }

  @Builder
  private swipeRow(item: PinmonyInboxItem) {
    ListItem() { this.row(item) }
      .swipeAction({ end: this.section === 'messages' && this.backActive && this.actionsReady && item.enabled && /^conversation:\d{1,40}$/.test(item.id) ? {
        builder: () => { this.removeConversationAction(item); }
      } : undefined, edgeEffect: SwipeEdgeEffect.Spring })
      .onTouch((event: TouchEvent) => { if (this.section === 'messages') this.trackConversationTouch(event, item); })
  }

  @Builder
  private destination(name: string, _param?: Object) {
    if (name === 'inbox-search') { this.searchDestination() }
    else { this.listDestination() }
  }

  @Builder
  private listDestination() {
    HdsNavDestination() {
      Stack({alignContent:Alignment.TopStart}) {
        if (this.section !== 'activity') {
        Column() {
        Row() {
          CapsuleSegmentButtonV2({ items: this.segments, enableStateAnimation: true,
            selectedIndex: this.section === 'contacts' ? 1 : 0,
            onItemClicked: (index: number) => {
              this.selectSection(index === 0 ? 'messages' : 'contacts');
            } }) .width('100%').constraintSize({ maxWidth: 360 })
        }.width('100%').justifyContent(FlexAlign.Center).padding({ left: 20, right: 20, top: 12, bottom: 12 })
        }.width('100%').margin({top:this.titleContentInset()}).backgroundColor($r('app.color.page_background')).zIndex(1)
          .onAreaChange((_old:Area,area:Area) => {this.listHeaderHeight = Number(area.height);})
        }
        List({ scroller: this.scroller, space: 8 }) {
          ListItem() { Column().width('100%').height(Math.max(0, this.titleContentInset() + (this.section === 'activity' ? 0 : this.listHeaderHeight) - 8)) }
            .accessibilityLevel('no-hide-descendants')
            if (this.loading() && this.section !== 'activity') { ListItem() { LoadingProgress().color($r('app.color.accent')).width(28).height(28) } }
            if (this.error()) {
              ListItem() { PinmonyActionNotice({ message: PinmonyI18n.render(this.error(), this.uiLanguage), actionText: this.text('pm_retry_b8784c8d'), onAction: () => {
                if (this.section === 'activity') this.onAction('activity-retry'); else if (this.section === 'contacts') this.onContactsRetry(); else this.onRetry();
              } }) }
            }
            ForEach(this.rows(false), (item: PinmonyInboxItem) => { this.swipeRow(item) },
              (item: PinmonyInboxItem): string => (item.id + ':' + item.title + ':' + item.subtitle + ':' + item.timeLabel + ':' + item.unread + ':' + item.updatedAt + ':' + item.imageUrl + ':' + item.activityFollowed + ':' + item.activityBusy + ':' + item.activityUncertain) + ':' + this.uiLanguage)
            if (!this.loading() && !this.error() && this.rows(false).length === 0) {
              ListItem() { Text(this.text(this.section === 'activity' ? 'pm_activity_empty' : this.section === 'contacts' ? 'pm_no_suggested_contacts_03b9d232' : 'pm_your_conversations_will_appear_here_2f066d17'))
                .fontColor($r('app.color.secondary_text')).padding(24) }
            }
        }.width('100%').height('100%').constraintSize({ maxWidth: 720 }).align(Alignment.Top).scrollBar(BarState.Auto)
          .contentEndOffset(32)
          .scrollBarMargin({start:LengthMetrics.vp(this.titleContentInset() + (this.section === 'activity' ? 0 : this.listHeaderHeight))})
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .parallelGesture(PanGesture({ direction: PanDirection.Horizontal, distance: 24 })
            .onActionEnd((event: GestureEvent) => this.swipeSection(event.offsetX, event.offsetY)))
        if (this.section === 'activity' && this.loading() && this.rows(false).length === 0) {
          Column() {
            LoadingProgress().width(28).height(28).color($r('app.color.accent'))
          }.width('100%').height('100%').padding({top:this.titleContentInset()})
            .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center).hitTestBehavior(HitTestMode.None)
        }
      }.width('100%').height('100%').backgroundColor($r('app.color.page_background'))
    }.width('100%').height('100%')
      .titleBar(PinmonyHdsTitleBar.resolve(this.getUIContext(), { avoidLayoutSafeArea: true, enableComponentSafeArea: false,
      style: { blurStrategy: (this.immersiveLightMode !== 'off') ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: (this.immersiveLightMode !== 'off'), scrollEffectOpts: { enableScrollEffect: (this.immersiveLightMode !== 'off'), scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: (this.immersiveLightMode !== 'off') ? 18 : 0 }, contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },  backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: (this.immersiveLightMode !== 'off') ? 18 : 0 } } },
        content: { title: { mainTitle: this.text(this.section === 'activity' ? 'pm_activity_title' : 'pm_inbox_63a5e7b7') },
          backIcon: { isEnabled: true, action: () => this.onBack() },
          menu: { value: [{ content: { icon: $r('app.media.inbox_search_outline'), label: this.text('pm_search_44ce7ae9'),
            action: () => this.openSearch() } }] } } }, this.hdsDarkMode))
      .titleMode(HdsNavDestinationTitleMode.MINI).hideTitleBar(false).hideBackButton(false)
      .bindToScrollable([this.scroller]).backgroundColor($r('app.color.page_background'))
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .onBackPressed(() => {
        if (!this.backActive) { this.onCoveredBack?.(); return true; }
        this.onBack(); return true;
      })
  }

  @Builder
  private searchDestination() {
    HdsNavDestination() {
      Stack({alignContent:Alignment.TopStart}) {
        Column() {
        if (this.searching) {
          Search({ value: this.query(), placeholder: this.text('pm_inbox_search_username') })
            .onChange((value: string) => {
              this.closeConversationActions();
              if (this.section === 'contacts') this.contactQuery = value;
              else this.messageQuery = value;
              this.searchScroller.scrollTo({ xOffset: 0, yOffset: 0 });
            }).margin({ left: 20, right: 20, bottom: 12 })
        }
        }.width('100%').margin({top:this.titleContentInset()}).backgroundColor($r('app.color.page_background')).zIndex(1)
          .onAreaChange((_old:Area,area:Area) => {this.searchHeaderHeight = Number(area.height);})
        List({ scroller: this.searchScroller, space: 8 }) {
          ListItem() { Column().width('100%').height(Math.max(0, this.titleContentInset() + this.searchHeaderHeight - 8)) }
            .accessibilityLevel('no-hide-descendants')
            if (this.loading() && this.section !== 'activity') { ListItem() { LoadingProgress().color($r('app.color.accent')).width(28).height(28) } }
            if (this.error()) {
              ListItem() { PinmonyActionNotice({ message: PinmonyI18n.render(this.error(), this.uiLanguage), actionText: this.text('pm_retry_b8784c8d'), onAction: () => {
                if (this.section === 'activity') this.onAction('activity-retry'); else if (this.section === 'contacts') this.onContactsRetry(); else this.onRetry();
              } }) }
            }
            ForEach(this.rows(), (item: PinmonyInboxItem) => { this.swipeRow(item) },
              (item: PinmonyInboxItem): string => (item.id + ':' + item.title + ':' + item.subtitle + ':' + item.timeLabel + ':' + item.unread + ':' + item.updatedAt + ':' + item.imageUrl + ':' + item.activityFollowed + ':' + item.activityBusy + ':' + item.activityUncertain) + ':' + this.uiLanguage)
            if (!this.loading() && !this.error() && this.rows().length === 0) {
              ListItem() { Text(this.text(this.query().trim() ? 'pm_inbox_no_matching_username' :
                this.section === 'activity' ? 'pm_activity_empty' : this.section === 'contacts' ? 'pm_no_suggested_contacts_03b9d232' : 'pm_your_conversations_will_appear_here_2f066d17'))
                .fontColor($r('app.color.secondary_text')).padding(24) }
            }
        }.width('100%').height('100%').constraintSize({ maxWidth: 720 }).align(Alignment.Top).scrollBar(BarState.Auto)
          .contentEndOffset(32)
          .scrollBarMargin({start:LengthMetrics.vp(this.titleContentInset() + this.searchHeaderHeight)})
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        if (this.section === 'activity' && this.loading() && this.rows(false).length === 0) {
          Column() {
            LoadingProgress().width(28).height(28).color($r('app.color.accent'))
          }.width('100%').height('100%').padding({top:this.titleContentInset()})
            .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center).hitTestBehavior(HitTestMode.None)
        }
      }.width('100%').height('100%').backgroundColor($r('app.color.page_background'))
    }.width('100%').height('100%')
      .titleBar(PinmonyHdsTitleBar.resolve(this.getUIContext(), { avoidLayoutSafeArea: true, enableComponentSafeArea: false,
      style: { blurStrategy: (this.immersiveLightMode !== 'off') ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: (this.immersiveLightMode !== 'off'), scrollEffectOpts: { enableScrollEffect: (this.immersiveLightMode !== 'off'), scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: (this.immersiveLightMode !== 'off') ? 18 : 0 }, contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },  backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: (this.immersiveLightMode !== 'off') ? 18 : 0 } } },
        content: { title: { mainTitle: this.text('pm_search_44ce7ae9') },
          backIcon: { isEnabled: true, action: () => this.closeSearch() },
          menu: { value: [] } } }, this.hdsDarkMode))
      .titleMode(HdsNavDestinationTitleMode.MINI).hideTitleBar(false).hideBackButton(false)
      .bindToScrollable([this.searchScroller]).backgroundColor($r('app.color.page_background'))
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .onBackPressed(() => {
        if (!this.backActive) { this.onCoveredBack?.(); return true; }
        this.closeSearch(); return true;
      })
  }

  build() {
    HdsNavigation(this.paths) {
      Column().width('100%').height('100%').backgroundColor($r('app.color.page_background'))
    }.width('100%').height('100%').hideTitleBar(true)
      .navDestination(this.destination)
      .mode(NavigationMode.Stack)
      .backgroundColor($r('app.color.page_background'))
  }
}
