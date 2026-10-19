import { PinmonySearchFilterOption, PinmonySearchSnapshot } from '../models/PinmonySearch';
import { PinmonySearchCache } from '../services/PinmonySearchCache';

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
  searchError: string = '';
  searchFilterOptions: PinmonySearchFilterOption[] = [];
  searchFilterLoading: boolean = false;
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
  searchOpenHistory?: () => void;
  searchInputStopEditing: (() => void) | undefined = undefined;
  searchRequestToken: number = 0;
  searchQueryToken: number = 0;
  searchIntentToken: number = 0;
  searchQueryClearPage: string = '';
  searchReturnPageKey: string = '';
  retainedSearch: PinmonySearchSnapshot | undefined = undefined;
  searchQuizReturnPage: string = '';
  readonly searchCache: PinmonySearchCache = new PinmonySearchCache();
  readonly knownSearchPinTitles: Map<string, string> = new Map<string, string>();
  searchScrollOffset: number = 0;
  retainedSearchScrollOffset: number = 0;
  searchResultsResetPending: boolean = false;
  searchActionsReady: boolean = true;
  searchInputReady: boolean = false;
}
