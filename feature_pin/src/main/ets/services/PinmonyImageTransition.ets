export interface ImageFlightRect { x: number; y: number; width: number; height: number; }
export interface PinmonyDetailEntryPhoto { pinUrl: string; imageUrl: string; x: number; y: number; width: number; height: number; imageWidth?: number; imageHeight?: number; returnPageOnly?: boolean; }
export function imageContainRect(width: number, height: number, imageWidth: number, imageHeight: number): ImageFlightRect {
  const ratio: number = imageWidth > 0 && imageHeight > 0 ? imageWidth / imageHeight : width / Math.max(1, height);
  const w: number = Math.min(width, height * ratio);
  const h: number = w / ratio;
  return { x: (width - w) / 2, y: (height - h) / 2, width: w, height: h };
}
