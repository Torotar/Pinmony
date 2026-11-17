export interface PinmonyCardImage {
  id: string;
  url: string;
  width: number;
  height: number;
}

interface PinmonyCardImageResource { url?: string; width?: number; height?: number; }
interface PinmonyCardSlotResource { id?: string; slot_id?: string; images?: Record<string, PinmonyCardImageResource>; }
interface PinmonyCardCarouselResource { carousel_slots?: PinmonyCardSlotResource[]; }

export function normalizeCardCarouselImages(images: PinmonyCardImage[] | undefined): PinmonyCardImage[] {
  if (!Array.isArray(images) || images.length < 2 || images.length > 100) return [];
  if (!images.every((photo: PinmonyCardImage): boolean => !!photo && typeof photo.id === 'string' &&
    typeof photo.url === 'string' && photo.url.length <= 2000 && /^https:\/\/(?:[a-z0-9-]+\.)*pinimg\.com\//i.test(photo.url) &&
    Number.isFinite(photo.width) && photo.width > 0 && Number.isFinite(photo.height) && photo.height > 0)) return [];
  return images.map((photo: PinmonyCardImage): PinmonyCardImage => ({ id: photo.id, url: photo.url, width: photo.width, height: photo.height }));
}

// Read only existing feed payloads; never fetch a detail for every visible card.
export function pinmonyCardCarouselImages(data: Object | undefined): PinmonyCardImage[] {
  const slots: PinmonyCardSlotResource[] | undefined = (data as PinmonyCardCarouselResource | undefined)?.carousel_slots;
  if (!Array.isArray(slots) || slots.length < 2 || slots.length > 100) return [];
  const images: PinmonyCardImage[] = [];
  for (let index: number = 0; index < slots.length; index++) {
    const slot: PinmonyCardSlotResource | undefined = slots[index];
    const image: PinmonyCardImageResource | undefined = ['474x', '736x', '564x', 'orig', '236x']
      .map((size: string): PinmonyCardImageResource | undefined => slot?.images?.[size])
      .find((value: PinmonyCardImageResource | undefined): boolean => !!value && typeof value.url === 'string' &&
        value.url.length <= 2000 && /^https:\/\/(?:[a-z0-9-]+\.)*pinimg\.com\//i.test(value.url) &&
        Number.isFinite(value.width) && Number.isFinite(value.height) && (value.width || 0) > 0 && (value.height || 0) > 0);
    // Do not silently drop unavailable slots and misrepresent the dot count/order.
    if (!image) return [];
    images.push({ id: String(slot?.id || slot?.slot_id || index), url: image.url!, width: image.width!, height: image.height! });
  }
  return images;
}
