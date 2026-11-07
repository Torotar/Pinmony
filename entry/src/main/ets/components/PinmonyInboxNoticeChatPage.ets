import { PinmonyInboxStore, PinmonyInboxFlowPage } from 'feature_inbox';

@Component
export struct PinmonyInboxNoticeChatPage {
  @ObjectLink store: PinmonyInboxStore;
  @Prop active: boolean = true;
  onAction: (action: string, value: string) => void = (): void => {};
  onBack: () => boolean = (): boolean => true;
  onCopyText?: (text: string) => Promise<boolean>;
  build() {
    Stack() {
      if(this.store.inboxFlow) {
        PinmonyInboxFlowPage({snapshot:this.store.inboxFlow,active:this.active,
          restoreOffset:this.store.chatReturnConversation === this.store.inboxFlow.conversationId ? this.store.chatScrollOffset : -1,
          onOffset:(offset: number): void => { this.store.chatScrollOffset = offset; this.store.chatReturnConversation = this.store.inboxFlow?.conversationId || ''; },
          onAction:(action: string, value: string): void => this.onAction(action,value),
          onCoveredBack:(): boolean => this.onBack(), onCopyText:this.onCopyText})
          .width('100%').height('100%')
      }
    }.width('100%').height('100%').backgroundColor($r('app.color.page_background'))
      .hitTestBehavior(this.active ? HitTestMode.Default : HitTestMode.None)
      .accessibilityLevel(this.active ? 'auto' : 'no-hide-descendants')
  }
}
