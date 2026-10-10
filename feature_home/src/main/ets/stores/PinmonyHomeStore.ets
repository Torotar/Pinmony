import { PinmonyHomeMenuState } from '../models/PinmonyHomeMenu';
import { PinmonyHomeSnapshot } from '../models/PinmonyHome';

@Observed
export class PinmonyHomeStore {
  diskCacheRestored: boolean = false;
  diskCacheRestoredAt: number = 0;
  startupFeedCommitted: boolean = false;
  homeRequestToken: number = 0;
  homeMoreRequestToken: number = 0;
  pendingHomeTab: string = '';
  homeMoreLoadingId: string = '';
  homeTabNeedsRedispatch: boolean = false;
  homeMenuPin: string = '';
  homeMenuPage: string = '';
  customHomeMenu: PinmonyHomeMenuState | undefined = undefined;
  customHomeMenuToken: number = 0;
  pendingHomeMorePin: string = '';
  homeDetailMoreToken: number = 0;
  home: PinmonyHomeSnapshot | undefined = undefined;
  cachedHome: PinmonyHomeSnapshot | undefined = undefined;
  cachedHomeScrollOffset: number = 0;
  homeSourceWarning: string = '';
  retainingHomeFeed: boolean = false;
  homeAppendRequested: boolean = false;
  homeRefreshing: boolean = false;
  homeRefreshToken: number = 0;
  homeRefreshAwaitingPage: boolean = false;
  homeActionsReady: boolean = false;
  homeLoading: boolean = false;
  homeError: string = '';

  // Presentation may start before the hidden Web route finishes navigating.
  // A current empty/error state takes priority over a previous cached feed.
  homeForPresentation(pageKey: string): PinmonyHomeSnapshot | undefined {
    if (!pageKey) return undefined;
    if (this.home?.pageKey === pageKey) return this.home;
    if (this.cachedHome?.pageKey === pageKey && this.cachedHome.pins.length > 0) return this.cachedHome;
    return undefined;
  }
}
