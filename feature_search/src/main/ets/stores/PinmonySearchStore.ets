import { PinmonySearchFilterOption, PinmonySearchSnapshot } from '../models/PinmonySearch';
import { PinmonySearchCache } from '../services/PinmonySearchCache';

interface PinmonySearchScrollPositions {
  current: number;
  retained: number;
}

@Observed
export class PinmonySearchStore {
  searchNativeReadsReady: boolean = false;
  searchNativeInputReady: boolean = false;
  searchDiscoveryReadsReady: boolean = false;
  onNavigationChange: (() => void) | undefined = undefined;
  private _search: PinmonySearchSnapshot | undefined = undefined;
  get search(): PinmonySearchSnapshot | undefined { return this._search; }
  set search(value: PinmonySearchSnapshot | undefined) {
    if (this._search === value) return;
    this._search = value;
    if (this.onNavigationChange) this.onNavigationChange();
  }
  searchLoading: boolean = false;
  submittedPinLoading: boolean = false;
  searchError: string = '';
  searchFilterOptions: PinmonySearchFilterOption[] = [];
  searchFilterLoading: boolean = false;
  searchFilterOpen: boolean = false;
  searchFilterError: string = '';
  searchFilterToken: number = 0;
  searchProductDomains: PinmonySearchFilterOption[] = [];
  searchProductCurrency: string = '';
  searchProductPrices: boolean = false;
  searchProductLower: number = 0;
  searchProductUpper: number = 0;
  searchProductMin: string = '';
  searchProductMax: string = '';
  searchProductError: string = '';
  searchInputFocused: boolean = false;
  photoSearchVisible: boolean = false;
  searchOpenHistory?: () => void;
  searchInputStopEditing: ((deferRootReturn?: boolean) => boolean) | undefined = undefined;
  searchRequestToken: number = 0;
  searchQueryToken: number = 0;
  searchIntentToken: number = 0;
  searchQueryClearPage: string = '';
  searchReturnPageKey: string = '';
  retainedSearch: PinmonySearchSnapshot | undefined = undefined;
  searchQuizReturnPage: string = '';
  readonly searchCache: PinmonySearchCache = new PinmonySearchCache();
  readonly knownSearchPinTitles: Map<string, string> = new Map<string, string>();
  // Live scroll positions are restoration data, not observable UI state.
  private readonly scrollPositions: PinmonySearchScrollPositions = { current: 0, retained: 0 };
  get searchScrollOffset(): number { return this.scrollPositions.current; }
  set searchScrollOffset(offset: number) { this.scrollPositions.current = offset; }
  get retainedSearchScrollOffset(): number { return this.scrollPositions.retained; }
  set retainedSearchScrollOffset(offset: number) { this.scrollPositions.retained = offset; }

  rememberScrollPosition(pageKey: string, offset: number): void {
    this.searchCache.updateScrollOffset(pageKey, offset);
    // Bypass top-level setters during a gesture so @Observed does not send the
    // offset back through initialResultsScrollOffset on every pixel of motion.
    if (this.search?.pageKey === pageKey) this.scrollPositions.current = offset;
    if (this.retainedSearch?.pageKey === pageKey) this.scrollPositions.retained = offset;
  }
  searchResultsResetPending: boolean = false;
  searchActionsReady: boolean = true;
  searchInputReady: boolean = false;
}
