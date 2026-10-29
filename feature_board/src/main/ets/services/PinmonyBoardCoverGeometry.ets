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

// BoardCoverImageCrop in the captured website bundle: a 236px square frame,
// aspect-fill scale, clamped image position, rounded source-pixel coordinates.
export function boardCoverCrop(pin: PinmonyBoardPin, x: number = 0, y: number = 0): PinmonyBoardCoverCrop {
  const side: number = Math.min(pin.imageWidth, pin.imageHeight);
  return {pinId:pin.id,cropX:Math.round(Math.max(0,Math.min(pin.imageWidth-side,x))),
    cropY:Math.round(Math.max(0,Math.min(pin.imageHeight-side,y))),width:side,height:side,scale:236/side};
}
