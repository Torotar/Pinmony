import { PinWebPublishFlow } from '../models/PinWebPublishFlow';
import { PinWebProfilePanel } from '../models/PinWebProfilePanel';
import { PinWebProfileCache } from '../services/PinWebProfileCache';
import { PinWebProfileSnapshot, PinWebPublishOption } from '../models/PinWebProfile';

export interface ProfileOrigin { page: string; tab: number; profile?: PinWebProfileSnapshot; scroll: number; panel?: PinWebProfilePanel; }

@Observed
export class PinWebProfileStore {
  onNavigationChange: (() => void) | undefined = undefined;
  panel: PinWebProfilePanel | undefined = undefined;
  panelToken: number = 0;
  origins: ProfileOrigin[] = [];
  profileSession: number = 0;
  profileUrl: string = '';
  profileRequestToken: number = 0;
  private _profile: PinWebProfileSnapshot | undefined = undefined;
  get profile(): PinWebProfileSnapshot | undefined { return this._profile; }
  set profile(value: PinWebProfileSnapshot | undefined) {
    if (this._profile === value) return;
    this._profile = value;
    if (this.onNavigationChange) this.onNavigationChange();
  }
  readonly profileCache: PinWebProfileCache = new PinWebProfileCache();
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
  publishFlow: PinWebPublishFlow | undefined = undefined;
  publishFlowToken: number = 0;
  publishPicking: boolean = false;
  publishOptions: PinWebPublishOption[] = [];
  publishTitle: string = '';
  publishLoading: boolean = false;
  publishRequestToken: number = 0;
}
