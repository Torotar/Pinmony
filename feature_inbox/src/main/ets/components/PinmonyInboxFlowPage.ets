import { PinmonyActionNotice } from 'common_ui';
import { BlurStrategy } from '@kit.UIDesignKit';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyRuntimeLog } from 'common_foundation';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, TextStyleMode, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
import { InboxFlowUser, InboxFlowMessage, PinmonyInboxFlowSnapshot } from '../models/PinmonyInboxFlow';
import { PinmonyUserAvatar } from 'common_ui';
import { PinmonyInboxBoardCard } from './PinmonyInboxBoardCard';
import { PinmonyChatScrollPosition } from '../services/PinmonyChatScrollPosition';
interface ReactionPopupState { isVisible: boolean; }

@Component
export struct PinmonyInboxFlowPage {
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  private get immersiveLightEnabled(): boolean { return this.immersiveLightMode !== 'off'; }
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop @Watch('snapshotChanged') snapshot: PinmonyInboxFlowSnapshot = {} as PinmonyInboxFlowSnapshot;
  onUser?: (url: string) => void;
  onAction?: (action: string, value: string) => void;
  onPin?: (url: string) => void;
  onBoard?: (messageId: string) => void;
  onCopyText?: (text: string) => Promise<boolean>;
  @Prop restoreOffset: number = -1;
  @Prop @Watch('activeChanged') active: boolean = true;
  onOffset?: (offset: number) => void;
  onNotifications?: () => void;
  onPinAction?: (action: string, url: string) => void;
  onNewsHidden?: (newsId: string) => void;
  onNewsRestored?: (newsId: string) => void;
  onPinUnsubscribed?: () => void;
  onBlockChanged?: (blocked: boolean, userName: string) => void;
  private scroller: Scroller = new Scroller();
  private readonly chatPosition: PinmonyChatScrollPosition = new PinmonyChatScrollPosition();
  private viewportHeight: number = 0;
  private presentedConversation: string = '';
  private visible: boolean = false;
  @State private query: string = '';
  @State private draft: string = '';
  @State private imageRatios: Map<string, number> = new Map<string, number>();
  private textControllers: Map<string, TextController> = new Map<string, TextController>();
  @State private textAvatarOffsets: Map<string, number> = new Map<string, number>();
  @State private senderLabelHeights: Map<string, number> = new Map<string, number>();
  @State private selectedMessage: InboxFlowMessage | undefined = undefined;
  @State private showMessageMenu: boolean = false;
  @State private reactionMessageId: string = '';
  @State private blockTarget: InboxFlowUser | undefined = undefined;
  private historyPending: boolean = false;
  private contentHeight: number = 0;
  private settingsReturnOffset: number = -1;
  private previousScreen: string = '';
  private historyHeight: number = 0;
  private historyOffset: number = 0;
  private sentRevision: number = 0;
  @State private showUpdatesMenu: boolean = false;
  private presentedNewsId: string = '';
  private queryToken: number = 0;
  private lastHiddenNewsId: string = '';
  private lastRestoredNewsId: string = '';
  private lastBlockRevision: number = 0;
  private flowPathStack: NavPathStack = new NavPathStack();
  // HDS invokes this as its own callback. Capture the page explicitly while
  // keeping a stable callback identity across scroll and snapshot updates.
  private readonly conversationTitleBuilder: () => void = (): void => { this.conversationTitle(); };
  aboutToAppear(): void {
    this.visible = true;
    this.flowPathStack.pushPath({ name: 'inbox-flow' }, false);
    this.prepareChatPosition();
  }
  aboutToDisappear(): void {
    this.visible = false; this.queryToken++;
    // Do not pop the destination while its final frame is being removed.
    // The stack belongs to this component and is released with it.
  }

  private messageConfirmationKey(): string {
    return this.snapshot.pageUrl + ':' + (this.snapshot.conversationId || '') + ':' + (this.snapshot.nativeAccountGeneration === undefined ?
      this.snapshot.session.toString() : this.snapshot.nativeAccountGeneration.toString() + ':' + (this.snapshot.nativeToken || 0).toString());
  }
  private activeChanged(): void {
    if (!this.active) return;
    this.prepareChatPosition();
    this.chatPosition.restore(this.restoreOffset);
    this.positionChat();
  }

  private prepareChatPosition(): void {
    if (this.snapshot.screen !== 'chat' || !this.snapshot.conversationId) return;
    if (this.presentedConversation !== this.snapshot.conversationId) {
      this.presentedConversation = this.snapshot.conversationId;
      // A retained sentRevision is history, not a newly completed send.
      this.sentRevision = this.snapshot.sentRevision || 0;
      this.chatPosition.begin(this.snapshot.conversationId, this.restoreOffset);
    }
  }

  private positionChat(): void {
    if (!this.visible || !this.active || this.snapshot.screen !== 'chat' || !this.snapshot.messages.length) return;
    const offset: number | undefined = this.chatPosition.layout(this.contentHeight, this.viewportHeight);
    if (offset !== undefined && Math.abs(this.scroller.currentOffset().yOffset - offset) > 0.5) {
      this.scroller.scrollTo({ xOffset: 0, yOffset: offset });
    }
  }

