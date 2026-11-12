import { PinmonyBoardDetail } from 'feature_board';
import { PinmonyProfilePanel } from 'feature_profile';
export interface PinmonyProfileBoardOrigin {
  board?: PinmonyBoardDetail;
  returnUrl: string;
  returnPage: string;
  rootTab: number;
  cancelledPins?: string[];
}

export interface PinmonyFollowingBoardReturn {
  panel: PinmonyProfilePanel;
  board: string;
  source: string;
  mode: string;
  section: string;
  account: string;
  generation: number;
  origin: string;
  depth: number;
}
