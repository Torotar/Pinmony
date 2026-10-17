import { PinmonyBoardDetail } from 'feature_board';
export interface PinmonyProfileBoardOrigin {
  board?: PinmonyBoardDetail;
  returnUrl: string;
  returnPage: string;
  rootTab: number;
  cancelledPins?: string[];
}

export interface PinmonyFollowingBoardReturn {
  board: string;
  source: string;
  mode: string;
  section: string;
  account: string;
  generation: number;
  origin: string;
  depth: number;
}
