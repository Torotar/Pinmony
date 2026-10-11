import { PinmonyBoardDetail } from '../models/PinmonyBoardDetail';
import { PinmonyBoardCollaborators } from '../models/PinmonyBoardCollaborators';

@Observed
export class PinmonyBoardStore {
  collaborators: PinmonyBoardCollaborators | undefined = undefined;
  collaboratorsToken: number = 0;
  onNavigationChange: (() => void) | undefined = undefined;
  boardDetail: PinmonyBoardDetail | undefined = undefined;
  presentationPage: string = '';
  presentationOnly: boolean = false;
  rootTab: number = 3;
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
  discoveryBoardPage: string = '';
  boardOpeningToken: number = 0;
}
