import { PinmonyPinStore } from 'feature_pin';
import { PinmonyInboxStore, PinmonyInboxPage, PinmonyBoardInvitation, PinmonyInboxSnapshot } from 'feature_inbox';
import { PinmonyAuthStatus } from 'common_session';

export interface PinmonyInboxRootView {
  inboxStore: PinmonyInboxStore;
  pinStore: PinmonyPinStore;
  activeSheetKind: string;
  loadFailed: boolean;
  openUserProfile: (url: string) => void;
  activeTab: number;
  authStatus: PinmonyAuthStatus;
  updateInboxScrollAvailability: (scrollable: boolean) => void;
  handleRootContentScroll: (offset: number, state: ScrollState) => void;
  inboxPlaceholder: () => PinmonyInboxSnapshot;
  currentInboxUrl: () => string;
  previewBoardInvitation: (item: PinmonyBoardInvitation) => void;
  selectInboxSection: (section: string) => Promise<void>;
  loadMoreInbox: () => Promise<void>;
  retryInboxContacts: () => Promise<void>;
  performInboxAction: (id: string) => Promise<void>;
  selectNativeRootTab: (index: number) => void;
  retryInbox: () => Promise<void>;
  rootPullKind: string;
  pullRefreshRoot: (kind: string) => Promise<void>;
}

@Builder
export function PinmonyBuildInboxRootContent(view: PinmonyInboxRootView) {
          if ((view.inboxStore.inbox || view.inboxStore.inboxLoading || view.inboxStore.inboxError) && !view.inboxStore.inboxWebFlow &&
              !view.pinStore.detail && !view.activeSheetKind && !view.loadFailed) {
            PinmonyInboxPage({ onUser: (url: string) => view.openUserProfile(url),
              interactionReady: view.activeTab === 2 && view.authStatus === 'authenticated',
              onScrollAvailability: (scrollable: boolean) => view.updateInboxScrollAvailability(scrollable),
              onContentScroll: (offset: number, state: ScrollState) => view.handleRootContentScroll(offset, state),
              snapshot: view.inboxStore.inbox || view.inboxPlaceholder(),
              actionsReady: view.activeTab === 2 && view.inboxStore.inboxActionsReady &&
                view.inboxStore.inbox?.pageUrl === view.currentInboxUrl(),
              sectionReady: view.activeTab === 2 && view.inboxStore.inboxSectionReady &&
                view.inboxStore.inbox?.pageUrl === view.currentInboxUrl(),
              retainedContent: view.inboxStore.inboxRetainedContent,
              invitations: view.inboxStore.boardInvitations, onInvitationPreview: (item: PinmonyBoardInvitation) => view.previewBoardInvitation(item),
              onInvitationAll: () => { view.inboxStore.invitationAllVisible = true; },
              initialScrollOffset: view.inboxStore.inboxScrollOffset,
              onScrollPosition: (url: string, section: string, offset: number) => {
                if (!view.inboxStore.inbox || view.inboxStore.inbox.pageUrl !== url || view.inboxStore.inbox.section !== section ||
                    view.currentInboxUrl() !== url) return;
                view.inboxStore.inboxScrollOffset = offset;
                if (view.inboxStore.inboxActionsReady && !view.inboxStore.inboxLoading && !view.inboxStore.inboxError) view.inboxStore.inboxCache.put(view.inboxStore.inbox, offset);
              },
              loading: view.inboxStore.inboxLoading,
              error: view.inboxStore.inboxError,
              onSection: (section: string) => view.selectInboxSection(section),
              onLoadMore: () => view.loadMoreInbox(),
              onContactsRetry: () => view.retryInboxContacts(),
              onAction: (id: string) => view.performInboxAction(id),
              onHome: () => view.selectNativeRootTab(0),
              onRetry: () => view.retryInbox(),
              refreshing: view.rootPullKind === 'inbox',
              onRefresh: () => view.pullRefreshRoot('inbox')
            })
            .width('100%')
            .height('100%')
            .visibility(view.activeTab === 2 ? Visibility.Visible : Visibility.Hidden)
            .hitTestBehavior(view.activeTab === 2 ? HitTestMode.Default : HitTestMode.None)
          }


}
