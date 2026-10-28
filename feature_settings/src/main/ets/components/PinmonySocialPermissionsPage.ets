import { BlurStrategy, HdsNavigation, ScrollEffectType, hdsMaterial, HdsNavDestination, HdsNavDestinationTitleMode, HdsSnackBar, SnackBarIconType, SnackBarOperationType } from '@kit.UIDesignKit';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { PinmonySettingsStore } from '../stores/PinmonySettingsStore';
import { SocialBlockedUser, SocialMessageGroup, SocialMessageChoice } from '../models/PinmonySocialPermissions';
@Component
export struct PinmonySocialPermissionsPage {
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  private get immersiveLightEnabled(): boolean { return this.immersiveLightMode !== 'off'; }
  @StorageLink('pinmonyLanguage') @Watch('syncErrorSnack') private uiLanguage: string = 'zh';
  @ObjectLink @Watch('syncErrorSnack') store: PinmonySettingsStore;
  onBack?: () => void;
  onRequest?: (action: string, value: string) => void;
  @State private query: string = '';
  @State @Watch('syncErrorSnack') private confirming: boolean = false;
  @State private myPhraseDraft: string = '';
  @State private otherPhraseDraft: string = '';
  @State private myPhraseDraftActive: boolean = false;
  @State private otherPhraseDraftActive: boolean = false;
  private visible: boolean = false;
  private stack: NavPathStack = new NavPathStack();
  private scroller: Scroller = new Scroller();
  private suppressSwipeClick: boolean = false;
  private errorSnack: HdsSnackBar | undefined = undefined;
  private errorSnackKey: string = '';
  private dismissErrorSnack(): void { this.errorSnack?.dismiss(); this.errorSnackKey = ''; }
  private syncErrorSnack(): void {
    if (!this.visible || !this.store.error || this.store.busy || this.store.loading || this.confirming) {
      this.dismissErrorSnack(); return;
    }
    const key: string = this.store.screen + ':' + this.store.token + ':' + this.store.error + ':' + this.uiLanguage;
    if (key === this.errorSnackKey) return;
    this.dismissErrorSnack(); this.errorSnackKey = key;
    if (!this.errorSnack) this.errorSnack = new HdsSnackBar(this.getUIContext());
    this.errorSnack.show({ icon: $r('sys.symbol.exclamationmark_circle'), iconType: SnackBarIconType.NORMAL },
      { title: PinmonyI18n.render(this.store.error, this.uiLanguage) }, {
        operationType: SnackBarOperationType.TEXT_ONLY,
        content: this.uiText(this.store.writeUncertain || PinmonyI18n.isUnconfirmed(this.store.error) ? 'pm_reload_df7392cc' : 'pm_retry_b8784c8d'),
        contentAccessibilityText: this.uiText('pm_reload_current_settings_d2b82d8a'),
        onContentClick: () => {
          if (!this.visible || key !== this.errorSnackKey || this.store.busy || this.store.loading || this.confirming) return;
          this.dismissErrorSnack();
          if (this.onRequest) this.onRequest(this.store.screen === 'socialBlocked' ? 'socialBlocked' : 'socialRead', '');
        }
      }, { duration: 4000, pressBackCallback: () => {
        if (!this.visible || key !== this.errorSnackKey) return;
        this.dismissErrorSnack(); if (this.onBack) this.onBack();
      } });
  }
  private uiText(key: string): string { return PinmonyI18n.text(key, this.uiLanguage); }
  private messageTabLabel(id: number): string {
    return this.uiText(id === -1 ? 'pm_social_business_tab' : id === 0 ? 'pm_social_friends' : id === 1 ? 'pm_social_followers' : id === 2 ? 'pm_social_following' : 'pm_social_others_short');
  }
  private messageTabIds(): number[] { return this.store.social.business ? [-1,0,1,2,4] : [0,1,2,4]; }
  aboutToAppear(): void { this.visible = true; this.myPhraseDraftActive = false; this.otherPhraseDraftActive = false; this.stack.pushPath({ name: 'social' }, false); this.syncErrorSnack(); }
  aboutToDisappear(): void { this.visible = false; this.confirming = false; this.myPhraseDraftActive = false; this.otherPhraseDraftActive = false; this.dismissErrorSnack(); }
  private available(): boolean { return this.visible && !this.store.busy && !this.store.loading && !this.store.writeUncertain && !this.confirming; }
  private phraseServerValue(mine: boolean): string {
    const phrases: string[] = mine ? this.store.social.myCommentFilterPhrases || [] : this.store.social.otherCommentFilterPhrases || [];
    return phrases.join(', ');
  }
  private phraseDraftValue(mine: boolean): string {
    return mine ? this.myPhraseDraftActive ? this.myPhraseDraft : this.phraseServerValue(true) : this.otherPhraseDraftActive ? this.otherPhraseDraft : this.phraseServerValue(false);
  }
  private parsePhraseDraft(value: string): string[] | undefined {
    const phrases: string[] = value.split(',').map((item: string): string => item.trim()).filter((item: string): boolean => item.length > 0);
    if (phrases.length > 100 || phrases.some((item: string): boolean => item.length > 200 || item.includes('\n') || item.includes('\r'))) return undefined;
    if (phrases.some((item: string, index: number): boolean => phrases.indexOf(item) !== index)) return undefined;
    return phrases;
  }
  private updatePhraseDraft(mine: boolean, value: string): void {
    if (!this.available()) return;
    if (mine) { this.myPhraseDraft = value; this.myPhraseDraftActive = true; }
    else { this.otherPhraseDraft = value; this.otherPhraseDraftActive = true; }
  }
  private savePhraseFilter(mine: boolean): void {
    if (!this.available() || !this.store.social.ready || this.store.social.protected || mine && this.store.social.commentsEnabled !== true || !this.onRequest) return;
    const phrases: string[] | undefined = this.parsePhraseDraft(this.phraseDraftValue(mine));
    if (!phrases) { this.store.error = PinmonyI18n.message('pm_social_filter_invalid'); return; }
    const current: string[] = mine ? this.store.social.myCommentFilterPhrases || [] : this.store.social.otherCommentFilterPhrases || [];
    if (JSON.stringify(current) === JSON.stringify(phrases)) return;
    this.onRequest('socialCommentFilter', JSON.stringify({ target: mine ? 'mine' : 'others', phrases: phrases }));
  }
  @Builder
  private phraseFilterInput(mine: boolean) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        TextArea({ text: this.phraseDraftValue(mine), placeholder: this.uiText('pm_social_filter_phrases_placeholder') })
          .layoutWeight(1).height(96).maxLength(2000).fontSize(16).fontColor($r('app.color.primary_text'))
          .backgroundColor($r('app.color.input_surface')).border({ width: 1, color: $r('app.color.secondary_text'), radius: 12 })
          .onChange((value: string): void => { this.updatePhraseDraft(mine, value); })
        Button(this.uiText('pm_social_filter_phrases_done'), { type: ButtonType.Normal })
          .height(96).borderRadius(16).enabled(this.available()).onClick((): void => { this.savePhraseFilter(mine); })
      }.width('100%')
      Text(this.uiText('pm_social_filter_phrases_hint')).fontSize(14).fontColor($r('app.color.secondary_text')).width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, bottom: 12 })
  }
  @Builder
  private socialToggle(action: string, enabled: boolean | undefined, gated: boolean = false) {
    Column({ space: 4 }) {
      Row({ space: 16 }) {
        Text(this.uiText(action === 'socialComments' ? 'pm_social_comments' : action === 'socialShopping' ? 'pm_social_shopping' : action === 'socialIdeaDownloads' ? 'pm_social_idea_downloads' : action === 'mine' ? 'pm_social_filter_my_pins' : 'pm_social_filter_other_pins'))
          .fontSize(17).fontColor($r('app.color.primary_text')).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: enabled === true })
          .selectedColor($r('app.color.accent')).switchPointColor(Color.White)
          .enabled(this.available() && this.store.social.ready && !this.store.social.protected && !gated && enabled !== undefined)
          .accessibilityText(this.uiText(action === 'socialComments' ? 'pm_social_comments' : action === 'socialShopping' ? 'pm_social_shopping' : action === 'socialIdeaDownloads' ? 'pm_social_idea_downloads' : action === 'mine' ? 'pm_social_filter_my_pins' : 'pm_social_filter_other_pins'))
          .onChange((checked: boolean): void => {
            if (!this.onRequest || !this.available() || enabled === undefined || gated) return;
            if (action === 'mine' || action === 'others') this.onRequest('socialCommentFilter', action + ':' + checked.toString());
            else this.onRequest(action, checked.toString());
          })
      }.width('100%').constraintSize({ minHeight: 56 })
      if (action === 'socialComments' || action === 'mine' || action === 'others') {
        Text(this.uiText(action === 'socialComments' ? 'pm_social_comments_detail' : action === 'mine' ? 'pm_social_filter_my_detail' : 'pm_social_filter_other_detail')).fontSize(14).fontColor($r('app.color.secondary_text')).width('100%')
      }
      if ((action === 'mine' || action === 'others') && enabled === true && (action === 'others' || this.store.social.commentsEnabled === true)) this.phraseFilterInput(action === 'mine')
    }.width('100%')
  }
  private title(): string {
    const screens: string[] = ['socialComments','social','socialMessages','socialBlocked','socialMentions','socialFriends','socialFollowers','socialFollowing','socialOthers'];
    const titles: string[] = ['pm_social_comments_title','pm_social_title','pm_social_messages','pm_social_blocked','pm_social_mentions','pm_social_friends','pm_social_followers','pm_social_following',this.store.social.personal ? 'pm_social_others_short' : 'pm_social_others'];
    return this.uiText(titles[screens.indexOf(this.store.screen)] || 'pm_social_title');
  }
  private open(screen: string): void {
    if (!this.visible || this.store.busy || this.store.loading || this.confirming) return;
    if (screen === 'socialMessages' && this.store.social.business) this.store.socialMessageGroup = -1;
    this.store.token++; this.store.screen = screen; this.store.error = '';
    if (this.onRequest) this.onRequest(screen === 'socialBlocked' ? 'socialBlocked' : 'socialRead','');
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
  }
  private groupId(): number { return this.store.screen === 'socialMessages' && (this.store.social.personal || this.store.social.business) ? this.store.socialMessageGroup : this.store.screen === 'socialFriends' ? 0 : this.store.screen === 'socialFollowers' ? 1 : this.store.screen === 'socialFollowing' ? 2 : 4; }
  private selectMessageTab(index: number): void {
    if (!this.visible || this.store.screen !== 'socialMessages' || !(this.store.social.personal || this.store.social.business) || this.store.busy || this.store.loading || this.confirming || !Number.isInteger(index) || index < 0 || index >= this.messageTabIds().length) return;
    this.store.socialMessageGroup = this.messageTabIds()[index];
  }
  private swipeMessageTab(offsetX: number, offsetY: number): void {
    if (Math.abs(offsetX) < 48 || Math.abs(offsetX) <= Math.abs(offsetY) * 1.5) return;
    const selected: number = this.messageTabIds().indexOf(this.store.socialMessageGroup);
    if (selected < 0) return;
    this.selectMessageTab(selected + (offsetX < 0 ? 1 : -1));
  }
  private group(id: number): SocialMessageGroup | undefined { return this.store.social.groups.find((g: SocialMessageGroup): boolean => g.id === id); }
  private levelLabel(level: number): string { return this.uiText(level === 0 ? 'pm_social_direct' : level === 1 ? 'pm_social_requests' : 'pm_social_ignore'); }
  private selectionKey(level: number): string {
    const selected: number = this.store.screen === 'socialMentions' ? this.store.social.mentions ?? -1 : this.group(this.groupId())?.selected ?? -1;
    return this.store.screen + ':' + this.groupId() + ':' + level + ':' + this.store.token + ':' + selected + ':' + this.store.busy + ':' + this.store.loading + ':' + this.store.writeUncertain + ':' + this.store.social.ready + ':' + this.store.social.protected + ':' + this.store.social.myCommentFilterEnabled + ':' + this.store.social.otherCommentFilterEnabled + ':' + (this.store.social.myCommentFilterPhrases || []).join(',') + ':' + (this.store.social.otherCommentFilterPhrases || []).join(',') + ':' + this.uiLanguage;
  }
  private choose(level: number): void {
    if (this.suppressSwipeClick || !this.available() || !this.store.social.ready || this.store.social.protected || !this.onRequest) return;
    if (this.store.screen === 'socialMentions') { if (level !== this.store.social.mentions) this.onRequest('socialMentions',String(level)); }
    else { const group: SocialMessageGroup | undefined = this.group(this.groupId()); if (group && group.selected !== level && group.levels.includes(level)) { const choice: SocialMessageChoice = { group: group.id, level: level }; this.onRequest('socialMessage',JSON.stringify(choice)); } }
  }
  private blocked(): SocialBlockedUser[] {
    const query: string = this.query.trim().toLowerCase();
    return this.store.social.blocked.filter((u: SocialBlockedUser): boolean => !query || (u.name + ' @' + u.username).toLowerCase().includes(query));
  }
  private unblock(user: SocialBlockedUser): void {
    if (!this.available() || this.store.screen !== 'socialBlocked') return;
    const token: number = this.store.token;
    this.confirming = true;
    this.getUIContext().showAlertDialog({
      title: PinmonyI18n.format('pm_social_unblock_title',[user.name],this.uiLanguage), message: this.uiText('pm_social_unblock_description'), alignment: DialogAlignment.Bottom,
      primaryButton: { value: this.uiText('pm_cancel_2cd0f3be'), action: () => { this.confirming = false; } },
      secondaryButton: { value: this.uiText('pm_social_unblock'), fontColor: $r('app.color.accent'), action: () => {
        const current: boolean = this.confirming && this.visible && token === this.store.token && this.store.screen === 'socialBlocked'; this.confirming = false;
        if (current && this.available() && this.store.social.blocked.some((u: SocialBlockedUser): boolean => u.id === user.id) && this.onRequest) this.onRequest('socialUnblock',user.id);
      } }, cancel: () => { this.confirming = false; }
    });
  }
  @Builder
  private link(title: string, detail: string, target: string, requiresReady: boolean = false) {
    Button() {
      Column({ space: 6 }) {
        Row() { Text(this.uiText(title)).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).layoutWeight(1)
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([$r('app.color.secondary_text')])
        }.width('100%')
        if (detail) { Text(PinmonyI18n.render(detail, this.uiLanguage)).fontSize(16).fontColor($r('app.color.secondary_text')).width('100%') }
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ top:12,bottom:12 })
    }.width('100%').backgroundColor(Color.Transparent).padding(0).enabled(!this.store.busy && !this.store.loading && !this.confirming && (!requiresReady || this.store.social.ready)).onClick(() => this.open(target))
  }
  @Builder
  private selection(label: string, value: number, selected: number, messageOption: boolean = false) {
    Row() {
      Text(PinmonyI18n.render(label, this.uiLanguage)).fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text')).layoutWeight(1)
      Radio({ value: String(value), group: this.store.screen + ':' + this.groupId() }).checked(selected === value)
        .radioStyle({ checkedBackgroundColor: $r('app.color.accent'), indicatorColor: Color.White })
        .enabled(this.available() && this.store.social.ready && !this.store.social.protected)
        .accessibilityText(label).onChange((checked: boolean) => { if (checked) this.choose(value); })
    }.width('100%').constraintSize({ minHeight: messageOption ? 48 : 56 }).onClick(() => this.choose(value))
  }
  @Builder
  private messageChoices() {
    Text(this.uiText(this.groupId() === 0 ? 'pm_social_friends_detail' : this.groupId() === 1 ? 'pm_social_followers_detail' : this.groupId() === 2 ? 'pm_social_following_detail' : 'pm_social_others_detail')).fontSize(16).fontColor($r('app.color.primary_text'))
    Column({ space: 0 }) {
      ForEach(this.group(this.groupId())?.levels || [], (level: number) => { this.selection(this.levelLabel(level),level,this.group(this.groupId())!.selected,true) }, (level: number): string => this.selectionKey(level))
    }.width('100%')
  }
  @Builder
  private messageTabs() {
    Column({ space:16 }) {
      Scroll() {
        Row({ space:8 }) {
          ForEach(this.messageTabIds(), (id: number, index: number) => {
            Button(this.messageTabLabel(id), { type: ButtonType.Capsule })
              .height(36).padding({left:20,right:20}).fontSize(14).fontWeight(FontWeight.Medium)
              .backgroundColor(id === this.store.socialMessageGroup ? $r('app.color.accent') : $r('app.color.input_surface'))
              .fontColor(id === this.store.socialMessageGroup ? Color.White : $r('app.color.primary_text'))
              .enabled(!this.store.busy && !this.store.loading && !this.confirming)
              .accessibilitySelected(id === this.store.socialMessageGroup)
              .onClick(() => this.selectMessageTab(index))
          }, (id: number): string => id + ':' + this.store.socialMessageGroup + ':' + this.store.busy + ':' + this.store.loading + ':' + this.uiLanguage)
        }.height(36)
      }.width('100%').height(36).scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).align(Alignment.Start)
      Scroll(this.scroller) {
        Column({ space:16 }) {
          if (this.store.social.business && this.store.socialMessageGroup === -1) {
            Text(this.uiText('pm_social_business_messages')).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
            Text(this.uiText('pm_social_business_detail')).fontSize(16).fontColor($r('app.color.secondary_text'))
            Text(this.uiText('pm_social_unavailable')).fontSize(14).fontColor($r('app.color.secondary_text'))
          } else {
            this.messageChoices()
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ bottom:28 })
      }.width('100%').layoutWeight(1).align(Alignment.TopStart).edgeEffect(EdgeEffect.Spring,{alwaysEnabled:true})
        .parallelGesture(PanGesture({ direction: PanDirection.Horizontal, distance: 12 })
          .onActionStart(() => { this.suppressSwipeClick = true; })
          .onActionEnd((event: GestureEvent) => { this.swipeMessageTab(event.offsetX, event.offsetY); }))
    }.width('100%').height('100%').padding({left:20,right:20,top:0})
      .onTouch((event: TouchEvent) => { if (event.type === TouchType.Down) this.suppressSwipeClick = false; })
  }
  @Builder
  private shoppingAndDownloads() {
    Column({ space: 24 }) {
      Column({ space: 16 }) {
        Text(this.uiText('pm_social_shopping_section')).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
        Row({ space: 16 }) {
          Column({ space: 4 }) {
            Text(this.uiText('pm_social_shopping')).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text')).width('100%')
            Text(this.uiText('pm_social_shopping_detail')).fontSize(15).fontColor($r('app.color.secondary_text')).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          if (this.store.social.ready && this.store.social.shoppingRecommendationsEnabled !== undefined) {
          Toggle({ type: ToggleType.Switch, isOn: this.store.social.shoppingRecommendationsEnabled === true })
          .selectedColor($r('app.color.accent')).switchPointColor(Color.White)
            .enabled(this.available() && this.store.social.ready && !this.store.social.protected && this.store.social.shoppingRecommendationsEnabled !== undefined)
            .accessibilityText(this.uiText('pm_social_shopping'))
            .onChange((checked: boolean): void => { if (this.available() && this.onRequest) this.onRequest('socialShopping', String(checked)); })
          } else {
            Blank().width(48).height(48)
          }
        }.width('100%').alignItems(VerticalAlign.Top)
        Text(this.uiText('pm_social_shopping_exclusions')).fontSize(15).fontColor($r('app.color.secondary_text')).width('100%')
      }.width('100%').alignItems(HorizontalAlign.Start)
      Column({ space: 16 }) {
        Text(this.uiText('pm_social_download_section')).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
        Row({ space: 16 }) {
          Column({ space: 4 }) {
            Text(this.uiText('pm_social_idea_downloads')).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text')).width('100%')
            Text(this.uiText('pm_social_download_detail')).fontSize(15).fontColor($r('app.color.secondary_text')).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          if (this.store.social.ready && this.store.social.ideaPinDownloadsEnabled !== undefined) {
          Toggle({ type: ToggleType.Switch, isOn: this.store.social.ideaPinDownloadsEnabled === true })
          .selectedColor($r('app.color.accent')).switchPointColor(Color.White)
            .enabled(this.available() && this.store.social.ready && !this.store.social.protected && this.store.social.ideaPinDownloadsEnabled !== undefined)
            .accessibilityText(this.uiText('pm_social_idea_downloads'))
            .onChange((checked: boolean): void => { if (this.available() && this.onRequest) this.onRequest('socialIdeaDownloads', String(checked)); })
          } else {
            Blank().width(48).height(48)
          }
        }.width('100%').alignItems(VerticalAlign.Top)
      }.width('100%').alignItems(HorizontalAlign.Start)
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 12, bottom: 12 })
  }
  @Builder
  private body() {
    if (this.store.screen === 'social') {
      Text(this.uiText('pm_social_intro')).fontSize(16).fontColor($r('app.color.secondary_text'))
      this.link('pm_social_message_settings',this.uiText('pm_social_message_settings_detail'),'socialMessages')
      this.link('pm_social_blocked',this.uiText('pm_social_blocked_detail'),'socialBlocked')
      this.link('pm_social_mentions',this.uiText('pm_social_mentions_detail'),'socialMentions')
      this.link('pm_social_comments_title',this.uiText('pm_social_comments_entry_detail'),'socialComments',true)
      this.shoppingAndDownloads()
    } else if (this.store.screen === 'socialComments') {
      if (this.store.social.ready) {
        this.socialToggle('socialComments', this.store.social.commentsEnabled)
        this.socialToggle('mine', this.store.social.myCommentFilterEnabled, this.store.social.commentsEnabled !== true)
        this.socialToggle('others', this.store.social.otherCommentFilterEnabled)
      }
    } else if (this.store.screen === 'socialMessages') {
      if (this.store.social.ready && this.store.social.business) {
      Text(this.uiText('pm_social_business_messages')).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
      Text(this.uiText('pm_social_business_detail')).fontSize(16).fontColor($r('app.color.secondary_text'))
      Text(this.uiText('pm_social_unavailable')).fontSize(14).fontColor($r('app.color.secondary_text'))
      }
      Column({ space: 0 }) {
        this.link('pm_social_friends','', 'socialFriends')
        this.link('pm_social_followers','', 'socialFollowers')
        this.link('pm_social_following','', 'socialFollowing')
        this.link(this.store.social.personal ? 'pm_social_others_short' : 'pm_social_others','', 'socialOthers')
      }.width('100%')
    } else if (this.store.screen === 'socialBlocked') {
      Text(this.uiText('pm_social_blocked_intro')).fontSize(16).fontColor($r('app.color.secondary_text'))
      if (this.store.social.blocked.length) {
        Search({ value: this.query, placeholder: this.uiText('pm_social_search') }).onChange((value: string) => { this.query = value; }).width('100%')
        ForEach(this.blocked(), (user: SocialBlockedUser) => {
          Row({ space:12 }) {
            if (user.image) { Image(user.image).width(48).height(48).borderRadius(24).objectFit(ImageFit.Cover) }
            Column({ space:4 }) { Text(PinmonyI18n.render(user.name, this.uiLanguage)).fontColor($r('app.color.primary_text')); Text('@' + user.username).fontColor($r('app.color.secondary_text')) }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Button(this.uiText('pm_social_unblock')).enabled(this.available()).onClick(() => this.unblock(user))
          }.width('100%').padding({ top:12,bottom:12 })
        }, (user: SocialBlockedUser): string => (user.id) + ':' + this.uiLanguage)
        if (!this.blocked().length) { Text(this.uiText('pm_social_no_matches')).fontColor($r('app.color.secondary_text')) }
      } else if (this.store.social.blockedReady && this.store.social.blockedComplete && !this.store.loading && !this.store.error) { Text(this.uiText('pm_social_no_blocked')).width('100%').textAlign(TextAlign.Center).fontColor($r('app.color.secondary_text')).margin({ top:100 }) }
      if (this.store.social.blockedReady && !this.store.social.blockedComplete) { Text(this.uiText('pm_social_blocked_partial')).fontSize(14).fontColor($r('app.color.secondary_text')) }
    } else if (this.store.screen === 'socialMentions') {
      Text(this.uiText('pm_social_mentions_detail')).fontSize(16).fontColor($r('app.color.primary_text'))
      Column({ space: 4 }) {
        ForEach([0,1,2], (level: number) => { this.selection(this.uiText(level === 0 ? 'pm_social_mentions_anyone' : level === 1 ? 'pm_social_mentions_following' : 'pm_social_mentions_off'),level,this.store.social.mentions === undefined ? -1 : this.store.social.mentions) }, (level: number): string => this.selectionKey(level))
      }.width('100%')
    } else {
      this.messageChoices()
    }
  }
  @Builder
  private destination() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Center }) {
        ForEach([this.store.screen], (_screen: string) => {
        Column() {
        if (this.store.screen === 'socialMessages' && (this.store.social.personal || this.store.social.business)) {
          this.messageTabs()
        } else {
        Scroll(this.scroller) {
          Column({ space:16 }) {
            this.body()
          }.width('100%').alignItems(HorizontalAlign.Start).padding({ left:20,right:20,top:16,bottom:28 })
        }.width('100%').height('100%').align(Alignment.TopStart).edgeEffect(EdgeEffect.Spring,{alwaysEnabled:true})
        }
        }.width('100%').height('100%')
          .transition(this.store.screen === 'social' ? TransitionEffect.IDENTITY : TransitionEffect.asymmetric(
            TransitionEffect.translate({ x: '100%' }).animation({ duration: 180, curve: Curve.EaseOut }),
            TransitionEffect.IDENTITY))
        }, (screen: string): string => screen)
        if (this.store.loading || this.store.busy) { LoadingProgress().width(40).height(40).color($r('app.color.accent')).hitTestBehavior(HitTestMode.None) }
      }.width('100%').height('100%')
    }.titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: true,
      style: { blurStrategy: this.immersiveLightEnabled ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: this.immersiveLightEnabled, scrollEffectOpts: { enableScrollEffect: this.immersiveLightEnabled, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 }, contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },  backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 } } },
      content: { title: { mainTitle: this.title() }, backIcon: { isEnabled: true, action: () => { if (this.onBack) this.onBack(); } } } })
      .titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.scroller])
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .onBackPressed(() => { if (this.onBack) this.onBack(); return true; })
      .backgroundColor($r('app.color.page_background'))
  }
  build() {
    HdsNavigation(this.stack) {
      Column().width('100%').height('100%').backgroundColor($r('app.color.page_background'))
    }.width('100%').height('100%').hideTitleBar(true).navDestination(this.destination)
      .mode(NavigationMode.Stack)
      .backgroundColor($r('app.color.page_background'))
  }
}
