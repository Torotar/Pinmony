import { PinmonyBoardDetail } from 'feature_board';
export interface PinmonyProfileBoardOrigin {
  board?: PinmonyBoardDetail;
  returnUrl: string;
  returnPage: string;
  rootTab: number;
  cancelledPins?: string[];
}
