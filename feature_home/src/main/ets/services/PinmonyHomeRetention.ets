import { PinmonyHomePin } from '../models/PinmonyHome';

// New document controls can change without replacing the feed the user returned to.
export function retainHomePins(saved: PinmonyHomePin[], live: PinmonyHomePin[], append: boolean): PinmonyHomePin[] {
  const merged: PinmonyHomePin[] = saved.map((pin: PinmonyHomePin): PinmonyHomePin => {
    const current: PinmonyHomePin | undefined = live.find((item: PinmonyHomePin): boolean => item.pinUrl === pin.pinUrl);
    return { id: pin.id, pinUrl: pin.pinUrl, imageUrl: pin.imageUrl,
      imageWidth: pin.imageWidth, imageHeight: pin.imageHeight,
      title: current?.title || pin.title, hasMore: current?.hasMore || false, saved: pin.saved === true };
  });
  if (append) {
    live.forEach((pin: PinmonyHomePin): void => {
      if (!merged.some((item: PinmonyHomePin): boolean => item.pinUrl === pin.pinUrl)) merged.push(pin);
    });
  }
  return merged;
}
