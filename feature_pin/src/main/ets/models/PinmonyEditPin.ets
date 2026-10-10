import { PinmonySaveBoard, PinmonySaveResult } from './PinmonyComments';

export interface PinmonyEditPinResult {
  pin: string;
  loading: boolean;
  busy: boolean;
  error: string;
  phase: string;
  imageUrl: string;
  title: string;
  description: string;
  editableContent: boolean;
  board: PinmonySaveBoard;
  ai: boolean;
  uncertain: boolean;
  done: string;
  picker: PinmonySaveResult;
}