  private captureChatOffset(): void {
    if (this.visible && this.active && this.snapshot.screen === 'chat' && this.onOffset) this.onOffset(this.scroller.currentOffset().yOffset);
  }

  private messageImageRatio(message: InboxFlowMessage): number {
    return message.imageWidth && message.imageHeight ? message.imageWidth / message.imageHeight :
      this.imageRatios.get(message.image) || 1;
  }

  private messageImageWidth(message: InboxFlowMessage): number {
    return Math.min(220, 460 * this.messageImageRatio(message));
  }

  private snapshotChanged(): void {
    this.prepareChatPosition();
    if (this.previousScreen === 'settings' && this.snapshot.screen === 'chat' && this.settingsReturnOffset >= 0) {
      this.chatPosition.restore(this.settingsReturnOffset); this.contentHeight = 0; this.settingsReturnOffset = -1;
    }
    this.previousScreen = this.snapshot.screen;
    if (this.snapshot.screen === 'updatesMenu' && !this.snapshot.newsUndoing && this.snapshot.newsId &&
        this.snapshot.newsId !== this.presentedNewsId && !this.snapshot.newsHidden) {
      this.presentedNewsId = this.snapshot.newsId;
      this.showUpdatesMenu = true;
    }
    if (this.historyPending && !this.snapshot.loading && this.snapshot.error) this.historyPending = false;
    if (this.snapshot.newsHidden && this.snapshot.newsId && this.snapshot.newsId !== this.lastHiddenNewsId) {
      this.lastHiddenNewsId = this.snapshot.newsId;
      if (this.snapshot.screen === 'updatesMenu') this.showUpdatesMenu = false;
    }
    if (this.snapshot.screen === 'updatesMenu' && this.snapshot.unsubscribedPin) this.showUpdatesMenu = false;
    if (!this.snapshot.newsHidden && this.lastHiddenNewsId && this.snapshot.newsId === this.lastHiddenNewsId &&
        this.snapshot.newsId !== this.lastRestoredNewsId) {
      this.lastRestoredNewsId = this.snapshot.newsId;
      if (!this.snapshot.newsUndoing && this.onNewsRestored) this.onNewsRestored(this.snapshot.newsId);
    }
    if ((this.snapshot.blockRevision || 0) > this.lastBlockRevision) {
      this.lastBlockRevision = this.snapshot.blockRevision || 0;
      const target: InboxFlowUser | undefined = this.snapshot.users.filter((user: InboxFlowUser) => user.id === this.snapshot.blockedUserId)[0];
      this.showMessageMenu = false;
      this.blockTarget = undefined;
      if (this.onBlockChanged) this.onBlockChanged(!!this.snapshot.blocked, target ? target.name : this.uiText("pm_contacts_3303b569"));
    }
    if ((this.snapshot.sentRevision || 0) < this.sentRevision) this.sentRevision = this.snapshot.sentRevision || 0;
    if ((this.snapshot.sentRevision || 0) > this.sentRevision) {
      this.sentRevision = this.snapshot.sentRevision || 0;
      this.draft = '';
      this.chatPosition.latest();
    }
  }

  private act(action: string, value: string = ''): void {
    if (action === 'settings' && this.snapshot.screen === 'chat') { this.settingsReturnOffset = this.scroller.currentOffset().yOffset; this.captureChatOffset(); }
    if (this.onAction) this.onAction(action, value);
  }

  private blockTargetName(): string {
    return this.blockTarget ? this.blockTarget.name : this.uiText("pm_contacts_3303b569");
  }

