import { PinImageSources } from 'common_ui';
import { PinmonyRelatedPin } from '../models/PinmonyDetail';

interface RelatedImage { url: string; width: number; height: number; }
interface RelatedPin {
  id: string; type: string; images: Record<string, RelatedImage>;
  title?: string; grid_title?: string; description?: string;
}
interface RelatedResource { status: string; data: RelatedPin[]; bookmark?: string; error?: Object; code?: number; }
interface RelatedResponse { resource_response: RelatedResource; }
export interface RelatedPresentation { pins: PinmonyRelatedPin[]; ended: boolean; }

/** Read-only first-page presentation. Control readiness still belongs to the current bridge. */
export function readRelatedPresentation(body: string, pinUrl: string): RelatedPresentation | undefined {
  if (!/^https:\/\/www\.pinterest\.com\/pin\/\d+\/$/.test(pinUrl) || body.length > 1000000) return undefined;
  try {
    const resource: RelatedResource = (JSON.parse(body) as RelatedResponse).resource_response;
    if (!resource || resource.status !== 'success' || resource.error ||
        (typeof resource.code === 'number' && resource.code !== 0) || !Array.isArray(resource.data)) return undefined;
    const pins: PinmonyRelatedPin[] = [];
    for (const pin of resource.data.slice(0, 24)) {
      if (!pin || pin.type !== 'pin' || !/^\d+$/.test(String(pin.id))) continue;
      const target: string = 'https://www.pinterest.com/pin/' + pin.id + '/';
      if (target === pinUrl || pins.some((item: PinmonyRelatedPin): boolean => item.pinUrl === target)) continue;
      const sizes: Record<string, RelatedImage> = pin.images || {};
      let selected: RelatedImage | undefined;
      const images: PinImageSources = {};
      for (const tier of ['474x', '236x', '564x', '736x', 'orig']) {
        const image: RelatedImage | undefined = sizes[tier];
        if (!image || !/^https:\/\/[^\s]+$/i.test(image.url) || image.url.length > 2000) continue;
        images[tier] = { url: image.url };
        if (!selected && Number.isFinite(image.width) && image.width > 0 && image.width <= 20000 &&
            Number.isFinite(image.height) && image.height > 0 && image.height <= 20000) selected = image;
      }
      if (!selected) continue;
      const title: string = typeof pin.grid_title === 'string' ? pin.grid_title :
        typeof pin.title === 'string' ? pin.title : typeof pin.description === 'string' ? pin.description : '';
      pins.push({ id: 'api:' + pin.id, pinUrl: target, imageUrl: selected.url,
        imageWidth: selected.width, imageHeight: selected.height, images: images, title: title.trim().slice(0, 160) });
    }
    if (resource.data.length > 0 && pins.length === 0) return undefined;
    return { pins: pins, ended: !resource.bookmark || resource.bookmark === '-end-' || resource.data.length === 0 };
  } catch (_) { return undefined; }
}
