import { PinmonyBoardNativeReads } from './PinmonyBoardNativeReads';
import { PinmonyProfileNativeReads } from './PinmonyProfileNativeReads';
import { PinmonyInboxMessagesNativeReads } from './PinmonyInboxMessagesNativeReads';
import { PinmonyInboxUpdatesNativeReads } from './PinmonyInboxUpdatesNativeReads';
import { PinmonySearchNativeReads } from './PinmonySearchNativeReads';
import { PinmonySearchDiscoveryNativeReads } from './PinmonySearchDiscoveryNativeReads';
import { PinmonyHomeNativeReads } from './PinmonyHomeNativeReads';
import { PinmonyDetailNativeReads } from './PinmonyDetailNativeReads';
import { PinmonyControllerHooks } from './PinmonyControllerLifecycle';

import { PinmonySearchStore } from 'feature_search';
import { PinmonySharePanelsController, PinmonyDetailOperationsController, PinmonyDetailReadController, PinmonyPostPanelsController, PinmonyPinStore, PinmonyDetailController } from 'feature_pin';
import { PinmonyBoardOperationsController, PinmonyBoardStateController, PinmonyBoardCollaboratorsController, PinmonyBoardStore } from 'feature_board';
import { PinmonyPhotoMenuCoordinator } from './PinmonyPhotoMenuCoordinator';
import { PinmonyRootContextCoordinator } from './PinmonyRootContextCoordinator';
import { PinmonyInboxReadController, PinmonyInboxActionsController, PinmonyInboxStore, PinmonyBoardInvitationController } from 'feature_inbox';
import { PinmonyControllerLifecycle } from './PinmonyControllerLifecycle';
import { PinmonyProfileActionsController, PinmonyProfileReadController, PinmonyPublishController, PinmonyProfileStore } from 'feature_profile';
import { PinmonySettingsController } from 'feature_settings';

type PinmonyNavigationAwareStore = PinmonyPinStore | PinmonyBoardStore | PinmonyProfileStore | PinmonyInboxStore | PinmonySearchStore;

export interface PinmonyProductControllers {
  boardCollaborators: PinmonyBoardCollaboratorsController;
  publish: PinmonyPublishController;
  boardInvitation: PinmonyBoardInvitationController;
  boardState: PinmonyBoardStateController;
  photoMenu: PinmonyPhotoMenuCoordinator;
  rootContext: PinmonyRootContextCoordinator;
  boardOperations: PinmonyBoardOperationsController;
  settings: PinmonySettingsController;
  inboxActions: PinmonyInboxActionsController;
  detail: PinmonyDetailController;
  detailRead: PinmonyDetailReadController;
  homeNativeReads: PinmonyHomeNativeReads;
  searchNativeReads: PinmonySearchNativeReads;
  searchDiscoveryNativeReads: PinmonySearchDiscoveryNativeReads;
  detailNativeReads: PinmonyDetailNativeReads;
  detailOperations: PinmonyDetailOperationsController;
  sharePanels: PinmonySharePanelsController;
  postPanels: PinmonyPostPanelsController;
  boardNativeReads: PinmonyBoardNativeReads;
  profileNativeReads: PinmonyProfileNativeReads;
  profileRead: PinmonyProfileReadController;
  profileActions: PinmonyProfileActionsController;
  inboxMessagesNativeReads: PinmonyInboxMessagesNativeReads;
  inboxUpdatesNativeReads: PinmonyInboxUpdatesNativeReads;
  inboxRead: PinmonyInboxReadController;
}

function pauseHook(name: string, pause: () => void): PinmonyControllerHooks {
  return { name: name, pause: pause };
}

function resumeHook(name: string, pause: () => void, resume: () => void): PinmonyControllerHooks {
  return { name: name, pause: pause, resume: resume };
}

export function assembleControllerLifecycle(controllers: PinmonyProductControllers,
  pauseCoordination: () => void): PinmonyControllerLifecycle {
  return new PinmonyControllerLifecycle([
    pauseHook('board-collaborators', (): void => controllers.boardCollaborators.pause()),
    resumeHook('publish', (): void => controllers.publish.pause(), (): void => controllers.publish.resume()),
    resumeHook('board-invitation', (): void => controllers.boardInvitation.pause(), (): void => controllers.boardInvitation.resume()),
    resumeHook('board-state', (): void => controllers.boardState.pause(), (): void => controllers.boardState.resume()),
    { name: 'coordinator-tasks', pause: pauseCoordination },
    pauseHook('photo-menu', (): void => controllers.photoMenu.pause()),
    pauseHook('root-context', (): void => controllers.rootContext.pause()),
    pauseHook('board-operations', (): void => controllers.boardOperations.pause()),
    pauseHook('settings', (): void => controllers.settings.pause()),
    pauseHook('inbox-actions', (): void => controllers.inboxActions.pause()),
    pauseHook('detail-actions', (): void => controllers.detail.pause()),
    resumeHook('board-native', (): void => controllers.boardNativeReads.pause(), (): void => {controllers.boardNativeReads.demand();}),
    pauseHook('profile-native', (): void => controllers.profileNativeReads.pause()),
    pauseHook('inbox-messages-native', (): void => controllers.inboxMessagesNativeReads.pause()),
    pauseHook('inbox-updates-native', (): void => controllers.inboxUpdatesNativeReads.pause()),
    pauseHook('search-native', (): void => controllers.searchNativeReads.pause()),
    pauseHook('search-discovery-native', (): void => controllers.searchDiscoveryNativeReads.pause()),
    pauseHook('home-native-reads', (): void => controllers.homeNativeReads.pause()),
    pauseHook('detail-native-reads', (): void => controllers.detailNativeReads.pause()),
    pauseHook('detailReadController', (): void => controllers.detailRead.pause()),
    pauseHook('detailOperationsController', (): void => controllers.detailOperations.pause()),
    pauseHook('sharePanelsController', (): void => controllers.sharePanels.pause()),
    resumeHook('post-panels', (): void => controllers.postPanels.pause(), (): void => controllers.postPanels.resume()),
    resumeHook('profile-read', (): void => controllers.profileRead.pause(), (): void => controllers.profileRead.resume()),
    resumeHook('profile-actions', (): void => controllers.profileActions.pause(), (): void => controllers.profileActions.resume()),
    resumeHook('inbox-read', (): void => controllers.inboxRead.pause(), (): void => controllers.inboxRead.resume())
  ]);
}

export function bindStoreNavigation(stores: PinmonyNavigationAwareStore[],
  callback: (() => void) | undefined): void {
  stores.forEach((store: PinmonyNavigationAwareStore): void => { store.onNavigationChange = callback; });
}
