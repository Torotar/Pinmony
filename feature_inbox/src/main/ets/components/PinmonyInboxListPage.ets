import { CapsuleSegmentButtonV2, SegmentButtonV2Items } from '@kit.ArkUI';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, BlurStrategy, ScrollEffectType } from '@kit.UIDesignKit';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyUserAvatar, PinmonyImmersiveLight } from 'common_ui';
import { PinmonyInboxItem, PinmonyInboxSnapshot } from '../models/PinmonyInbox';

@Component
export struct PinmonyInboxListPage {
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  private get immersiveLightEnabled(): boolean { return this.immersiveLightMode !== 'off'; }
  @StorageLink('pinmonyLanguage') @Watch('syncLabels') private uiLanguage: string = 'zh';
  @Prop snapshot: PinmonyInboxSnapshot;
  @Prop section: string = 'messages';
  @Prop actionsReady: boolean = false;
  onSection: (section: string) => void = () => {};
  onBack: () => void = () => {};
  onAction: (id: string) => void = () => {};
  onSearchBackChange: (handler: (() => boolean) | undefined) => void = () => {};
  onSearchClosed: () => void = () => {};
  onRetry: () => void = () => {};
  onContactsRetry: () => void = () => {};
  @State private searching: boolean = false;
  @State private messageQuery: string = '';
  @State private contactQuery: string = '';
  private readonly scroller: Scroller = new Scroller();
  private readonly searchScroller: Scroller = new Scroller();
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
  aboutToDisappear(): void { this.onSearchBackChange(undefined); }
  private openSearch(): void {
    if (this.searching) return;
    this.searching = true;
    this.paths.pushPath({ name: 'inbox-search' }, true);
  }
  private closeSearch(): void {
    if (!this.searching) return;
    this.onSearchClosed();
    this.searching = false;
    this.paths.pop(true);
  }
  private query(): string { return this.section === 'contacts' ? this.contactQuery : this.messageQuery; }
  private rows(search: boolean = true): PinmonyInboxItem[] {
    const query: string = (search ? this.query() : '').trim().replace(/^@/, '').toLowerCase();
    const rows: PinmonyInboxItem[] = this.section === 'contacts' ? this.snapshot.contacts : this.snapshot.items;
    if (!query) return rows;
    return rows.filter((item: PinmonyInboxItem): boolean => {
      const names: string[] = item.usernames || (this.section === 'contacts' && item.subtitle.startsWith('@') ?
        [item.subtitle.slice(1)] : item.profileUrl ? [item.profileUrl.split('/').filter((part: string): boolean => !!part).pop() || ''] : []);
      return names.some((name: string): boolean => name.toLowerCase().includes(query));
    });
  }
  private error(): string {
    return this.section === 'contacts' ? this.snapshot.contactsError || '' : this.snapshot.apiError || '';
  }
  private loading(): boolean { return this.section === 'contacts' && !!this.snapshot.contactsLoading; }

  private selectSection(section: string): void {
    if (section === this.section) return;
    this.onSection(section);
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
  }

  private swipeSection(offsetX: number, offsetY: number): void {
    if (Math.abs(offsetX) < 48 || Math.abs(offsetX) <= Math.abs(offsetY)) return;
    if (offsetX < 0 && this.section === 'messages') this.selectSection('contacts');
    else if (offsetX > 0 && this.section === 'contacts') this.selectSection('messages');
  }

