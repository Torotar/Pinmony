import { PinmonyHomeMenuState } from '../models/PinmonyHomeMenu';
import { PinmonyHomeSnapshot, PinmonyHomeImageRecovery, PinmonyHomeTab } from '../models/PinmonyHome';

@Observed
export class PinmonyHomeStore {
  imageRecovery: PinmonyHomeImageRecovery | undefined = undefined;
  recoverImage(pinUrl: string, imageUrl: string): void {
    if (!/^https:\/\/(?:www|uk)\.pinterest\.com\/pin\/\d+\/$/.test(pinUrl) || !/^https:\/\/i\.pinimg\.com\//.test(imageUrl)) return;
    this.imageRecovery = { pinUrl: pinUrl, imageUrl: imageUrl, revision: (this.imageRecovery?.revision || 0) + 1 };
  }
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
  inboxMenuPending: boolean = false;
  customHomeMenuToken: number = 0;
  pendingHomeMorePin: string = '';
  homeDetailMoreToken: number = 0;
  home: PinmonyHomeSnapshot | undefined = undefined;
  cachedHome: PinmonyHomeSnapshot | undefined = undefined;
  cachedHomeScrollOffset: number = 0;
  homePresentationEpoch: number = 0;
  private readonly categoryScrollOffsets: Map<string, number> = new Map<string, number>();

  categoryScrollOffset(pageKey: string, categoryId: string): number | undefined {
    return this.categoryScrollOffsets.get(pageKey + '|' + categoryId);
  }

  rememberCategoryScroll(pageKey: string, categoryId: string, offset: number): void {
    if (!pageKey || !categoryId || !Number.isFinite(offset)) return;
    this.categoryScrollOffsets.set(pageKey + '|' + categoryId, Math.max(0, offset));
    const selected: string = this.cachedHome?.tabs.find((tab: PinmonyHomeTab): boolean => tab.selected)?.id || '';
    if (this.cachedHome?.pageKey === pageKey && selected === categoryId) this.cachedHomeScrollOffset = Math.max(0, offset);
  }

  clearCategoryPositions(): void {
    this.categoryScrollOffsets.clear();
    this.cachedHomeScrollOffset = 0;
    this.homePresentationEpoch++;
  }
  homeSourceWarning: string = '';
  retainingHomeFeed: boolean = false;
  homeAppendRequested: boolean = false;
  homeRefreshing: boolean = false;
  homeRefreshToken: number = 0;
  homeRefreshAwaitingPage: boolean = false;
  homeNativeReadsReady: boolean = false;
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
