import { PinmonyBoardCoverCrop, PinmonyBoardPin, PinmonyBoardCoverPreview } from '../models/PinmonyBoardDetail';

export function boardCoverPreview(pin: PinmonyBoardPin, x: number, y: number, width: number, height: number,
  sourceWidth: number = 236, frameAspect: number = 5/3): PinmonyBoardCoverPreview | undefined {
  const sourceHeight: number = sourceWidth * pin.imageHeight / pin.imageWidth;
  if(![x,y,width,height,sourceWidth,sourceHeight,frameAspect].every((v: number): boolean => Number.isFinite(v)) ||
    x < 0 || y < 0 || width <= 0 || height <= 0 || sourceWidth <= 0 || frameAspect <= 0 || x+width > sourceWidth+1 || y+height > sourceHeight+1)return undefined;
  // Use one scale for both axes, then center the saved crop in the display frame.
  // Percentages are relative to different frame dimensions, so they must account for its aspect ratio.
  const scale: number = Math.max(frameAspect/width,1/height);
  return {imageUrl:pin.previewImageUrl || pin.imageUrl,width:(100*sourceWidth*scale/frameAspect)+'%',height:(100*sourceHeight*scale)+'%',
    left:(100*((frameAspect-width*scale)/2-x*scale)/frameAspect)+'%',top:(100*((1-height*scale)/2-y*scale))+'%'};
}

// Captured BoardCoverImageCrop formula: 236px-wide frame, aspect-fill scale,
// clamped image position and rounded source pixels. Keep square as the legacy default.
export function boardCoverCrop(pin: PinmonyBoardPin, x: number = 0, y: number = 0, frameAspect: number = 1): PinmonyBoardCoverCrop {
  const scale: number = Math.max(236/pin.imageWidth,236/frameAspect/pin.imageHeight);
  const width: number = Math.max(1,Math.round(236/scale));
  const height: number = Math.max(1,Math.round(236/frameAspect/scale));
  return {pinId:pin.id,cropX:Math.round(Math.max(0,Math.min(pin.imageWidth-width,x))),
    cropY:Math.round(Math.max(0,Math.min(pin.imageHeight-height,y))),width:width,height:height,scale:scale};
}
