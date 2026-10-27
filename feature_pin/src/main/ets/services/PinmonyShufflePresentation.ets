import { PinmonyShuffleEffect, PinmonyShuffleItem, PinmonyShuffleSnapshot } from '../models/PinmonyShuffle';

interface ShuffleResource { status?: string; code?: number; error?: Object; endpoint_name?: string; data?: ShuffleData; }
interface ShuffleEnvelope { resource_response?: ShuffleResource; }
interface ShuffleData { id?: string; effect_data?: Record<string, Object>; items?: ShuffleRawItem[]; }
interface ShuffleImage { url?: string; width?: number; height?: number; }
interface ShuffleImageSource { url: string; width: number; height: number; }
interface ShufflePin { id?: string; }
interface ShuffleOffset { x?: number; y?: number; }
interface ShuffleRotation { z?: number; }
interface ShuffleSettings { offset?: ShuffleOffset; scale?: number; rotation?: ShuffleRotation;
  alpha?: number; is_hidden?: boolean; is_tappable?: boolean; effects?: Object[]; }
interface ShuffleRawItem {
  shuffle_asset?: ShuffleAsset;
  id?: string; item_type?: number; pin?: ShufflePin;
  images?: Record<string, ShuffleImage>;
  settings?: ShuffleSettings;
  offset?: number[]; scale?: number; rotation?: number; effect_data?: Object;
}
interface ShuffleAsset { cutout_images?: Record<string,ShuffleImage>; }

function finite(value: Object | undefined, fallback: number): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}

function image(raw: ShuffleRawItem): ShuffleImageSource | undefined {
  const entries: string[] = raw.images ? Object.keys(raw.images) : [];
  for (const key of ['originals', '750x', '736x', '236x']) {
    if (!entries.includes(key)) continue;
    const candidate = raw.images?.[key];
    if (candidate?.url && candidate.url.length <= 4096 && /^https:\/\/i\.pinimg\.com\/[^\s#]+$/i.test(candidate.url)) {
      const width: number = finite(candidate.width, 0), height: number = finite(candidate.height, 0);
      return { url: candidate.url, width: width > 0 && width <= 50000 ? width : 0, height: height > 0 && height <= 50000 ? height : 0 };
    }
  }
  return undefined;
}

function effects(raw: ShuffleRawItem): PinmonyShuffleEffect[] {
  const values: Object[] = raw.settings?.effects || [];
  return values.filter((value: Object): boolean => !!value && typeof value === 'object').map((value: Object): PinmonyShuffleEffect => {
    const kind: string = typeof (value as Record<string, Object>).type === 'string' ? String((value as Record<string, Object>).type) : 'unknown';
    return { kind, value };
  });
}

export function readShufflePresentation(body: string, expectedId: string, canvasWidth: number = 0, canvasHeight: number = 0): PinmonyShuffleSnapshot | undefined {
  try {
    if (body.length > 2000000 || !/^\d{1,40}$/.test(expectedId)) return undefined;
    const envelope: ShuffleEnvelope = JSON.parse(body) as ShuffleEnvelope;
    const data: ShuffleData | undefined = envelope.resource_response?.data;
    if (envelope.resource_response?.status !== 'success' || envelope.resource_response.error || envelope.resource_response.code !== undefined && envelope.resource_response.code !== 0 || envelope.resource_response.endpoint_name !== 'v3_get_shuffle' || !data || String(data.id) !== expectedId || !Array.isArray(data.items) || data.items.length > 200) return undefined;
    const items: PinmonyShuffleItem[] = [];
    for (const raw of data.items) {
      if (!raw || typeof raw.id !== 'string' || !/^\w[\w-]{0,127}$/.test(raw.id)) return undefined;
      const settings = raw.settings;
      const offsetX: number = finite(settings?.offset?.x, finite(raw.offset?.[0], 0));
      const offsetY: number = finite(settings?.offset?.y, finite(raw.offset?.[1], 0));
      const scale: number = finite(settings?.scale, finite(raw.scale, 1));
      if (scale <= 0 || scale > 100 || Math.abs(offsetX) > 100000 || Math.abs(offsetY) > 100000 || items.some((item: PinmonyShuffleItem): boolean => item.id === raw.id)) return undefined;
      const source = image(raw);
      const cutout: string | undefined = raw.shuffle_asset?.cutout_images?.originals?.url;
      const cutoutUrl: string | undefined = typeof cutout === 'string' && cutout.length <= 4096 && /^https:\/\/i\.pinimg\.com\/[^\s#]+$/i.test(cutout) ? cutout : undefined;
      const pinId: string | undefined = raw.item_type === 1 && raw.pin?.id && /^\d{1,30}$/.test(raw.pin.id) ? raw.pin.id : undefined;
      items.push({ id: raw.id, itemType: typeof raw.item_type === 'number' ? raw.item_type : 0, pinId,
        pinUrl: pinId ? '/pin/' + pinId + '/' : undefined, imageUrl: source?.url, cutoutUrl, imageWidth: source?.width || 0,
        imageHeight: source?.height || 0, offsetX, offsetY, rotation: finite(settings?.rotation?.z, finite(raw.rotation, 0)) * 180 / Math.PI,
        scale, tappable: settings?.is_tappable === true && !!pinId, hidden: settings?.is_hidden === true,
        alpha: Math.min(1, Math.max(0, finite(settings?.alpha, 1))), effects: effects(raw) });
    }
    const effectData: Record<string, Object> | undefined = data.effect_data;
    return { id: expectedId, canvasWidth: Number.isFinite(canvasWidth) && canvasWidth > 0 && canvasWidth <= 50000 ? canvasWidth : 0,
      canvasHeight: Number.isFinite(canvasHeight) && canvasHeight > 0 && canvasHeight <= 50000 ? canvasHeight : 0,
      backgroundColor: typeof effectData?.backgroundColor === 'string' && /^#[0-9a-f]{6}$/i.test(effectData.backgroundColor) ? effectData.backgroundColor : '',
      items, motionEffect: effectData?.motionEffect };
  } catch (_) { return undefined; }
}
