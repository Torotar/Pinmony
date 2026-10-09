import { PinWebSearchFilterOption, PinWebSearchSnapshot } from '../models/PinWebSearch';
import { PinWebSearchCache } from '../services/PinWebSearchCache';

@Observed
export class PinWebSearchStore {
  onNavigationChange: (() => void) | undefined = undefined;
  private _search: PinWebSearchSnapshot | undefined = undefined;
  get search(): PinWebSearchSnapshot | undefined { return this._search; }
  set search(value: PinWebSearchSnapshot | undefined) {
    if (this._search === value) return;
    this._search = value;
    if (this.onNavigationChange) this.onNavigationChange();
  }
  searchLoading: boolean = false;
  searchError: string = '';
  searchFilterOptions: PinWebSearchFilterOption[] = [];
  searchFilterLoading: boolean = false;
  searchFilterError: string = '';
  searchFilterToken: number = 0;
  searchInputFocused: boolean = false;
  searchInputStopEditing: (() => void) | undefined = undefined;
  searchRequestToken: number = 0;
  searchQueryToken: number = 0;
  searchIntentToken: number = 0;
  searchQueryClearPage: string = '';
  searchReturnPageKey: string = '';
  retainedSearch: PinWebSearchSnapshot | undefined = undefined;
  searchQuizReturnPage: string = '';
  readonly searchCache: PinWebSearchCache = new PinWebSearchCache();
  readonly knownSearchPinTitles: Map<string, string> = new Map<string, string>();
  searchScrollOffset: number = 0;
  retainedSearchScrollOffset: number = 0;
  searchResultsResetPending: boolean = false;
  searchActionsReady: boolean = true;
  searchInputReady: boolean = false;
}
