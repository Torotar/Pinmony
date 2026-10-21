import { PinmonySearchResult } from '../models/PinmonySearch';
interface PhotoImage { url: string; width: number; height: number; }
interface PhotoPin { id: string; type: string; grid_title?: string; title?: string; images?: Record<string, PhotoImage>; }
interface PhotoResponse { success: boolean; status: string; code: number; endpoint_name: string; data: PhotoPin[]; }
export function parsePhotoSearch(text: string, origin: string): PinmonySearchResult[] {
  const response: PhotoResponse = JSON.parse(text) as PhotoResponse;
  if (!/^https:\/\/(?:www|uk)\.pinterest\.com$/.test(origin) || response.success !== true ||
    response.status !== 'success' || response.code !== 0 || response.endpoint_name !== 'v3_lens_search_handler' ||
    !Array.isArray(response.data) || response.data.length > 1000) throw new Error('photo-response');
  const results: PinmonySearchResult[] = [];
  response.data.forEach((pin: PhotoPin): void => {
    if (pin.type !== 'pin' || !/^\d{1,30}$/.test(pin.id) || !pin.images || results.some((p: PinmonySearchResult): boolean => p.id === pin.id)) return;
    const image: PhotoImage | undefined = pin.images['474x'] || pin.images['736x'] || pin.images['orig'];
    if (!image || !/^https:\/\/i\.pinimg\.com\//.test(image.url) ||
      !Number.isFinite(image.width) || !Number.isFinite(image.height) || image.width <= 0 || image.height <= 0) return;
    results.push({ id: pin.id, kind: 'pin', title: (pin.grid_title || pin.title || '').slice(0, 2000), subtitle: '',
      targetUrl: origin + '/pin/' + pin.id + '/', imageUrl: image.url,
      imageWidth: image.width, imageHeight: image.height, enabled: true });
  });
  if (response.data.length && !results.length) throw new Error('photo-shape');
  return results;
}
