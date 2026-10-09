import { PinWebRelatedPin } from './PinWebDetail';
export interface PinWebImageCrop { x: number; y: number; w: number; h: number; }
export interface PinWebVisualResult {
  pin: string; loading: boolean; error: string; ended: boolean; items: PinWebRelatedPin[];
}
export function emptyVisualResult(): PinWebVisualResult {
  return { pin: '', loading: false, error: '', ended: false, items: [] };
}
