import { PinWebHomePin } from '../models/PinWebHome';

// New document controls can change without replacing the feed the user returned to.
export function retainHomePins(saved: PinWebHomePin[], live: PinWebHomePin[], append: boolean): PinWebHomePin[] {
  const merged: PinWebHomePin[] = saved.map((pin: PinWebHomePin): PinWebHomePin => {
    const current: PinWebHomePin | undefined = live.find((item: PinWebHomePin): boolean => item.pinUrl === pin.pinUrl);
    return { id: pin.id, pinUrl: pin.pinUrl, imageUrl: pin.imageUrl,
      imageWidth: pin.imageWidth, imageHeight: pin.imageHeight,
      title: current?.title || pin.title, hasMore: current?.hasMore || false, saved: pin.saved === true };
  });
  if (append) {
    live.forEach((pin: PinWebHomePin): void => {
      if (!merged.some((item: PinWebHomePin): boolean => item.pinUrl === pin.pinUrl)) merged.push(pin);
    });
  }
  return merged;
}
