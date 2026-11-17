import { PinmonyCarousel, PinmonyCarouselItem } from '../models/PinmonyDetail';

// CDN size and format may change between a feed thumbnail and its detail slot.
function carouselPhotoIdentity(source: string): string {
  const match: RegExpMatchArray | null = source.match(
    /^https:\/\/(?:[a-z0-9-]+\.)*pinimg\.com\/(?:[0-9]+x(?:[0-9]+)?|originals|orig)\/([^?#]+)(?:[?#].*)?$/i);
  return match ? match[1].replace(/\.(?:jpg|jpeg|png|webp|avif)$/i, '') : '';
}

// -1 means no confirmed match. Callers retain their established first-slot fallback.
export function carouselEntryIndex(carousel: PinmonyCarousel | undefined, pinUrl: string, imageUrl: string): number {
  if (!carousel || carousel.freeScroll || !pinUrl || !imageUrl) return -1;
  const pin: RegExpMatchArray | null = pinUrl.match(/\/pin\/([^/?#]+)\/?(?:[?#].*)?$/);
  if (!pin || pin[1] !== carousel.pinId) return -1;
  const exact: number = carousel.items.findIndex((item: PinmonyCarouselItem): boolean => item.imageUrl === imageUrl);
  if (exact >= 0) return exact;
  const identity: string = carouselPhotoIdentity(imageUrl);
  return identity ? carousel.items.findIndex((item: PinmonyCarouselItem): boolean =>
    carouselPhotoIdentity(item.imageUrl) === identity) : -1;
}
