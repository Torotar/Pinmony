import { PinWebVisualResult, emptyVisualResult } from '../models/PinWebVisualSearch';
import { ShareSheetOption, MoreSheetOption } from '../models/PinWebSheets';
import { PinWebConfirmedSaves } from '../services/PinWebConfirmedSaves';
import { PinWebDetailSnapshot } from '../models/PinWebDetail';
import { PinWebEditPinResult } from '../models/PinWebEditPin';
import { PinWebCommentResult, PinWebSaveResult } from '../models/PinWebComments';
import { PinWebDetailCache } from '../services/PinWebDetailCache';
import { PinWebDetailPrefetch } from '../services/PinWebDetailPrefetch';

interface DetailOrigin {
  pin: string;
  origin: string;
}

@Observed
export class PinWebPinStore {
  detailPresentationOnly: boolean = false;
  detailPreparing: boolean = false;
  readonly detailPrefetch: PinWebDetailPrefetch = new PinWebDetailPrefetch();
  prefetchedImageUrls: string[] = [];
  onNavigationChange: (() => void) | undefined = undefined;
  readonly confirmedSaves: PinWebConfirmedSaves = new PinWebConfirmedSaves();
  imageLayer: string = '';
  viewerSaveBusy: boolean = false;
  visualToken: number = 0;
  visualResult: PinWebVisualResult = emptyVisualResult();
  shareSession: number = 0;
  commentResult: PinWebCommentResult = { pin: '', loading: true, error: '', items: [] };
  commentToken: number = 0;
  saveResult: PinWebSaveResult = { pin: '', loading: true, busy: false,
    error: '', feedback: '', items: [], shortlist: [], savedId: '', savedBoard: '' };
  saveToken: number = 0;
  editToken: number = 0;
  editResult: PinWebEditPinResult = {
    pin: '', loading: true, busy: false, error: '', phase: 'edit', imageUrl: '', title: '', description: '', ai: false, uncertain: false, done: '',
    board: { id: '', name: '', imageUrl: '', enabled: false, secret: false },
    picker: { pin: '', loading: false, busy: false, error: '', feedback: '', items: [], shortlist: [], savedId: '', savedBoard: '' }
  };
  shareSnackKey: string = '';
  shareBackHandledUntil: number = 0;
  shareFeedbackSnackKey: string = '';
  saveUndoPin: string = '';
  saveUndoId: string = '';
  saveCreating: boolean = false;
  feedbackUndoPin: string = '';
  feedbackUndoSession: number = 0;
  feedbackUndoBusy: boolean = false;
  ignoredShareSession: number = 0;
  shareOpenRequestedSession: number = 0;
  sharePin: string = '';
  moreSession: number = 0;
  moreApiMode: boolean = false;
  ignoredMoreSession: number = 0;
  morePin: string = '';
  detailSession: number = 0;
  detailPin: string = '';
  detailImageFailedPin: string = '';
  readonly detailCache: PinWebDetailCache = new PinWebDetailCache();
  detailScrollOffset: number = 0;
  shareOptions: ShareSheetOption[] = [];
  shareActions: ShareSheetOption[] = [];
  shareContacts: ShareSheetOption[] = [];
  shareOnPinDetail: boolean = false;
  shareTitle: string = '';
  shareSectionLabel: string = '';
  shareSearchId: string = '';
  shareSearchLabel: string = '';
  shareSendId: string = '';
  shareSendLabel: string = '';
  shareSearchActive: boolean = false;
  shareQuery: string = '';
  shareError: string = '';
  shareFeedback: string = '';
  shareLoading: boolean = false;
  moreTitle: string = '';
  moreOptions: MoreSheetOption[] = [];
  moreError: string = '';
  moreLoading: boolean = false;
  private _detail: PinWebDetailSnapshot | undefined = undefined;
  get detail(): PinWebDetailSnapshot | undefined { return this._detail; }
  set detail(value: PinWebDetailSnapshot | undefined) {
    if (this._detail === value) return;
    this._detail = value;
    if (this.onNavigationChange) this.onNavigationChange();
  }
  private _detailOpeningPin: string = '';
  get detailOpeningPin(): string { return this._detailOpeningPin; }
  set detailOpeningPin(value: string) {
    if (this._detailOpeningPin === value) return;
    this._detailOpeningPin = value;
    if (this.onNavigationChange) this.onNavigationChange();
  }
  detailApiError: string = '';
  detailApiRetryable: boolean = true;
  detailMediaUnsupported: boolean = false;
  detailOpeningToken: number = 0;
  detailActionsReady: boolean = false;
  private _detailWebFlow: boolean = false;
  get detailWebFlow(): boolean { return this._detailWebFlow; }
  set detailWebFlow(value: boolean) {
    if (this._detailWebFlow === value) return;
    this._detailWebFlow = value;
    if (this.onNavigationChange) this.onNavigationChange();
  }
  detailReturnUrl: string = '';
  private detailOrigins: DetailOrigin[] = [];

  rememberDetailOrigin(pin: string, origin: string): void {
    if (!pin || !origin || origin.match(/\/pin\/(\d+)/)?.[1] === pin) return;
    if (!/\/pin\/\d+(?:\/|$)/.test(origin)) this.detailOrigins = [];
    this.detailOrigins.push({ pin: pin, origin: origin });
    if (this.detailOrigins.length > 64) this.detailOrigins.shift();
  }

  detailOrigin(pin: string): string {
    for (let index: number = this.detailOrigins.length - 1; index >= 0; index--) {
      if (this.detailOrigins[index].pin === pin) return this.detailOrigins[index].origin;
    }
    return '';
  }

  leaveDetailOrigin(pin: string): void {
    for (let index: number = this.detailOrigins.length - 1; index >= 0; index--) {
      if (this.detailOrigins[index].pin === pin) { this.detailOrigins.splice(index); return; }
    }
  }

  clearDetailOrigins(): void { this.detailOrigins = []; }
  videoForeground: boolean = true;
}
