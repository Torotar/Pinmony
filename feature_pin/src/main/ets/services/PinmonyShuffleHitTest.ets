import { PinmonyShuffleSnapshot, PinmonyShuffleItem } from '../models/PinmonyShuffle';

export interface PinmonyShuffleHitPoint { item: PinmonyShuffleItem; u: number; v: number; }

// Invert the centered contain transform of the displayed composite.
export function shuffleHitCandidates(shuffle: PinmonyShuffleSnapshot, width: number, height: number,
  x: number, y: number): PinmonyShuffleHitPoint[] {
  const hits: PinmonyShuffleHitPoint[] = [];
  if (shuffle.canvasWidth <= 0 || shuffle.canvasHeight <= 0 || width <= 0 || height <= 0 ||
      !Number.isFinite(x) || !Number.isFinite(y) || x < 0 || y < 0 || x > width || y > height) return hits;
  const ratio: number = Math.min(width / shuffle.canvasWidth,height / shuffle.canvasHeight);
  const canvasX: number = (x - width / 2) / ratio, canvasY: number = (y - height / 2) / ratio;
  if (Math.abs(canvasX) > shuffle.canvasWidth / 2 || Math.abs(canvasY) > shuffle.canvasHeight / 2) return hits;
  const unit: number = (shuffle.coordinateWidth || shuffle.canvasWidth) / shuffle.canvasWidth;
  const px: number = canvasX * unit, py: number = canvasY * unit;
  for (let index: number = shuffle.items.length - 1; index >= 0; index--) {
    const item: PinmonyShuffleItem = shuffle.items[index];
    const width: number = item.hitWidth ?? item.imageWidth, height: number = item.hitHeight ?? item.imageHeight;
    if (item.hidden || item.alpha <= 0 || item.scale <= 0 || width <= 0 || height <= 0) continue;
    const angle: number = item.rotation * Math.PI / 180;
    const dx: number = px - item.offsetX, dy: number = py - item.offsetY;
    const localX: number = (dx * Math.cos(angle) + dy * Math.sin(angle)) / item.scale;
    const localY: number = (-dx * Math.sin(angle) + dy * Math.cos(angle)) / item.scale;
    const u: number = localX / width + 0.5, v: number = localY / height + 0.5;
    if (u >= 0 && u < 1 && v >= 0 && v < 1) hits.push({item:item,u:u,v:v});
  }
  return hits;
}
