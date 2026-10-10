import { PinmonyRelatedPin } from './PinmonyDetail';
export interface PinmonyImageCrop { x: number; y: number; w: number; h: number; }
export interface PinmonyVisualResult {
  pin: string; loading: boolean; error: string; ended: boolean; items: PinmonyRelatedPin[];
}
export function emptyVisualResult(): PinmonyVisualResult {
  return { pin: '', loading: false, error: '', ended: false, items: [] };
}
