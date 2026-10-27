import { PinmonyBoardCoverCrop, PinmonyBoardPin, PinmonyBoardCoverPreview } from '../models/PinmonyBoardDetail';

export function boardCoverPreview(pin: PinmonyBoardPin, x: number, y: number, width: number, height: number,
  sourceWidth: number = 236): PinmonyBoardCoverPreview | undefined {
  const sourceHeight: number = sourceWidth * pin.imageHeight / pin.imageWidth;
  if(![x,y,width,height,sourceWidth,sourceHeight].every((v: number): boolean => Number.isFinite(v)) ||
    x < 0 || y < 0 || width <= 0 || height <= 0 || sourceWidth <= 0 || x+width > sourceWidth+1 || y+height > sourceHeight+1)return undefined;
  return {imageUrl:pin.previewImageUrl || pin.imageUrl,width:(100*sourceWidth/width)+'%',height:(100*sourceHeight/height)+'%',
    left:(-100*x/width)+'%',top:(-100*y/height)+'%'};
}

// BoardCoverImageCrop in the captured website bundle: a 236px square frame,
// aspect-fill scale, clamped image position, rounded source-pixel coordinates.
export function boardCoverCrop(pin: PinmonyBoardPin, x: number = 0, y: number = 0): PinmonyBoardCoverCrop {
  const side: number = Math.min(pin.imageWidth, pin.imageHeight);
  return {pinId:pin.id,cropX:Math.round(Math.max(0,Math.min(pin.imageWidth-side,x))),
    cropY:Math.round(Math.max(0,Math.min(pin.imageHeight-side,y))),width:side,height:side,scale:236/side};
}
