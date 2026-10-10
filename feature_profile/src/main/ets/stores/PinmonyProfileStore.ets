import { PinmonyPublishFlow } from '../models/PinmonyPublishFlow';
import { PinmonyProfilePanel } from '../models/PinmonyProfilePanel';
import { PinmonyProfileCache } from '../services/PinmonyProfileCache';
import { PinmonyProfileSnapshot, PinmonyPublishOption } from '../models/PinmonyProfile';

export interface ProfileOrigin { page: string; tab: number; profile?: PinmonyProfileSnapshot; scroll: number; panel?: PinmonyProfilePanel; }

@Observed
export class PinmonyProfileStore {
  onNavigationChange: (() => void) | undefined = undefined;
  panel: PinmonyProfilePanel | undefined = undefined;
  panelToken: number = 0;
  origins: ProfileOrigin[] = [];
  profileSession: number = 0;
  profileUrl: string = '';
  profileRequestToken: number = 0;
  private _profile: PinmonyProfileSnapshot | undefined = undefined;
  get profile(): PinmonyProfileSnapshot | undefined { return this._profile; }
  set profile(value: PinmonyProfileSnapshot | undefined) {
    if (this._profile === value) return;
    this._profile = value;
    if (this.onNavigationChange) this.onNavigationChange();
  }
  readonly profileCache: PinmonyProfileCache = new PinmonyProfileCache();
  profileActionsReady: boolean = false;
  profilePullRefreshing: boolean = false;
  profilePullToken: number = 0;
  profileScrollOffset: number = 0;
  private _profileLoading: boolean = false;
  get profileLoading(): boolean { return this._profileLoading; }
  set profileLoading(value: boolean) {
    if (this._profileLoading === value) return;
    this._profileLoading = value;
    if (this.onNavigationChange) this.onNavigationChange();
  }
  private _profileError: string = '';
  get profileError(): string { return this._profileError; }
  set profileError(value: string) {
    if (this._profileError === value) return;
    this._profileError = value;
    if (this.onNavigationChange) this.onNavigationChange();
  }
  private _profileWebFlow: boolean = false;
  get profileWebFlow(): boolean { return this._profileWebFlow; }
  set profileWebFlow(value: boolean) {
    if (this._profileWebFlow === value) return;
    this._profileWebFlow = value;
    if (this.onNavigationChange) this.onNavigationChange();
  }
  profileFlowLeftPage: boolean = false;
  profileSwitching: boolean = false;
  publishFlow: PinmonyPublishFlow | undefined = undefined;
  publishFlowToken: number = 0;
  publishPicking: boolean = false;
  publishOptions: PinmonyPublishOption[] = [];
  publishTitle: string = '';
  publishLoading: boolean = false;
  publishRequestToken: number = 0;
  publishPreparing: boolean = false;
}
