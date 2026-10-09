import { PinWebSaveBoard, PinWebSaveResult } from './PinWebComments';

export interface PinWebEditPinResult {
  pin: string;
  loading: boolean;
  busy: boolean;
  error: string;
  phase: string;
  imageUrl: string;
  title: string;
  description: string;
  board: PinWebSaveBoard;
  ai: boolean;
  uncertain: boolean;
  done: string;
  picker: PinWebSaveResult;
}
