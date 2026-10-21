export interface PinmonyImageCrop { x: number; y: number; w: number; h: number; }
export interface PinmonyRelatedPin {
  id: string; pinUrl: string; imageUrl: string; title: string; imageWidth: number; imageHeight: number;
}
export interface PinmonyVisualResult {
  pin: string; loading: boolean; error: string; ended: boolean; items: PinmonyRelatedPin[];
}
