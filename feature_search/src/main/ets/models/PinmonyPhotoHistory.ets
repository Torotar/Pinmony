export interface PinmonyPhotoHistoryItem { id: string; imageUrl: string; width: number; height: number; }
export interface PinmonyPhotoHistoryPage { items: PinmonyPhotoHistoryItem[]; cursor: string; ended: boolean; }
interface Size { width: number; height: number; }
interface Item { id: string; type: string; image_urls: Record<string, string>; image_sizes: Record<string, Size>; }
interface Resource { status: string; code: number; endpoint_name: string; data: Item[]; bookmark?: string; }
interface Response { resource_response: Resource; }
export function parsePhotoHistory(text: string, previous: string): PinmonyPhotoHistoryPage {
  const resource: Resource = (JSON.parse(text) as Response).resource_response;
  if (!resource || resource.status !== 'success' || resource.code !== 0 || resource.endpoint_name !== 'v3_get_lens_histories' ||
    !Array.isArray(resource.data) || resource.data.length > 1000) throw new Error('history-response');
  const items: PinmonyPhotoHistoryItem[] = [];
  resource.data.forEach((item: Item): void => {
    if (item.type !== 'lens_image' || typeof item.id !== 'string' || !item.id || item.id.length > 200 || !item.image_urls || !item.image_sizes) return;
    const tier: string = item.image_urls['736x'] ? '736x' : '1200x';
    const url: string = item.image_urls[tier], size: Size = item.image_sizes[tier];
    if (!/^https:\/\/i\.pinimg\.com\/[A-Za-z0-9_/.%-]+\.(?:jpg|jpeg|png|webp)$/i.test(url || '') ||
      !size || !Number.isFinite(size.width) || !Number.isFinite(size.height) || size.width <= 0 || size.height <= 0) return;
    if (!items.some((p: PinmonyPhotoHistoryItem): boolean => p.id === item.id)) items.push({ id: item.id, imageUrl: url, width: size.width, height: size.height });
  });
  if (resource.data.length && !items.length) throw new Error('history-shape');
  const cursor: string = typeof resource.bookmark === 'string' && resource.bookmark.length <= 4096 ? resource.bookmark : '';
  return { items: items, cursor: cursor, ended: !cursor || cursor === '-end-' || cursor === previous || !resource.data.length };
}