  @Builder
  private row(item: PinmonyInboxItem) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 14 }) {
        PinmonyUserAvatar({ image: item.imageUrl, name: item.title, avatarSize: 48 })
        Column({ space: 4 }) {
          Text(PinmonyI18n.render(item.title, this.uiLanguage)).fontSize(16).fontWeight(item.unread ? FontWeight.Bold : FontWeight.Medium)
            .fontColor($r('app.color.primary_text')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (item.subtitle) {
            Text(PinmonyI18n.render(item.subtitle, this.uiLanguage)).fontSize(14).fontColor($r('app.color.secondary_text'))
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (this.section === 'messages' && item.timeLabel) {
          Text(item.timeLabel).fontSize(12).fontColor($r('app.color.secondary_text'))
        }
        if (this.section === 'contacts') {
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([$r('app.color.secondary_text')])
        }
      }.width('100%')
    }.width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 })
      .backgroundColor(Color.Transparent).enabled(this.actionsReady && item.enabled)
      .accessibilityText(item.title + ' ' + item.subtitle).onClick(() => this.onAction(item.id))
  }

  @Builder
  private destination(name: string, _param?: Object) {
    if (name === 'inbox-search') { this.searchDestination() }
    else { this.listDestination() }
  }

  @Builder
  private listDestination() {
    HdsNavDestination() {
      Column() {
        Row() {
          CapsuleSegmentButtonV2({ items: this.segments, enableStateAnimation: true,
            selectedIndex: this.section === 'contacts' ? 1 : 0,
            onItemClicked: (index: number) => {
              this.selectSection(index === 0 ? 'messages' : 'contacts');
            } }) .width(280)
        }.width('100%').justifyContent(FlexAlign.Center).padding({ top: 12, bottom: 12 })
        Scroll(this.scroller) {
          Column({ space: 8 }) {
            if (this.loading()) { LoadingProgress().width(28).height(28) }
            if (this.error()) {
              Text(PinmonyI18n.render(this.error(), this.uiLanguage)).fontColor($r('app.color.secondary_text')).padding(20)
              Button(this.text('pm_retry_b8784c8d')).onClick(() => {
                if (this.section === 'contacts') this.onContactsRetry(); else this.onRetry();
              })
            }
            ForEach(this.rows(false), (item: PinmonyInboxItem) => { this.row(item) },
              (item: PinmonyInboxItem): string => (item.id + ':' + item.title + ':' + item.subtitle + ':' + item.timeLabel + ':' + item.unread) + ':' + this.uiLanguage)
            if (!this.loading() && !this.error() && this.rows(false).length === 0) {
              Text(this.text(this.section === 'contacts' ? 'pm_no_suggested_contacts_03b9d232' : 'pm_your_conversations_will_appear_here_2f066d17'))
                .fontColor($r('app.color.secondary_text')).padding(24)
            }
          }.width('100%').constraintSize({ maxWidth: 720 }).padding({ bottom: 32 })
        }.width('100%').layoutWeight(1).align(Alignment.Top).scrollBar(BarState.Auto)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .parallelGesture(PanGesture({ direction: PanDirection.Horizontal, distance: 24 })
            .onActionEnd((event: GestureEvent) => this.swipeSection(event.offsetX, event.offsetY)))
      }.width('100%').height('100%').backgroundColor($r('app.color.page_background'))
    }.width('100%').height('100%')
      .titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: true,
      style: { blurStrategy: this.immersiveLightEnabled ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: this.immersiveLightEnabled, scrollEffectOpts: { enableScrollEffect: this.immersiveLightEnabled, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 }, contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },  backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 } } },
        content: { title: { mainTitle: this.text('pm_inbox_63a5e7b7') },
          backIcon: { isEnabled: true, action: () => this.onBack() },
          menu: { value: [{ content: { icon: $r('app.media.inbox_search_outline'), label: this.text('pm_search_44ce7ae9'),
            action: () => this.openSearch() } }] } } })
      .titleMode(HdsNavDestinationTitleMode.MINI).hideTitleBar(false).hideBackButton(false)
      .bindToScrollable([this.scroller]).backgroundColor($r('app.color.page_background'))
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .onBackPressed(() => { this.onBack(); return true; })
  }

  @Builder
  private searchDestination() {
    HdsNavDestination() {
      Column() {
        if (this.searching) {
          Search({ value: this.query(), placeholder: this.text('pm_inbox_search_username') })
            .onChange((value: string) => {
              if (this.section === 'contacts') this.contactQuery = value;
              else this.messageQuery = value;
              this.searchScroller.scrollTo({ xOffset: 0, yOffset: 0 });
            }).margin({ left: 20, right: 20, bottom: 12 })
        }
        Scroll(this.searchScroller) {
          Column({ space: 8 }) {
            if (this.loading()) { LoadingProgress().width(28).height(28) }
            if (this.error()) {
              Text(PinmonyI18n.render(this.error(), this.uiLanguage)).fontColor($r('app.color.secondary_text')).padding(20)
              Button(this.text('pm_retry_b8784c8d')).onClick(() => {
                if (this.section === 'contacts') this.onContactsRetry(); else this.onRetry();
              })
            }
            ForEach(this.rows(), (item: PinmonyInboxItem) => { this.row(item) },
              (item: PinmonyInboxItem): string => (item.id + ':' + item.title + ':' + item.subtitle + ':' + item.timeLabel + ':' + item.unread) + ':' + this.uiLanguage)
            if (!this.loading() && !this.error() && this.rows().length === 0) {
              Text(this.text(this.query().trim() ? 'pm_inbox_no_matching_username' :
                this.section === 'contacts' ? 'pm_no_suggested_contacts_03b9d232' : 'pm_your_conversations_will_appear_here_2f066d17'))
                .fontColor($r('app.color.secondary_text')).padding(24)
            }
          }.width('100%').constraintSize({ maxWidth: 720 }).padding({ bottom: 32 })
        }.width('100%').layoutWeight(1).align(Alignment.Top).scrollBar(BarState.Auto)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      }.width('100%').height('100%').backgroundColor($r('app.color.page_background'))
    }.width('100%').height('100%')
      .titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: true,
      style: { blurStrategy: this.immersiveLightEnabled ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: this.immersiveLightEnabled, scrollEffectOpts: { enableScrollEffect: this.immersiveLightEnabled, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 }, contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },  backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 } } },
        content: { title: { mainTitle: this.text('pm_search_44ce7ae9') },
          backIcon: { isEnabled: true, action: () => this.closeSearch() },
          menu: { value: [] } } })
      .titleMode(HdsNavDestinationTitleMode.MINI).hideTitleBar(false).hideBackButton(false)
      .bindToScrollable([this.searchScroller]).backgroundColor($r('app.color.page_background'))
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .onBackPressed(() => { this.closeSearch(); return true; })
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
