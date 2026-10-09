import { PinWebBoardDetail } from '../models/PinWebBoardDetail';

@Observed
export class PinWebBoardStore {
  onNavigationChange: (() => void) | undefined = undefined;
  boardDetail: PinWebBoardDetail | undefined = undefined;
  private _pendingBoardUrl: string = '';
  get pendingBoardUrl(): string { return this._pendingBoardUrl; }
  set pendingBoardUrl(value: string) {
    if (this._pendingBoardUrl === value) return;
    this._pendingBoardUrl = value;
    if (this.onNavigationChange) this.onNavigationChange();
  }
  pendingBoardSource: string = '';
  boardReturnUrl: string = '';
  boardReturnPage: string = '';
  boardOpeningToken: number = 0;
}
