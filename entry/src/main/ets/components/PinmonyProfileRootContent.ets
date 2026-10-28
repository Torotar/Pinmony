import { PinmonyI18n } from 'common_foundation';
import { PinmonyPinStore } from 'feature_pin';
import { PinmonyProfileStore, PinmonyProfilePage } from 'feature_profile';
import { PinmonyAuthStatus } from 'common_session';

export interface PinmonyProfileRootView {
  profileStore: PinmonyProfileStore;
  pinStore: PinmonyPinStore;
  loadFailed: boolean;
  authStatus: PinmonyAuthStatus;
  activeTab: number;
  nativeRootOnly: boolean;
  rootContentInteracted: boolean;
  handleRootContentScroll: (offset: number, state: ScrollState) => void;
  openUserProfile: (url: string) => void;
  openWebsite: (url: string) => void;
  backFromUserProfile: () => void;
  currentProfileUrl: () => string;
  changeProfileTab: (section: string) => Promise<void>;
  openProfilePanel: (mode: string, section?: string) => Promise<void>;
  followProfileUser: (id?: string) => Promise<void>;
  performProfileAction: (id: string) => Promise<boolean>;
  openProfileBoard: (id: string) => Promise<void>;
  traceAction: (name: string, detail?: string) => void;
  openProfilePinMenu: (id: string) => Promise<void>;
  openProfileSearch: () => void;
  openProfilePublish: () => void;
  sortProfileBoards: (value: string) => void;
  loadBoardVisibility: (value?: boolean) => void;
  openBoardRecovery: () => void;
  openProfileShare: () => Promise<void>;
  openProfileMenu: () => void;
  loadMoreProfile: () => void;
  refreshProfile: (pull?: boolean) => void;
  organizeProfile: (action: string, value?: string, secret?: boolean) => Promise<void>;
  onTouch: (event: TouchEvent) => void;
  onContentInteracted: () => void;
  onSettings: () => void;
}

@Builder
export function PinmonyBuildProfileRootContent(view: PinmonyProfileRootView) {
          if ((view.profileStore.profile || view.profileStore.profileLoading || view.profileStore.profileError) &&
              !view.profileStore.profileWebFlow && !view.pinStore.detail && !view.loadFailed) {
            Stack() {
              if (view.profileStore.profile && !(view.profileStore.profile.nativeVersion !== undefined && view.profileStore.profile.business === undefined) && !view.profileStore.profileWebFlow && !view.pinStore.detail && !view.loadFailed) {
                PinmonyProfilePage({
                  interactionReady: view.authStatus === 'authenticated' &&
                    (view.activeTab === 3 || view.profileStore.origins.length > 0),
                  automaticLoadingEnabled: (view.profileStore.profileNativeReadsReady || !view.nativeRootOnly || view.rootContentInteracted) &&
                    (view.activeTab === 3 || view.profileStore.origins.length > 0),
              onContentScroll: (offset: number, state: ScrollState) => view.handleRootContentScroll(offset, state),
                  profile: view.profileStore.profile,
                  onUser: (url: string) => view.openUserProfile(url),
                  onWebsite: (url: string) => view.openWebsite(url),
                  onBack: view.profileStore.origins.length > 0 ? () => view.backFromUserProfile() : undefined,
                  readsReady: view.profileStore.profileNativeReadsReady,
                  actionsReady: view.profileStore.profileActionsReady &&
                    view.profileStore.profile?.profileUrl === view.currentProfileUrl(),
                  syncError: view.profileStore.profileError,
                  initialScrollOffset: view.profileStore.profileScrollOffset,
                  onScrollPosition: (url: string, section: string, offset: number) => {
                    if (!view.profileStore.profile || view.profileStore.profile.profileUrl !== url || view.profileStore.profile.section !== section ||
                        view.currentProfileUrl() !== url) return;
                    view.profileStore.profileScrollOffset = offset;
                    if (view.profileStore.profileNativeReadsReady || view.profileStore.profileActionsReady) view.profileStore.profileCache.put(view.profileStore.profile, offset);
                  },
                  loading: view.profileStore.profileSwitching,
                  onTab: (section: string) => view.changeProfileTab(section),
                  onAction: (id: string, kind: string) => { if (kind === 'edit' || kind === 'followers' || kind === 'following') view.openProfilePanel(kind); else if (kind === 'follow') view.followProfileUser(); else view.performProfileAction(id); },
                  onBoard: (id: string) => view.openProfileBoard(id),
                  onPin: (id: string) => { view.traceAction('profile.pin.open'); view.performProfileAction(id); },
                  onPinMore: (id: string) => view.openProfilePinMenu(id),
                  onSearch: () => view.openProfileSearch(),
                  onPublish: () => view.openProfilePublish(),
                  onBoardSort: (value: string) => view.sortProfileBoards(value),
                  onBoardVisibility: (value?: boolean) => view.loadBoardVisibility(value),
                  onBoardRecovery: () => view.openBoardRecovery(),
                  onSettings: () => view.onSettings(),
                  followingBusy: view.profileStore.followingBusy, onShare: () => view.openProfileShare(),
                  onMenu: () => view.openProfileMenu(),
                  onLoadMore: () => { view.onContentInteracted(); view.loadMoreProfile(); },
                  onRetry: () => view.refreshProfile(),
                  onRefresh: () => view.refreshProfile(true),
                  refreshing: view.profileStore.profilePullRefreshing,
                  onOrganize: (action: string, value: string, secret: boolean) => view.organizeProfile(action, value, secret)
                })
                .width('100%')
                .height('100%')
              } else if ((view.profileStore.profileLoading || view.profileStore.profileError || view.profileStore.profile?.nativeVersion !== undefined && view.profileStore.profile.business === undefined) && !view.profileStore.profileWebFlow &&
                         !view.pinStore.detail && !view.loadFailed) {
                PinmonyBuildProfileStatus(view)
              }
            }
            .width('100%')
            .height('100%')
            .visibility(view.profileStore.origins.length > 0 || view.activeTab === 3 ? Visibility.Visible : Visibility.Hidden)
            .hitTestBehavior(view.profileStore.origins.length > 0 || view.activeTab === 3 ? HitTestMode.Default : HitTestMode.None)
            .onTouch((event: TouchEvent) => view.onTouch(event))
          }


}

@Builder
function PinmonyBuildProfileStatus(view: PinmonyProfileRootView) {
    Column() {
      Column({ space: 18 }) {
        if (view.profileStore.profileLoading) {
          LoadingProgress().color($r('app.color.accent')).width(36).height(36)
          Text(PinmonyI18n.text(PinmonyI18n.message("pm_loading_profile_503bfab4")))
            .fontSize(15)
            .fontColor($r('app.color.secondary_text'))
        } else {
          Text(view.profileStore.profileError)
            .fontSize(16)
            .fontColor($r('app.color.primary_text'))
          Button(PinmonyI18n.text("pm_reload_df7392cc"))
            .onClick(() => view.refreshProfile())
        }
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .padding({ bottom: 100 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))

}
