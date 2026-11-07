import { PinmonyHdsTitleBar } from 'common_ui';
import { PinmonyInboxActivityRow } from './PinmonyInboxActivityRow';
import { PinmonyInboxConversationSwipe } from './PinmonyInboxConversationSwipe';
import { LengthMetrics } from '@kit.ArkUI';
import { PinmonyActionNotice, PinmonyImmersiveLight } from 'common_ui';
import { BlurStrategy, HdsNavigation, HdsNavigationTitleBarOptions, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { PinmonyI18n } from 'common_foundation';
import { CapsuleSegmentButtonV2, ColorMetrics, SegmentButtonV2Items } from '@kit.ArkUI';
import { PinmonyInboxItem, PinmonyInboxSnapshot } from '../models/PinmonyInbox';
import { PinmonyBoardInvitation, PinmonyBoardInvitations } from '../models/PinmonyBoardInvitation';
import { PinmonyBoardInvitationList } from './PinmonyBoardInvitationList';
import { PinmonyUserAvatar } from 'common_ui';

interface PinmonyInboxSegmentBadgeOptions {
  label: string;
  count: number;
}

interface PinmonyInboxUpdatesGroupOptions {
  label: string;
  items: PinmonyInboxItem[];
}

@Component
export struct PinmonyInboxPage {
  @StorageLink('systemDarkMode') private hdsDarkMode: boolean = false;
  @StorageProp('statusBarHeightPx') private statusBarHeightPx: number = 0;
  @StorageProp('systemDarkMode') private systemDarkMode: boolean = false;
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  private inboxTopInset(): number { return this.getUIContext().px2vp(this.statusBarHeightPx) + 56; }
  @State private inboxRefreshState: RefreshStatus = RefreshStatus.Inactive;
  @StorageLink('pinmonyRootScrollTop2') @Watch('onRootScrollTop') private rootScrollTop: number = 0;
  private onRootScrollTop(): void {
    try {
      const scroller: Scroller = this.activeContentScroller();
      const offset: number = scroller.offset()?.yOffset || 0;
      if (offset <= 1) {
        if (!(this.refreshing || this.loading) && this.onRefresh) this.onRefresh();
      } else {
        scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: true });
      }
    } catch (_) {}
  }

  @StorageLink('pinmonyLanguage') @Watch('syncSegmentItems') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop @Watch('onSnapshotChanged') snapshot: PinmonyInboxSnapshot = {} as PinmonyInboxSnapshot;
  @Prop actionsReady: boolean = true;
  @Prop sectionReady: boolean = true;
  @Prop @Watch('closeConversationActions') interactionReady: boolean = true;
  @Prop retainedContent: boolean = false;
  @Prop updatesUnread: boolean = false;
  @Prop messagesUnread: boolean = false;
  @Prop updatesUnreadCount: number = 0;
  @Prop messagesUnreadCount: number = 0;
  @Prop initialScrollOffset: number = 0;
  onContentScroll?: (offset: number, state: ScrollState) => void;
  onScrollAvailability?: (scrollable: boolean) => void;
  onScrollPosition?: (pageUrl: string, section: string, offset: number) => void;
  private readonly scroller: ListScroller = new ListScroller();
  private readonly updatesScroller: Scroller = new Scroller();
  private scrollRestoreGeneration: number = 0;
  private readonly rowHeights: Map<string, number> = new Map<string, number>();
  private swipeReleaseTimer: number = -1;
  private activeSection: string = '';
  private conversationSwipeActive: boolean = false;
  private segmentUpdateLabel: string = '';
  private segmentInboxLabel: string = '';
  @State private segmentSelectedIndex: number = 0;
  private readonly inboxSegmentsBuilder: () => void = (): void => { this.inboxSegments(); };
  private readonly segmentItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: this.uiText("pm_updates_3055a035") }, { text: this.uiText("pm_inbox_63a5e7b7") }
  ]);

  private segmentBackgroundColor(): ColorMetrics | undefined {
    try {
      return ColorMetrics.resourceColor($r('app.color.surface_muted'));
    } catch (_) {
      // Let the segment use its theme default if the color resource is unavailable.
      return undefined;
    }
  }

  private syncSegmentItems(): void {
    const selectedIndex: number = this.snapshot.section === 'messages' ? 1 : 0;
    if (this.segmentSelectedIndex !== selectedIndex) this.segmentSelectedIndex = selectedIndex;
    const update: string = PinmonyI18n.render(this.snapshot.updateLabel || PinmonyI18n.message("pm_updates_3055a035"), this.uiLanguage);
    const inbox: string = PinmonyI18n.render(this.snapshot.inboxLabel || PinmonyI18n.message("pm_inbox_63a5e7b7"), this.uiLanguage);
    if (this.segmentUpdateLabel === update && this.segmentInboxLabel === inbox) return;
    this.segmentUpdateLabel = update;
    this.segmentInboxLabel = inbox;
    this.segmentItems[0].text = update;
    this.segmentItems[1].text = inbox;
  }

  @State private sectionOpacity: number = 1;
  private restoringScroll: boolean = false;
  private lastReportedScrollOffset: number = -1;
  private contentHeight: number = 0;
  private viewportHeight: number = 0;
  @Prop loading: boolean = false;
  @Prop refreshing: boolean = false;
  onRefresh?: () => void;
  @Prop error: string = '';
  onSection?: (section: string) => void;
  onUser?: (url: string) => void;
  onAction?: (id: string) => void;
  onHome?: () => void;
  onList?: (section: string) => void;
  onRetry?: () => void;
  onLoadMore?: () => void;
  onContactsRetry?: () => void;
  @Prop invitations: PinmonyBoardInvitations | undefined = undefined;
  onInvitationPreview: (item: PinmonyBoardInvitation) => void = () => {};
  onInvitationAll: () => void = () => {};

  aboutToAppear(): void {
    this.syncSegmentItems();
    this.activeSection = this.snapshot.section;
    this.restoringScroll = this.initialScrollOffset > 0;
    if (this.onScrollAvailability) this.onScrollAvailability(false);
  }

  private closeConversationActions(): void {
    if (this.swipeReleaseTimer >= 0) clearTimeout(this.swipeReleaseTimer);
    this.swipeReleaseTimer = -1;
    this.conversationSwipeActive = false;
    try { this.scroller.closeAllSwipeActions(); } catch (_) { console.warn('Pinmony: inbox swipe close unavailable'); }
  }

  private trackConversationTouch(event: TouchEvent, item: PinmonyInboxItem): void {
    if (event.type === TouchType.Down && this.interactionReady && item.enabled && /^conversation:\d{1,40}$/.test(item.id)) {
      if (this.swipeReleaseTimer >= 0) clearTimeout(this.swipeReleaseTimer);
      this.conversationSwipeActive = true;
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.swipeReleaseTimer = setTimeout(() => { this.conversationSwipeActive = false; this.swipeReleaseTimer = -1; }, 0);
    }
  }

  @Builder
  private removeConversationAction(item: PinmonyInboxItem) {
    PinmonyInboxConversationSwipe({ active: this.interactionReady && item.enabled,
      onRemove: () => { this.closeConversationActions(); this.onAction?.('conversation-remove:' + item.id.slice('conversation:'.length)); } })
  }

  aboutToDisappear(): void { this.scrollRestoreGeneration++; this.closeConversationActions(); }

  private activeContentScroller(): Scroller {
    return this.snapshot.section === 'updates' ? this.updatesScroller : this.scroller;
  }

  private measureListPart(key: string, height: number): void {
    if (this.snapshot.section !== 'messages') return;
    this.rowHeights.set(key, height);
    this.updateListHeight();
  }

  private updateListHeight(): void {
    if (this.snapshot.section !== 'messages') return;
    this.contentHeight = (this.rowHeights.get('prefix') || 0) + (this.rowHeights.get('footer') || 0);
    if (this.snapshot.section === 'messages') {
      this.snapshot.items.forEach((item: PinmonyInboxItem) => { this.contentHeight += this.rowHeights.get(item.id) || 0; });
    }
    this.reportScrollAvailability();
  }

  private onSnapshotChanged(): void {
    this.syncSegmentItems();
    this.rowHeights.forEach((_height: number, key: string) => {
      if (key !== 'prefix' && key !== 'footer' && !this.snapshot.items.some((item: PinmonyInboxItem): boolean => item.id === key)) this.rowHeights.delete(key);
    });
    this.updateListHeight();
    if (this.activeSection === this.snapshot.section) return;
    this.closeConversationActions();
    this.activeSection = this.snapshot.section;
    this.lastReportedScrollOffset = -1;
    this.sectionOpacity = 0;
    this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
      this.sectionOpacity = 1;
    });
    // Each segment starts expanded; layout determines whether its own
    // content permits scroll-driven bottom-bar collapse.
    if (this.onScrollAvailability) this.onScrollAvailability(false);
    this.restoreScroll();
  }

  private restoreScroll(): void {
    this.restoringScroll = true;
    const generation: number = ++this.scrollRestoreGeneration;
    const section: string = this.snapshot.section;
    const page: string = this.snapshot.pageUrl;
    const scroller: Scroller = this.activeContentScroller();
    const offset: number = Math.max(0, this.initialScrollOffset);
    // Retained lists can restore before the first return frame; the deferred pass handles a new mount.
    try {
      const current = scroller.offset();
      if (current && Math.abs(current.yOffset - offset) > 0.5) scroller.scrollTo({ xOffset: 0, yOffset: offset, animation: false });
    } catch (_) { console.warn('Pinmony: inbox immediate restoration unavailable'); }
    setTimeout(() => {
      if (generation !== this.scrollRestoreGeneration || section !== this.snapshot.section || page !== this.snapshot.pageUrl) return;
      try { scroller.scrollTo({ xOffset: 0, yOffset: offset, animation: false }); }
      catch (_) { console.warn('Pinmony: inbox scroll restoration unavailable'); }
      this.restoringScroll = false;
      this.reportScrollAvailability();
    }, 0);
  }

  private loadMoreUpdatesAtEnd(): void {
    if (!this.interactionReady || !this.actionsReady || this.restoringScroll || this.loading || this.refreshing ||
        this.snapshot.section !== 'updates' || this.snapshot.dataSource !== 'api' ||
        this.snapshot.moreLoading || this.snapshot.moreError || !this.snapshot.hasMore) return;
    if (this.onLoadMore) this.onLoadMore();
  }

  private contentOverflowsViewport(): boolean {
    return Number.isFinite(this.contentHeight) && Number.isFinite(this.viewportHeight) &&
      this.viewportHeight > 0 && this.contentHeight > this.viewportHeight + 1;
  }

  private reportScrollAvailability(): void {
    if (this.onScrollAvailability) this.onScrollAvailability(this.contentOverflowsViewport());
  }

  private releaseScrollMeasurements(): void {
    this.contentHeight = 0;
    this.viewportHeight = 0;
    this.reportScrollAvailability();
  }

  private reportScroll(force: boolean = false): void {
    if (this.restoringScroll || this.interactionReady === false) return;
    try {
      const position = this.activeContentScroller().offset();
      if (!position) return;
      const offset: number = Math.max(0, position.yOffset);
      if (!force && this.lastReportedScrollOffset >= 0 && Math.abs(offset - this.lastReportedScrollOffset) < 1) return;
      this.lastReportedScrollOffset = offset;
      if (this.onScrollPosition) this.onScrollPosition(this.snapshot.pageUrl, this.snapshot.section, offset);
    } catch (_) { console.warn('Pinmony: inbox scroll position unavailable'); }
  }

  private selectSection(section: string): void {
    if (!this.refreshing && this.interactionReady && section !== this.snapshot.section &&
        ((!this.loading && !this.error) || this.snapshot.dataSource === 'api') && this.onSection) this.onSection(section);
  }

  private swipeSection(offsetX: number, offsetY: number): void {
    if(this.conversationSwipeActive)return;
    if (Math.abs(offsetX) < 48 || Math.abs(offsetX) <= Math.abs(offsetY)) return;
    if (offsetX < 0 && this.snapshot.section === 'updates') this.selectSection('messages');
    else if (offsetX > 0 && this.snapshot.section === 'messages') this.selectSection('updates');
  }

  private timeText(item: PinmonyInboxItem): string {
    if (item.timeLabel) return item.timeLabel;
    if (!item.updatedAt) return '';
    const date: number = Date.parse(item.updatedAt);
    const minutes: number = Math.floor((Date.now() - date) / 60000);
    if (!Number.isFinite(date) || minutes < 0) return '';
    if (minutes < 60) return minutes.toString() + this.uiText("pm_minutes_40de5434");
    if (minutes < 1440) return Math.floor(minutes / 60).toString() + this.uiText("pm_hours_8f82ece0");
    return Math.floor(minutes / 1440).toString() + this.uiText("pm_days_4ce3054e");
  }

  @Builder
  private groupTitle(label: string) {
    Text(PinmonyI18n.render(label, this.uiLanguage))
      .fontSize(18)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.primary_text'))
      .width('100%')
      .textAlign(TextAlign.Start)
      .padding({ left: 20, right: 20, top: 16, bottom: 8 })
  }

  @Builder
  private listTitle(label: string, section: string) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 8 }) {
        Text(PinmonyI18n.render(label, this.uiLanguage)).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
          .layoutWeight(1).textAlign(TextAlign.Start)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([$r('app.color.secondary_text')])
          .margin({ left: 8 })
      }.width('100%')
    }.width('100%').backgroundColor(Color.Transparent).padding({ left: 20, right: 20, top: 16, bottom: 8 })
      .stateEffect(false)
      .accessibilityText(label).onClick(() => { if (this.interactionReady && this.onList) this.onList(section); })
  }

  private messageUnreadCount(item: PinmonyInboxItem): number {
    if(item.unread === false)return 0;
    return typeof item.unreadCount === 'number' && Number.isSafeInteger(item.unreadCount) && item.unreadCount >= 0 ? item.unreadCount : item.unread === true ? 1 : 0;
  }

  private updateRowKey(item: PinmonyInboxItem): string {
    return JSON.stringify([item.id, item.title, item.subtitle, item.imageUrl, item.profileUrl || '',
      item.timeLabel || '', item.updatedAt || '', String(item.unread), String(item.unreadCount), String(item.outgoing === true),
      String(item.enabled), String(item.subdued === true), item.moreId || '', (item.usernames || []).join(','), this.uiLanguage]);
  }

  @Builder
  private updatesGroup($$: PinmonyInboxUpdatesGroupOptions) {
    if ($$.items.length > 0) {
      if ($$.label) { this.groupTitle($$.label) }
      ForEach($$.items, (item: PinmonyInboxItem) => { this.itemRow(item, false) },
        (item: PinmonyInboxItem) => this.updateRowKey(item))
    }
  }

  private openItemAvatar(item: PinmonyInboxItem, contact: boolean): void {
    if(!this.interactionReady || !item.enabled)return;
    if(contact || this.snapshot.section === 'messages') {
      if(item.profileUrl)this.onUser?.(item.profileUrl);
      return;
    }
    if(item.profileUrl)this.onUser?.(item.profileUrl); else this.onAction?.(item.id);
  }

  @Builder
  private itemRow(item: PinmonyInboxItem, contact: boolean = true) {
    Row({ space: 14 }) {
      if (item.imageUrl && !contact && !item.profileUrl && !/\/user\/default(?:[/_.-]|$)/i.test(item.imageUrl)) {
        Stack({ alignContent: Alignment.BottomEnd }) {
          Image(item.imageUrl).width(48).height(48).borderRadius(24).objectFit(ImageFit.Cover)
          if (/评论了|commented on/i.test(item.title)) {
            Image($r('app.media.lucide_message_circle')).width(14).height(14)
              .fillColor($r('app.color.secondary_text')).padding(5).width(24).height(24)
              .backgroundColor($r('app.color.surface_muted')).borderRadius(12)
              .accessibilityLevel('no').hitTestBehavior(HitTestMode.None)
          } else if (/点赞了|liked your/i.test(item.title)) {
            Image($r('app.media.lucide_heart_filled')).width(14).height(14)
              .fillColor($r('app.color.accent')).padding(5).width(24).height(24)
              .backgroundColor($r('app.color.surface_muted')).borderRadius(12)
              .accessibilityLevel('no').hitTestBehavior(HitTestMode.None)
          }
        }.width(48).height(48)
          .onClick(() => this.openItemAvatar(item, contact))
      } else {
        PinmonyUserAvatar({ profileUrl: item.profileUrl || '', image: item.imageUrl, colorIndex: item.avatarColorIndex || 0, name: item.title, avatarSize: 48 })
          .onClick(() => this.openItemAvatar(item, contact))
      }
      Column({ space: 4 }) {
        Text(PinmonyI18n.render(item.title, this.uiLanguage))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary_text'))
          .width('100%')
          .textAlign(TextAlign.Start)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (item.subtitle) {
          Row({ space: 4 }) {
            if (item.outgoing) { SymbolGlyph($r('sys.symbol.arrow_up_circle')).fontSize(14).fontColor([$r('app.color.secondary_text')]) }
          Text(PinmonyI18n.render(item.subtitle, this.uiLanguage))
            .fontSize(14)
            .fontColor($r('app.color.secondary_text'))
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          }.width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onClick(() => { if (item.enabled && this.onAction) this.onAction(item.id); })
      if (!contact && this.snapshot.section === 'messages' && this.messageUnreadCount(item) > 0) {
        Text(this.messageUnreadCount(item) > 99 ? '99+' : this.messageUnreadCount(item).toString())
          .fontSize(10).fontColor($r('app.color.detail_on_accent')).height(18)
          .constraintSize({ minWidth: 18 }).padding({ left: 4, right: 4 }).textAlign(TextAlign.Center)
          .borderRadius(9).backgroundColor($r('app.color.detail_save_accent')).flexShrink(0)
          .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      }
      if (!contact && (this.snapshot.section === 'updates' || this.timeText(item) || item.moreId)) {
        Column({ space: 8 }) {
          if (this.timeText(item)) {
            Column({ space: 4 }) {
              if (this.timeText(item).includes('\n')) {
                Text(this.timeText(item).split('\n')[1])
                  .fontSize(12).fontColor($r('app.color.secondary_text')).maxLines(1)
              }
              Text(PinmonyI18n.render(this.timeText(item).split('\n')[0], this.uiLanguage))
                .fontSize(12).fontColor($r('app.color.secondary_text')).maxLines(1)
            }.alignItems(HorizontalAlign.End)
          }
          if (this.snapshot.section === 'updates' || item.moreId) {
            Button({ type: ButtonType.Circle }) {
              Row({ space: 3 }) {
                ForEach([0, 1, 2], (dot: number) => {
                  Circle().width(3).height(3).fill(this.snapshot.section === 'updates' ?
                    $r('app.color.primary_text') : $r('app.color.secondary_text'))
                })
              }
            }
              .padding(0).backgroundColor(Color.Transparent).width(40).height(40)
              .visibility(item.moreId ? Visibility.Visible : Visibility.Hidden)
              .accessibilityText(this.uiText("pm_more_actions_9f07d2ce"))
              .onClick(() => {
                if (item.moreId && this.onAction) this.onAction(item.moreId);
              })
          }
        }.constraintSize({ minWidth: 40 }).flexShrink(0).alignItems(HorizontalAlign.End).alignSelf(ItemAlign.Center)
      } else if (contact && item.enabled) {
        SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontColor([$r('app.color.secondary_text')])
        .margin({ left: 8 })
        .onClick(() => { if (item.enabled && this.onAction) this.onAction(item.id); })
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
    .opacity(item.subdued ? 0.45 : 1)
    .accessibilityDescription((item.enabled ? '' : this.uiText("pm_service_unavailable_87f44469")) +
      (!contact && this.snapshot.section === 'messages' && this.messageUnreadCount(item) > 0 ? ' ' + PinmonyI18n.format('pm_inbox_unread_message_count', [this.messageUnreadCount(item)], this.uiLanguage) : ''))
    .accessibilityText(item.title + (item.subtitle ? '，' + item.subtitle : ''))
  }

  @Builder
  private emptyState() {
    Column({ space: 12 }) {
      Image(this.snapshot.section === 'updates' ?
        $r('app.media.inbox_updates_reference') : $r('app.media.inbox_messages_reference'))
        .width(this.snapshot.section === 'updates' ? 220 : 190)
        .height(this.snapshot.section === 'updates' ? 220 : 190)
        .objectFit(ImageFit.Contain)
        .accessibilityLevel('no')
      Text(PinmonyI18n.render(this.snapshot.emptyTitle, this.uiLanguage))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.primary_text'))
        .textAlign(TextAlign.Center)
        .margin({ top: 4 })
      Text(PinmonyI18n.render(this.snapshot.emptyDescription, this.uiLanguage))
        .fontSize(15)
        .lineHeight(23)
        .fontColor($r('app.color.primary_text'))
        .textAlign(TextAlign.Center)
        .maxLines(5)
      if (this.snapshot.section === 'updates' && this.snapshot.homeId && PinmonyI18n.render(this.snapshot.homeLabel, this.uiLanguage)) {
        Button(PinmonyI18n.render(this.snapshot.homeLabel, this.uiLanguage))
          .fontSize(15)
          .fontColor($r('app.color.primary_text'))
          .backgroundColor($r('app.color.surface_muted'))
          .borderRadius(16)
          .height(42)
          .margin({ top: 8 })
          .onClick(() => { if (this.onHome) this.onHome(); })
      }
    }
    .width('100%')
    .padding({ left: 24, right: 24 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private segmentUnreadBadge($$: PinmonyInboxSegmentBadgeOptions) {
    Row({ space: 4 }) {
      Row() {}
        .width($$.count > 99 ? 28 : $$.count > 9 ? 22 : 18).height(18).flexShrink(0)
      Text($$.label).fontSize(16).fontWeight(FontWeight.Medium).fontColor(Color.Transparent).flexShrink(0)
      Text($$.count > 99 ? '99+' : $$.count.toString())
        .fontSize(10).fontColor($r('app.color.detail_on_accent')).height(18)
        .width($$.count > 99 ? 28 : $$.count > 9 ? 22 : 18).textAlign(TextAlign.Center)
        .borderRadius(9).backgroundColor($r('app.color.detail_save_accent'))
        .flexShrink(0).offset({ y: -8 })
    }.width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
  }

  @Builder
  private inboxSegments() {
    Column() {
      if (this.snapshot.updateLabel && this.snapshot.inboxLabel) {
        Stack({ alignContent: Alignment.Start }) {
          CapsuleSegmentButtonV2({
            items: this.segmentItems,
            buttonBackgroundColor: this.segmentBackgroundColor(),
            buttonBackgroundBlurStyle: BlurStyle.NONE,
            enableStateAnimation: true,
            selectedIndex: this.segmentSelectedIndex,
            onItemClicked: (index: number) => {
              this.selectSection(index === 0 ? 'updates' : 'messages');
            }
          })
          .width('100%')
          if (this.updatesUnread) {
            Row() {
              this.segmentUnreadBadge({ label: PinmonyI18n.render(this.snapshot.updateLabel, this.uiLanguage), count: this.updatesUnreadCount })
            }.width('50%').height('100%').justifyContent(FlexAlign.Center)
              .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
          }
        }
        .width('100%')
        .height(56)
        .accessibilityDescription(this.updatesUnread || this.messagesUnread ? PinmonyI18n.format('pm_inbox_unread_counts', [this.updatesUnreadCount, this.messagesUnreadCount], this.uiLanguage) : '')
        .padding({ left: 20, right: 20, top: 4, bottom: 4 })
      }
    }.width('100%').height(56)
  }

  @Builder
  private inboxRefreshIndicator() {
    Column() {
      LoadingProgress().width(24).height(24).color($r('app.color.accent'))
      .visibility(this.refreshing || this.inboxRefreshState === RefreshStatus.Drag ||
        this.inboxRefreshState === RefreshStatus.OverDrag ? Visibility.Visible : Visibility.Hidden)
    }.width('100%').height(64).justifyContent(FlexAlign.Center)
      .offset({ y: this.inboxTopInset() })
      .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private updatesContent() {
    Scroll(this.updatesScroller) {
      Column() {
            if (this.snapshot.items.length === 0 && PinmonyI18n.render(this.snapshot.emptyTitle, this.uiLanguage)) {
              Column() {
                this.emptyState()
              }
              .width('100%')
              .padding({ top: this.snapshot.section === 'updates' ? 120 : 24,
                bottom: this.snapshot.section === 'updates' ? 48 : 12 })
            }
            if (this.snapshot.section === 'updates') {
              this.updatesGroup({ label: PinmonyI18n.render(this.snapshot.unreadLabel || '', this.uiLanguage) || this.uiText("pm_unread_4d0680f9"),
                items: this.snapshot.items.filter((item: PinmonyInboxItem) => item.unread === true) })
              this.updatesGroup({ label: PinmonyI18n.render(this.snapshot.readLabel || '', this.uiLanguage) || this.uiText("pm_read_efdd1a47"),
                items: this.snapshot.items.filter((item: PinmonyInboxItem) => item.unread === false) })
              this.updatesGroup({ label: '', items: this.snapshot.items.filter((item: PinmonyInboxItem) => item.unread === undefined) })
            }

            if (this.snapshot.section === 'updates' && this.snapshot.dataSource === 'api') {
              if (this.snapshot.moreLoading) {
                LoadingProgress().color($r('app.color.accent')).width(28).height(28).alignSelf(ItemAlign.Center)
              } else if (this.snapshot.moreError) {
                PinmonyActionNotice({ active: this.interactionReady, message: PinmonyI18n.render(this.snapshot.moreError, this.uiLanguage), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => { if (this.interactionReady && !this.snapshot.moreLoading && this.onLoadMore) this.onLoadMore(); } })
              } else if (this.snapshot.items.length === 0 && !PinmonyI18n.render(this.snapshot.emptyTitle, this.uiLanguage)) {
                Text(this.uiText("pm_no_updates_yet_7891215d")).fontColor($r('app.color.secondary_text')).alignSelf(ItemAlign.Center)
              }
            }
      }.width('100%').alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Start)
        .constraintSize({ maxWidth: 720 })
        .padding({ top: this.inboxTopInset(), bottom: 120 })
        .onAreaChange((_old: Area, area: Area) => {
          if (this.snapshot.section !== 'updates') return;
          this.contentHeight = Number(area.height);
          this.reportScrollAvailability();
        })
    }.layoutWeight(1).width('100%').align(Alignment.TopStart).scrollBar(BarState.Off)
      .scrollBarMargin({ start: LengthMetrics.vp(this.inboxTopInset()) })
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }).clip(false)
      .onAreaChange((_old: Area, area: Area) => { if (this.snapshot.section === 'updates') { this.viewportHeight = Number(area.height); this.reportScrollAvailability(); } })
      .onAppear(() => this.restoreScroll())
      .onDisAppear(() => { if (this.snapshot.section === 'updates') this.releaseScrollMeasurements(); })
      .onReachEnd(() => this.loadMoreUpdatesAtEnd())
      .onDidScroll((_xOffset: number, offset: number, state: ScrollState) => {
        if (this.snapshot.section !== 'updates') return;
        this.reportScroll();
        this.reportScrollAvailability();
        if (!this.restoringScroll && this.contentOverflowsViewport() && this.onContentScroll) this.onContentScroll(offset, state);
      })
      .onScrollStop(() => { if (this.snapshot.section === 'updates') this.reportScroll(true); })
  }

  @Builder
  private inboxContent() {
    Column() {
      Refresh({ refreshing: this.refreshing, builder: this.inboxRefreshIndicator }) {
      Column() {
      if (this.loading || (this.error && !this.retainedContent)) {
        Column({ space: 16 }) {
          if (this.loading) {
            LoadingProgress().color($r('app.color.accent'))
              .width(28)
              .height(28)
            Text(this.uiText("pm_loading_inbox_b0cbe6ba"))
              .fontSize(15)
              .fontColor($r('app.color.secondary_text'))
          } else {
            PinmonyActionNotice({ active: this.interactionReady, message: PinmonyI18n.render(this.error, this.uiLanguage), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => { if (this.onRetry) this.onRetry(); } })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 24, right: 24, top: this.inboxTopInset(), bottom: 110 })
      } else {
        if (this.error) {
          Row({ space: 12 }) {
            PinmonyActionNotice({ active: this.interactionReady, message: PinmonyI18n.render(this.error, this.uiLanguage), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => { if (this.onRetry) this.onRetry(); } })
          }.padding({ left: 20, right: 20, bottom: 12 }).width('100%')
        }
        if (this.snapshot.section === 'updates') {
          this.updatesContent()
        } else {
        // Keep the title inset inside the content: scrollTo(0) must preserve it.
        List({ scroller: this.scroller }) {
          ListItem() {
            Column() {
            if (this.snapshot.section === 'messages' && this.invitations && this.invitations.items.length > 0) {
              PinmonyBoardInvitationList({ snapshot: this.invitations, onPreview: this.onInvitationPreview, onAll: this.onInvitationAll })
            }
            if (this.snapshot.section === 'messages') {
              Row({ space: 12 }) {
                Stack({ alignContent: Alignment.Center }) {
                  Image($r('app.media.lucide_pen_line')).width(28).height(28)
                    .accessibilityLevel('no')
                }.width(54)
                  .height(54)
                  .borderRadius(18)
                  .backgroundColor($r('app.color.detail_accent'))
                Text(PinmonyI18n.render(this.snapshot.composeLabel, this.uiLanguage) || this.uiText("pm_new_message_3fc957bf"))
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.primary_text'))
                  .layoutWeight(1)
                  .textAlign(TextAlign.Start)
                SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18)
                  .fontColor([$r('app.color.secondary_text')])
                  .accessibilityLevel('no')
              }
              .width('100%')
              .padding({ left: 18, right: 20, top: 18, bottom: 18 })
              .accessibilityText(PinmonyI18n.render(this.snapshot.composeLabel, this.uiLanguage))
              .enabled(!!this.snapshot.composeId)
              .onClick(() => {
                if (this.interactionReady && this.snapshot.composeId && this.onAction) this.onAction(this.snapshot.composeId);
              })
            }

            if (this.snapshot.section === 'messages') {
              this.listTitle(this.uiText('pm_activity_title'), 'activity')
              if (this.snapshot.activityError) {
                PinmonyActionNotice({ active:this.interactionReady,message:PinmonyI18n.render(this.snapshot.activityError,this.uiLanguage),
                  actionText:this.uiText('pm_retry_b8784c8d'),onAction:() => {if(this.interactionReady)this.onAction?.('activity-retry');} })
              }
              ForEach((this.snapshot.activities || []).slice(0,2), (item: PinmonyInboxItem) => {
                PinmonyInboxActivityRow({item:item,interactionReady:this.interactionReady,
                  onAction:(id: string) => this.onAction?.(id),onUser:(url: string) => this.onUser?.(url)})
              }, (item: PinmonyInboxItem): string => this.updateRowKey(item) + ':' + item.updatedAt + ':' + item.activityFollowed + ':' + item.activityBusy + ':' + item.activityUncertain)
              if (!this.snapshot.activityLoading && !this.snapshot.activityError && !(this.snapshot.activities || []).length) {
                Text(this.uiText('pm_activity_empty')).fontColor($r('app.color.secondary_text')).padding(20)
              }
            }

            if (this.snapshot.section === 'messages' && this.snapshot.items.length > 0) {
              this.listTitle(PinmonyI18n.render(this.snapshot.messagesLabel || '', this.uiLanguage) || this.uiText("pm_messages_4da199fa"), 'messages')
            }
            }.width('100%').alignItems(HorizontalAlign.Start)
              .padding({ top: this.inboxTopInset() })
          }.onAreaChange((_old: Area, area: Area) => this.measureListPart('prefix', Number(area.height)))
          if (this.snapshot.section === 'messages') {
            ForEach(this.snapshot.items, (item: PinmonyInboxItem) => {
              ListItem() { this.itemRow(item, false) }
                .swipeAction({ end: this.interactionReady && item.enabled && /^conversation:\d{1,40}$/.test(item.id) ? {
                  builder: () => { this.removeConversationAction(item); }
                } : undefined, edgeEffect: SwipeEdgeEffect.Spring })
                .onTouch((event: TouchEvent) => this.trackConversationTouch(event, item))
                .onAreaChange((_old: Area, area: Area) => this.measureListPart(item.id, Number(area.height)))
            }, (item: PinmonyInboxItem) => this.updateRowKey(item))
          }
          ListItem() {
            Column() {
            if (this.snapshot.items.length === 0 && PinmonyI18n.render(this.snapshot.emptyTitle, this.uiLanguage)) {
              Column() { this.emptyState() }.width('100%').padding({ top: 24, bottom: 12 })
            }
            if (this.snapshot.section === 'messages' &&
              (PinmonyI18n.render(this.snapshot.contactsLabel, this.uiLanguage) || this.snapshot.contacts.length > 0)) {
              this.listTitle(PinmonyI18n.render(this.snapshot.contactsLabel, this.uiLanguage) ||
                this.uiText("pm_contacts_3303b569"), 'contacts')
              if (this.snapshot.contactsLoading) {
                Row({ space: 12 }) {
                  LoadingProgress().color($r('app.color.accent')).width(24).height(24)
                  Text(this.uiText("pm_loading_contacts_54858f2d")).fontSize(14).fontColor($r('app.color.secondary_text'))
                }.padding({ left: 20, top: 12, bottom: 12 })
              } else if (this.snapshot.contactsError) {
                Column({ space: 8 }) {
                  PinmonyActionNotice({ active: this.interactionReady, message: PinmonyI18n.render(this.snapshot.contactsError, this.uiLanguage), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => { if (this.onContactsRetry) this.onContactsRetry(); } })
                }.alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, top: 12 })
              } else if (this.snapshot.contacts.length > 0) {
                ForEach(this.snapshot.contacts, (item: PinmonyInboxItem) => {
                  this.itemRow(item)
                }, (item: PinmonyInboxItem) => this.updateRowKey(item))
              } else if (this.snapshot.contactsDataSource === 'api') {
                Text(this.uiText("pm_no_suggested_contacts_03b9d232")).fontSize(14).fontColor($r('app.color.secondary_text'))
                  .padding({ left: 20, top: 12, bottom: 12 })
              }
            }
            }.width('100%').alignItems(HorizontalAlign.Start)
              .padding({ bottom: 120 })
          }.onAreaChange((_old: Area, area: Area) => this.measureListPart('footer', Number(area.height)))
        }
        .constraintSize({ maxWidth: 720 })
        .layoutWeight(1)
        .width('100%')
        .align(Alignment.TopStart)
        .scrollBar(BarState.Off)
        .scrollBarMargin({start:LengthMetrics.vp(this.inboxTopInset())})
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .clip(false)
        .onAreaChange((_oldArea: Area, newArea: Area) => {
          if (this.snapshot.section !== 'messages') return;
          this.viewportHeight = Number(newArea.height);
          this.reportScrollAvailability();
        })
        .onAppear(() => this.restoreScroll())
        .onDisAppear(() => { if (this.snapshot.section === 'messages') this.releaseScrollMeasurements(); })
        .onReachEnd(() => this.loadMoreUpdatesAtEnd())
        .onDidScroll((offset: number, state: ScrollState) => {
          if (this.snapshot.section !== 'messages') return;
          this.reportScroll();
          this.reportScrollAvailability();
          if (!this.restoringScroll && this.contentOverflowsViewport() && this.onContentScroll) {
            this.onContentScroll(offset, state);
          }
        })
        .onScrollStop(() => { if (this.snapshot.section === 'messages') this.reportScroll(true); })
        }
      }
      }.width('100%').height('100%')
      }
      .width('100%').layoutWeight(1)
      .pullToRefresh(!this.refreshing && !this.loading)
      .onRefreshing(() => { if (this.onRefresh) this.onRefresh(); })
      .onStateChange((state: RefreshStatus) => { this.inboxRefreshState = state; })
    }
    .width('100%')
    .height('100%')
    .clip(false)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .backgroundColor($r('app.color.page_background'))
    .parallelGesture(PanGesture({ direction: PanDirection.Horizontal, distance: 24 })
      .onActionEnd((event: GestureEvent) => this.swipeSection(event.offsetX, event.offsetY)))
  }

  private inboxTitleBarOptions(): HdsNavigationTitleBarOptions {
    return {
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false,
      style: {
        blurStrategy: this.immersiveLightMode !== 'off' ? BlurStrategy.ENABLE : BlurStrategy.DISABLE,
        thermoCtrl: this.immersiveLightMode !== 'off',
        scrollEffectOpts: { enableScrollEffect: this.immersiveLightMode !== 'off',
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        originalStyle: { backgroundStyle: { maskExtraHeight: 0, blurRadius: this.immersiveLightMode !== 'off' ? 18 : 0 } },
        scrollEffectStyle: { backgroundStyle: { maskExtraHeight: 0, blurRadius: this.immersiveLightMode !== 'off' ? 18 : 0 } },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode)
      },
      content: { stackBuilder: this.inboxSegmentsBuilder }
    };
  }

  build() {
    HdsNavigation() { this.inboxContent() }
      .width('100%').height('100%')
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(true)
      .titleBar(PinmonyHdsTitleBar.resolve(this.getUIContext(), this.inboxTitleBarOptions(), this.hdsDarkMode))
      .systemBarStyle({ statusBarContentColor: this.systemDarkMode ? '#F7F8FA' : '#1B1E25' },
        { statusBarContentColor: this.systemDarkMode ? '#F7F8FA' : '#1B1E25' })
      .bindToScrollable([this.updatesScroller, this.scroller])
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .clip(false)
  }
}