  private messageTime(value: string): string {
    const date: Date = new Date(value);
    if (!Number.isFinite(date.getTime())) return '';
    const today: Date = new Date();
    const time: string = date.getHours().toString().padStart(2, '0') + ':' + date.getMinutes().toString().padStart(2, '0');
    if (date.toDateString() === today.toDateString()) return time;
    const yesterday: Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - 1);
    const datePart: string = this.uiLanguage === 'en' ?
      (date.getMonth() + 1).toString() + '/' + date.getDate().toString() + '/' + date.getFullYear().toString() :
      date.getFullYear().toString() + '年' + (date.getMonth() + 1).toString() + '月' + date.getDate().toString() + '日';
    return date.toDateString() === yesterday.toDateString() ? this.uiText('pm_activity_yesterday') + ' ' + time : datePart + ' ' + time;
  }

  @Builder
  private conversationTitle() {
    if (this.snapshot.screen === 'chat') {
    Row({ space: 10 }) {
      if (this.snapshot.users.some((user: InboxFlowUser) => !user.self)) {
        this.avatar(this.snapshot.users.filter((user: InboxFlowUser) => !user.self)[0], 32)
      }
      Text(PinmonyI18n.render(this.snapshot.title, this.uiLanguage) || this.uiText("pm_chat_4b3510b8"))
        .fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        .onClick(() => {
          const peers: InboxFlowUser[] = this.snapshot.users.filter((user: InboxFlowUser): boolean => !user.self);
          this.captureChatOffset();
          if (peers.length === 1 && peers[0].profileUrl && this.onUser) this.onUser(peers[0].profileUrl);
        })
    }.width('100%').padding({ left: 64, right: 72 }).alignItems(VerticalAlign.Center)
      .hitTestBehavior(HitTestMode.Transparent)
    }
  }

  @Builder
  private avatar(user: InboxFlowUser, size: number = 40) {
    PinmonyUserAvatar({ image: user.avatar, name: user.name, avatarSize: size })
      .onClick(() => { this.captureChatOffset(); if (user.profileUrl && this.onUser) this.onUser(user.profileUrl); })
  }

  @Builder
  private userRow(user: InboxFlowUser) {
    Row({ space: 12 }) {
      this.avatar(user)
      Text(PinmonyI18n.render(user.name, this.uiLanguage)).fontSize(17).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.primary_text')).layoutWeight(1).textAlign(TextAlign.Start)
      if (this.snapshot.screen === 'compose') {
        Checkbox().select(this.snapshot.selectedIds.includes(user.id)).width(24).height(24).margin(0).shape(CheckBoxShape.CIRCLE)
          .selectedColor($r('app.color.accent'))
          .onChange((selected: boolean) => {
            if (this.snapshot.selectedIds.includes(user.id) !== selected) this.act('select', user.id);
          })
          .hitTestBehavior(HitTestMode.None)
          .accessibilityText(this.uiText("pm_select_beb4816b") + user.name)
      } else if (!user.self) {
        Button(this.snapshot.blocked && this.snapshot.blockedUserId === user.id ? this.uiText("pm_unblock_e2c88959") : this.uiText("pm_block_5e2a9472"))
          .height(36).borderRadius(16).fontSize(14).fontWeight(FontWeight.Normal)
          .padding({ left: 14, right: 14 })
          .backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text'))
          .enabled(!this.snapshot.messageBusy && !this.snapshot.sending && !this.snapshot.writeUncertain)
          .onClick(() => { this.blockTarget = user; this.showMessageMenu = true; })
      }
    }.width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 })
      .enabled(!this.snapshot.loading && !this.snapshot.sending && !this.snapshot.messageBusy && !this.snapshot.writeUncertain)
      .onClick(() => { if (this.snapshot.screen === 'compose') this.act('select', user.id); })
  }

  @Builder
  private pinActions(message: InboxFlowMessage) {
    Column({ space: 8 }) {
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.lucide_share_2')).width(20).height(20).fillColor($r('app.color.primary_text'))
      }.width(40).height(40).backgroundColor($r('app.color.page_background'))
        .border({ width: 1, color: $r('app.color.surface_muted') }).accessibilityText(this.uiText("pm_share_pin_d85b11f9"))
        .onClick(() => { if (message.pinUrl && this.onPinAction) this.onPinAction('share', message.pinUrl); })
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.lucide_bookmark')).width(20).height(20)
      }.width(40).height(40).backgroundColor($r('app.color.page_background'))
        .border({ width: 1, color: $r('app.color.surface_muted') }).accessibilityText(this.uiText("pm_save_pin_d5491456"))
        .onClick(() => { if (message.pinUrl && this.onPinAction) this.onPinAction('save', message.pinUrl); })
    }
  }

  @Builder
  private reactionChoices() {
    Row({ space: 4 }) {
      ForEach(['❤️', '😂', '😍', '😮', '👍', '👎'], (reaction: string) => {
        Button({ type: ButtonType.Normal }) {
          Text(PinmonyI18n.render(reaction, this.uiLanguage)).fontSize(24).textAlign(TextAlign.Center).width('100%')
        }.width(40).height(44).padding(0).backgroundColor(Color.Transparent)
          .enabled(!this.snapshot.messageBusy && !this.snapshot.sending && !this.snapshot.writeUncertain)
          .onClick(() => { this.act('react', this.reactionMessageId + '|' + reaction); this.reactionMessageId = ''; })
      }, (reaction: string): string => JSON.stringify(reaction) + ':' + this.uiLanguage)
    }.padding(8)
  }

  @Builder
  private messageMenuContent() {
    Column({ space: 8 }) {
      if (!this.selectedMessage?.board && !this.selectedMessage?.profile) {
      Row() {
        ForEach(['❤️', '😂', '😍', '😮', '👍', '👎'], (reaction: string) => {
          Button({ type: ButtonType.Circle }) {
            Text(PinmonyI18n.render(reaction, this.uiLanguage)).fontSize(24).textAlign(TextAlign.Center).width('100%')
          }.padding(0).width(44).height(44)
            .backgroundColor($r('app.color.surface_muted'))
            .enabled(!this.snapshot.messageBusy && !this.snapshot.sending && !this.snapshot.writeUncertain)
            .onClick(() => {
              if (this.selectedMessage) this.act('react', this.selectedMessage.id + '|' + reaction);
              this.showMessageMenu = false;
            })
        }, (reaction: string): string => JSON.stringify(reaction) + ':' + this.uiLanguage)
      }.width('100%').justifyContent(FlexAlign.SpaceBetween)
      Divider().margin({ top: 8, bottom: 8 })
      }
      if (this.selectedMessage?.text && !this.selectedMessage.deleted && this.onCopyText) {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 10 }) {
            SymbolGlyph($r('sys.symbol.rectangle_on_rectangle')).fontSize(20)
              .fontColor([$r('app.color.primary_text')])
            Text(this.uiText("pm_copy_63d90d97")).fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text'))
          }.width('100%').justifyContent(FlexAlign.Start)
        }.width('100%').height(48).padding({ left: 8, right: 8 })
          .backgroundColor(Color.Transparent).accessibilityText(this.uiText("pm_copy_message_text_280f1f93"))
          .onClick(async () => {
            const text: string = this.selectedMessage?.text || '';
            if (text && this.onCopyText && await this.onCopyText(text)) this.showMessageMenu = false;
          })
      }
      if (this.selectedMessage?.pinUrl) {
        Button(this.uiText("pm_save_60a53514")).width('100%').backgroundColor(Color.Transparent).fontColor($r('app.color.primary_text'))
          .onClick(() => { if (this.selectedMessage && this.onPinAction) this.onPinAction('save', this.selectedMessage.pinUrl); this.showMessageMenu = false; })
        Button(this.uiText("pm_share_7e564575")).width('100%').backgroundColor(Color.Transparent).fontColor($r('app.color.primary_text'))
          .onClick(() => { if (this.selectedMessage && this.onPinAction) this.onPinAction('share', this.selectedMessage.pinUrl); this.showMessageMenu = false; })
      }
      if (this.selectedMessage?.own) {
        Button(this.uiText("pm_delete_2f9daa82")).width('100%').backgroundColor(Color.Transparent).fontColor($r('app.color.accent'))
          .enabled(!this.snapshot.messageBusy && !this.snapshot.sending && !this.snapshot.writeUncertain)
          .onClick(() => {
            const id: string = this.selectedMessage?.id || '';
            const intent: string = this.messageConfirmationKey();
            this.getUIContext().showAlertDialog({ title: this.uiText("pm_delete_message_053d6b4d"), message: this.uiText("pm_delete_this_message_94c4bcb6"),
              primaryButton: { value: this.uiText("pm_cancel_2cd0f3be"), action: (): void => {} },
              secondaryButton: { value: this.uiText("pm_delete_2f9daa82"), action: (): void => { if(this.messageConfirmationKey() === intent)this.act('deleteMessage', id); this.showMessageMenu = false; } } });
          })
      }
    }.padding({ left: 16, right: 16, bottom: 24 }).width('100%')
  }

  @Builder
  private blockSheetContent() {
    Column({ space: 16 }) {
      Text((this.snapshot.blocked ? this.uiText("pm_unblock_e2c88959") : this.uiText("pm_block_5e2a9472")) + this.blockTargetName() + '？')
        .fontSize(24).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
        .alignSelf(ItemAlign.Start)
      Text(this.snapshot.blocked ?
        this.uiText("pm_you_can_view_follow_message_or_save_their_pins_after_you_unblock_74bd9651") :
        this.uiText("pm_you_will_not_be_able_to_view_follow_contact_them_or_save_their_p_8111b778"))
        .fontSize(16).fontColor($r('app.color.primary_text')).lineHeight(26)
        .textAlign(TextAlign.Start)
      Row({ space: 12 }) {
        Button(this.uiText("pm_not_now_6b758902")).backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text'))
          .onClick(() => { this.showMessageMenu = false; this.blockTarget = undefined; })
        Button(this.snapshot.blocked ? this.uiText("pm_unblock_e2c88959") : this.uiText("pm_block_5e2a9472"))
          .backgroundColor(this.snapshot.blocked ? Color.Black : $r('app.color.accent'))
          .fontColor(Color.White).enabled(!this.snapshot.messageBusy && !!this.blockTarget)
          .onClick(() => {
            if (this.blockTarget) this.act(this.snapshot.blocked ? 'unblockUser' : 'blockUser', this.blockTarget.id);
          })
      }.width('100%').justifyContent(FlexAlign.End)
    }.width('100%').padding({ left: 28, right: 28, top: 16, bottom: 28 })
  }

  @Builder
  private activeSheetContent() {
    if (this.snapshot.screen === 'settings') this.blockSheetContent();
    else this.messageMenuContent();
  }

  private messageLayoutKey(message: InboxFlowMessage): string {
    return this.snapshot.conversationId + ':' + message.id;
  }

  private messageTextController(message: InboxFlowMessage): TextController {
    const key: string = this.messageLayoutKey(message);
    let controller: TextController | undefined = this.textControllers.get(key);
    if (!controller) {
      controller = new TextController();
      this.textControllers.set(key, controller);
    }
    return controller;
  }

  private openSharedProfile(messageId: string): void {
    const message: InboxFlowMessage | undefined = this.snapshot.messages.find((item: InboxFlowMessage): boolean => item.id === messageId);
    if (!this.active || message?.deleted || !message?.profile?.profileUrl || !this.onUser) return;
    this.captureChatOffset();
    this.onUser(message.profile.profileUrl);
  }

  private messageAvatarSize(message: InboxFlowMessage): number {
    return 44;
  }

  private textAvatarOffset(message: InboxFlowMessage): number {
    if (message.deleted || message.image || message.board || !message.text || message.text === '❤️') return -1;
    const key: string = this.messageLayoutKey(message);
    const offset: number = this.textAvatarOffsets.get(key) ?? 0;
    return offset < 0 ? -1 : offset + (message.sender?.name ? (this.senderLabelHeights.get(key) || 16) + 8 : 0);
  }

  @Builder
  private messageRow(message: InboxFlowMessage) {
    Column({ space: 12 }) {
      if (message.createdAt) {
        Text(this.messageTime(message.createdAt)).fontSize(12)
          .fontColor($r('app.color.secondary_text')).alignSelf(ItemAlign.Center)
      }
      Row({ space: 8 }) {
        if (message.own && !message.deleted && message.image && message.pinUrl) { this.pinActions(message) }
        if (!message.own && message.sender) {
          Column() { this.avatar(message.sender, this.messageAvatarSize(message)) }
            .alignSelf(this.textAvatarOffset(message) >= 0 ? ItemAlign.Start : ItemAlign.End)
            .margin({ top: Math.max(0, this.textAvatarOffset(message)) })
        }
        Column({ space: 8 }) {
          if (!message.own && message.sender?.name && !message.deleted) {
            Text(message.sender.name).fontSize(12).fontColor($r('app.color.secondary_text'))
              .onClick(() => { this.captureChatOffset(); if (message.sender?.profileUrl && this.onUser) this.onUser(message.sender.profileUrl); })
              .onAreaChange((_old: Area, area: Area) => {
                const key: string = this.messageLayoutKey(message);
                const height: number = Number(area.height);
                if (this.senderLabelHeights.get(key) !== height) {
                  const heights: Map<string, number> = new Map(this.senderLabelHeights);
                  heights.set(key, height); this.senderLabelHeights = heights;
                }
              })
          }
          if (message.profile && !message.deleted) {
            Button({ type: ButtonType.Normal }) {
            Column({ space: 8 }) {
              if (message.profileImages?.length) {
                Row() {
                  ForEach(message.profileImages, (url: string) => { Image(url).width(message.profileImages!.length === 1 ? '100%' : '50%').height(160).objectFit(ImageFit.Cover) }, (url: string) => url)
                }.width(240).clip(true).borderRadius(18)
              }
              Stack({ alignContent: Alignment.Center }) {
                PinmonyUserAvatar({ image: message.profile.avatar, name: message.profile.name, avatarSize: 60 })
              }
                .width(64).height(64).margin({ top: -32 }).borderRadius(32)
                .backgroundColor($r('app.color.page_background')).clip(true).zIndex(1)
              Text(message.profile.name).fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
            }.width('100%').alignItems(HorizontalAlign.Center).hitTestBehavior(HitTestMode.None)
            }.width(240).padding(0).borderRadius(18).clip(true).backgroundColor(Color.Transparent)
              .border({ width: 1, color: $r('app.color.surface_muted'), radius: 18 })
              .accessibilityText(this.uiText("pm_view_9ae8f7e3") + message.profile.name + this.uiText("pm_s_profile_66416c2f"))
              .onClick(() => this.openSharedProfile(message.id))
          } else if (message.board && !message.deleted) {
            PinmonyInboxBoardCard({ board: message.board,
              onOpen: () => { this.captureChatOffset(); if (this.onBoard) this.onBoard(message.id); } })
          } else if (message.image && !message.deleted) {
            Image(message.image).width(this.messageImageWidth(message))
              .height(this.messageImageWidth(message) / this.messageImageRatio(message))
              .constraintSize({ maxHeight: 460 }).borderRadius(18)
              .objectFit(ImageFit.Contain)
              .onComplete((event) => {
                if (event && event.width > 0 && event.height > 0) {
                  const ratio: number = event.width / event.height;
                  if (this.imageRatios.get(message.image) !== ratio) {
                    const ratios: Map<string, number> = new Map<string, number>(this.imageRatios);
                    ratios.set(message.image, ratio); this.imageRatios = ratios;
                  }
                }
              })
              .onClick(() => { this.captureChatOffset(); if (message.pinUrl && this.onPin) this.onPin(message.pinUrl); })
          }
          if (message.deleted) {
            Text(message.own ? this.uiText("pm_you_deleted_a_message_4ed92139") : this.snapshot.title + this.uiText("pm_deleted_a_message_4d82968b"))
              .fontColor($r('app.color.secondary_text')).fontSize(14).padding(12).borderRadius(24)
              .border({ width: 1, color: $r('app.color.surface_muted'), style: BorderStyle.Dashed })
          } else if (message.text === '❤️') {
            Image($r('app.media.lucide_heart_filled')).width(48).height(48).fillColor($r('app.color.accent'))
          } else if (message.text) {
            Text(message.text, { controller: this.messageTextController(message) })
              .fontSize(16).fontColor($r('app.color.primary_text'))
              .padding(12).borderRadius(16).backgroundColor($r('app.color.surface_muted'))
              .onAreaChange((_old: Area, area: Area) => {
                if (message.own || message.image || message.board) return;
                const lines: number = this.messageTextController(message).getLayoutManager().getLineCount();
                if (lines <= 0) return;
                const key: string = this.messageLayoutKey(message);
                const offset: number = lines <= 2 ? Math.max(0, (Number(area.height) - this.messageAvatarSize(message)) / 2) : -1;
                if (this.textAvatarOffsets.get(key) !== offset) {
                  const offsets: Map<string, number> = new Map(this.textAvatarOffsets);
                  offsets.set(key, offset); this.textAvatarOffsets = offsets;
                }
              })
          } else if (message.pinUrl && !message.image) {
            Text(this.uiText("pm_pin_image_unavailable_3240b81a")).fontColor($r('app.color.secondary_text'))
          }
          if (!message.deleted && !message.board && !message.profile) {
            Button({ type: ButtonType.Normal }) {
              Row() {
                if (message.reactions?.length) {
                  Text(message.reactions.join(' ')).fontSize(18).fontColor($r('app.color.primary_text'))
                } else {
                  SymbolGlyph($r('sys.symbol.face_smiling')).fontSize(20).fontColor([$r('app.color.primary_text')])
                  Text('+').fontSize(12).fontColor($r('app.color.primary_text'))
                }
              }
            }.constraintSize({ minWidth: 40 }).height(30).padding({ left: 6, right: 6 }).borderRadius(18)
              .backgroundColor($r('app.color.surface_muted'))
              .alignSelf(ItemAlign.End).margin({ top: -16, right: 4 }).zIndex(1)
              .accessibilityText(this.uiText("pm_choose_a_message_reaction_caf4b514"))
              .onClick(() => { this.reactionMessageId = this.reactionMessageId === message.id ? '' : message.id; })
              .bindPopup(this.reactionMessageId === message.id, {
                builder: this.reactionChoices, placement: Placement.Top, showInSubWindow: false,
                onStateChange: (event: ReactionPopupState) => { if (!event.isVisible && this.reactionMessageId === message.id) this.reactionMessageId = ''; }
              })
          }
        }.constraintSize({ maxWidth: 260 }).alignItems(HorizontalAlign.Start)
          .parallelGesture(LongPressGesture().onAction(() => { if (!message.deleted) { this.selectedMessage = message; this.showMessageMenu = true; } }))
        if (!message.own && !message.deleted && message.image && message.pinUrl) { this.pinActions(message) }
      }.width('100%').justifyContent(message.own ? FlexAlign.End : FlexAlign.Start)
        .padding({ left: 20, right: 20 })
    }.width('100%').padding({ top: 12, bottom: 12 })
  }

  @Builder
  private updatesMenuContent() {
    Column({ space: 4 }) {
      if (this.snapshot.canUnsubscribePin) {
        Button({ type: ButtonType.Normal }) {
          Text(this.uiText("pm_turn_off_updates_for_this_pin_01676b9f")).fontSize(18).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary_text')).width('100%').textAlign(TextAlign.Start)
        }.width('100%').constraintSize({ minHeight: 48 }).padding({ left: 8, right: 8, top: 12, bottom: 12 })
          .backgroundColor(Color.Transparent).enabled(!this.snapshot.messageBusy && !this.snapshot.unsubscribedPin)
          .onClick(() => this.act('unsubscribePin'))
      }
      Button({ type: ButtonType.Normal }) {
        Text(this.uiText("pm_delete_update_b051285c")).fontSize(18).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary_text')).width('100%').textAlign(TextAlign.Start)
      }.width('100%').constraintSize({ minHeight: 48 }).padding({ left: 8, right: 8, top: 12, bottom: 12 })
        .backgroundColor(Color.Transparent).enabled(!this.snapshot.messageBusy && !this.snapshot.sending && !this.snapshot.writeUncertain)
        .onClick(() => this.act('hideNews'))
      Button({ type: ButtonType.Normal }) {
        Text(this.uiText("pm_view_notification_settings_c3a6f9ff")).fontSize(18).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary_text')).width('100%').textAlign(TextAlign.Start)
      }.width('100%').constraintSize({ minHeight: 48 }).padding({ left: 8, right: 8, top: 12, bottom: 12 })
        .backgroundColor(Color.Transparent).onClick(() => { if (this.onNotifications) this.onNotifications(); })
      if (this.snapshot.unsubscribedPin) {
        Text(this.uiText("pm_you_will_no_longer_receive_notifications_about_this_pin_75459ce5")).fontSize(14).fontColor($r('app.color.secondary_text'))
      }
      if (this.snapshot.error) { PinmonyActionNotice({ active: this.active, message: PinmonyI18n.render(this.snapshot.error, this.uiLanguage) }) }
    }.width('100%').padding({ left: 20, right: 20, top: 8, bottom: 24 })
  }

  build() {
    if (this.snapshot.screen === 'updatesMenu' && this.snapshot.newsUndoing) {
      Column().width(1).height(1).hitTestBehavior(HitTestMode.Transparent)
      if (this.snapshot.error) { PinmonyActionNotice({ active: this.active, message: PinmonyI18n.render(this.snapshot.error, this.uiLanguage) }) }
    } else if (this.snapshot.screen === 'updatesMenu') {
      Column().width(1).height(1)
        .hitTestBehavior(HitTestMode.Transparent)
        .onAppear(() => { this.presentedNewsId = this.snapshot.newsId || ''; this.showUpdatesMenu = !this.snapshot.newsHidden; })
        .bindSheet($$this.showUpdatesMenu, this.updatesMenuContent(), {
          radius: { topLeft: 32, topRight: 32, bottomLeft: 32, bottomRight: 32 },
          onWillAppear: (): void => { PinmonyRuntimeLog.info('SheetTrace: event=will-appear source=PinmonyInboxFlowPage.showUpdatesMenu radius=four-corners-32vp'); },
          height: SheetSize.FIT_CONTENT,
          dragBar: true,
          showClose: true,
          title: { title: this.uiText("pm_update_options_c3643cd9") },
          backgroundColor: $r('app.color.page_background'),
          maskColor: '#66000000',
          onDisappear: () => {
            if (this.snapshot.screen !== 'updatesMenu' || this.snapshot.newsUndoing) return;
            if (this.snapshot.newsHidden && this.snapshot.newsId && this.onNewsHidden) this.onNewsHidden(this.snapshot.newsId);
            if (this.snapshot.unsubscribedPin && this.onPinUnsubscribed) this.onPinUnsubscribed();
            this.act('back');
          },
          onWillDismiss: (action: DismissSheetAction) => {
            action.dismiss();
            this.showUpdatesMenu = false;
          }
        })
    } else {
    HdsNavigation(this.flowPathStack) {}.width('100%').height('100%').hideTitleBar(true)
      .backgroundColor($r('app.color.page_background'))
      .navDestination(this.flowDestination)
    }
  }
  @Builder
  private flowDestination() {
    HdsNavDestination() {
    Stack({ alignContent: Alignment.Center }) {
    Column() {
      if (this.snapshot.screen === 'compose') {
        TextInput({ text: this.query, placeholder: this.uiText("pm_search_by_name_or_email_0c503b47") }).margin({ left: 16, right: 16, bottom: 8 })
          .enabled(!this.snapshot.loading && !this.snapshot.sending && !this.snapshot.messageBusy && !this.snapshot.writeUncertain)
          .onChange((value: string) => {
            this.query = value;
            const token: number = ++this.queryToken;
            setTimeout(() => { if (token === this.queryToken && this.snapshot.screen === 'compose') this.act('search', value); }, 300);
          })
          .onSubmit(() => { this.queryToken++; this.act('search', this.query); })
      }
      if (this.snapshot.error) {
        Column({ space: 8 }) {
          PinmonyActionNotice({ active: this.active, message: PinmonyI18n.render(this.snapshot.error, this.uiLanguage),
            actionText: this.snapshot.writeUncertain ? this.uiText("pm_reload_df7392cc") : this.uiText("pm_retry_b8784c8d"),
            actionEnabled: !(this.snapshot.screen === 'settings' && this.snapshot.writeUncertain),
            onAction: () => this.act('retry') })
        }.padding(16)
      }
      if (this.snapshot.loading && this.snapshot.screen !== 'chat') { LoadingProgress().width(28).height(28) }

      Scroll(this.scroller) {
        Column() {
          if (this.snapshot.screen === 'compose' || this.snapshot.screen === 'settings') {
            ForEach(this.snapshot.users, (user: InboxFlowUser) => { this.userRow(user) }, (user: InboxFlowUser) => user.id)
          } else {
            if (this.snapshot.users.length > 0) {
              Column({ space: 16 }) {
                Row({ space: 4 }) {
                  ForEach(this.snapshot.users.slice(0, 2), (user: InboxFlowUser) => { this.avatar(user, 72) },
                    (user: InboxFlowUser) => user.id)
                }
                Text(PinmonyI18n.render(this.snapshot.title, this.uiLanguage)).fontSize(18).fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.primary_text'))
                Text(this.uiText("pm_good_things_could_be_on_their_way_3f8e968c")).fontSize(14).fontColor($r('app.color.secondary_text'))
              }.width('100%').padding({ top: 40, bottom: 40 }).alignItems(HorizontalAlign.Center)
            }
            ForEach(this.snapshot.messages, (message: InboxFlowMessage) => { this.messageRow(message) },
              (message: InboxFlowMessage) => message.id)
          }
        }.width('100%').alignItems(HorizontalAlign.Start)
          .padding({ bottom: this.snapshot.screen === 'settings' ? 120 : 20 })
          .onAreaChange((_old: Area, area: Area) => {
            this.contentHeight = Number(area.height);
            if (this.historyPending && !this.snapshot.loading && this.contentHeight > this.historyHeight) {
              this.historyPending = false;
              this.scroller.scrollTo({ xOffset: 0, yOffset: this.historyOffset + this.contentHeight - this.historyHeight });
            }
            this.positionChat();
          })
      }.width('100%').layoutWeight(1).align(Alignment.TopStart)
        .scrollBar(BarState.Off)
        .onScrollStop(() => {
          if (this.chatPosition.canLoadHistory()) this.captureChatOffset();
          if (!this.active || this.snapshot.screen !== 'chat' || !this.chatPosition.canLoadHistory() || !this.snapshot.hasMore || this.snapshot.loading || this.historyPending || this.snapshot.error) return;
          if (this.scroller.currentOffset().yOffset > 80) return;
          this.historyHeight = this.contentHeight; this.historyOffset = this.scroller.currentOffset().yOffset;
          this.historyPending = true; this.act('more');
        })
        .onAreaChange((_old: Area, area: Area) => { this.viewportHeight = Number(area.height); this.positionChat(); })
        .onDidScroll((_x: number, _y: number, state: ScrollState) => {
          const offset: number = this.scroller.currentOffset().yOffset;
          if (this.visible && this.active && this.snapshot.screen === 'chat') this.chatPosition.record(offset, state === ScrollState.Scroll);
        })
      if (this.snapshot.screen === 'chat') {
        Row({ space: 8 }) {
          TextInput({ text: this.draft, placeholder: this.uiText("pm_write_a_message_2156709a") }).layoutWeight(1).maxLength(2000)
            .enabled(!this.snapshot.loading && !this.snapshot.sending && !this.snapshot.messageBusy && !this.snapshot.sendError && !this.snapshot.writeUncertain)
            .onChange((value: string) => { this.draft = value; })
            .onSubmit(() => { if (this.draft.trim()) this.act('send', this.draft); })
          if (this.draft.trim()) {
            Button(this.uiText("pm_send_edecf0ae")).enabled(!this.snapshot.loading && !this.snapshot.sending && !this.snapshot.messageBusy && !this.snapshot.sendError && !this.snapshot.writeUncertain)
              .onClick(() => this.act('send', this.draft))
          } else {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.heart_fill')).fontSize(20)
              .fontColor([$r('app.color.accent')])
          }.width(44).height(44).backgroundColor($r('app.color.page_background'))
            .border({ width: 1, color: $r('app.color.surface_muted') })
            .accessibilityText(this.uiText("pm_send_a_heart_dccfdd46"))
            .enabled(!this.snapshot.loading && !this.snapshot.sending && !this.snapshot.messageBusy && !this.snapshot.sendError && !this.snapshot.writeUncertain)
            .onClick(() => this.act('send', '❤️'))
          }
        }.padding({ left: 16, right: 16, top: 8, bottom: 24 })
        if (this.snapshot.sendError) {
          PinmonyActionNotice({ active: this.active, message: PinmonyI18n.render(this.snapshot.sendError, this.uiLanguage), actionText: this.uiText("pm_reload_conversation_585a78c6"), onAction: () => this.act('retry') })
        }
      }
    }.width('100%').height('100%').backgroundColor($r('app.color.page_background'))
      .bindSheet($$this.showMessageMenu, this.activeSheetContent(), {
        radius: { topLeft: 32, topRight: 32, bottomLeft: 32, bottomRight: 32 },
        onWillAppear: (): void => { PinmonyRuntimeLog.info('SheetTrace: event=will-appear source=PinmonyInboxFlowPage.showMessageMenu radius=four-corners-32vp'); },
        height: SheetSize.FIT_CONTENT, showClose: true,
        title: { title: this.snapshot.screen === 'settings' ? (this.snapshot.blocked ? this.uiText("pm_unblock_contact_4b2a7e25") : this.uiText("pm_block_contact_a32510e0")) : '' }, dragBar: true,
        backgroundColor: $r('app.color.page_background'),
        onWillDismiss: (action: DismissSheetAction) => { action.dismiss(); this.showMessageMenu = false; this.selectedMessage = undefined; this.blockTarget = undefined; }
      })
    if (this.snapshot.loading && this.snapshot.screen === 'chat') {
      LoadingProgress().width(40).height(40).color($r('app.color.primary_text')).hitTestBehavior(HitTestMode.None)
    }
    }.width('100%').height('100%')
    }.width('100%').height('100%')
      .titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: true,
        style: { blurStrategy: this.immersiveLightEnabled ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: this.immersiveLightEnabled,
          scrollEffectOpts: { enableScrollEffect: this.immersiveLightEnabled, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
          systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
          scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 }, contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },  backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 } }
        },
        content: { title: { mainTitle: this.snapshot.screen === 'chat' ? '' :
          this.snapshot.screen === 'compose' ? this.uiText("pm_new_message_3fc957bf") : PinmonyI18n.render(this.snapshot.title, this.uiLanguage) || this.uiText("pm_message_settings_57326743") },
          stackBuilder: this.conversationTitleBuilder,
          backIcon: { isEnabled: true, action: () => this.act('back') },
          menu: { value: this.snapshot.screen === 'chat' ? [{ content: { icon: $r('app.media.lucide_ellipsis'), label: this.uiText("pm_message_settings_57326743"), action: () => this.act('settings') } }] :
            this.snapshot.screen === 'compose' ? [{ content: { type: TextStyleMode.NORMAL, label: this.uiText("pm_next_acfc4e74"), isEnabled: !this.snapshot.loading && !this.snapshot.sending && !this.snapshot.messageBusy && !this.snapshot.writeUncertain && this.snapshot.selectedIds.length > 0, action: () => this.act('next') } }] : [] } } })
      .titleMode(HdsNavDestinationTitleMode.MINI).hideTitleBar(false).hideBackButton(false)
      .backgroundColor($r('app.color.page_background'))
      .bindToScrollable([this.scroller])
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .onBackPressed(() => { this.act('back'); return true; })
  }
}
