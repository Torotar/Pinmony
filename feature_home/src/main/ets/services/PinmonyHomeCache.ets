import { PinmonyHomeBoard, PinmonyHomePin, PinmonyHomeSnapshot, PinmonyHomeTab } from '../models/PinmonyHome';
import { ApiCache, buildCacheKey, CACHE_TTL, PinmonyRuntimeLog } from 'common_foundation';
export interface PinmonyHomeCacheRecord { snapshot: PinmonyHomeSnapshot; }
interface PinmonyHomeCacheKeyParams { pageKey: string; }

export function homeCacheKey(accountId: string, pageKey: string): string {
    const params: PinmonyHomeCacheKeyParams = { pageKey: pageKey };
    return buildCacheKey(accountId, 'home_feed', params);
  }

export function normalizeHomeBoard(value: PinmonyHomeBoard | null | undefined): PinmonyHomeBoard | undefined {
    if (!value || typeof value.id !== 'string' || !/^\d+$/.test(value.id) ||
        typeof value.name !== 'string' || !value.name.trim() ||
        typeof value.pinCount !== 'number' || !Number.isFinite(value.pinCount) ||
        value.pinCount < 0 || value.pinCount > 1000000000 ||
        typeof value.thumbnailUrl !== 'string') return undefined;
    if (value.thumbnailUrl && !/^https:\/\/(?:[a-z0-9-]+\.)*pinimg\.com\//i.test(value.thumbnailUrl)) return undefined;
    return { id: value.id, name: value.name.trim().slice(0, 160),
      pinCount: Math.floor(value.pinCount), thumbnailUrl: value.thumbnailUrl };
  }

export function normalizeHomeCacheRecord(record: PinmonyHomeCacheRecord, pageKey: string): PinmonyHomeCacheRecord | undefined {
    const saved: PinmonyHomeSnapshot | undefined = record?.snapshot;
    if (!saved || saved.kind !== 'state' || saved.pageKey !== pageKey ||
        saved.dataSource !== 'api' ||
        typeof saved.selectedTab !== 'string' || !Array.isArray(saved.tabs) || !Array.isArray(saved.pins)) return undefined;
    const tabs: PinmonyHomeTab[] = saved.tabs.filter((tab: PinmonyHomeTab): boolean =>
      !!tab && typeof tab.id === 'string' && !!tab.id && typeof tab.label === 'string' && !!tab.label &&
      typeof tab.selected === 'boolean' && typeof tab.enabled === 'boolean');
    if (!tabs.length || !tabs.some((tab: PinmonyHomeTab): boolean => tab.selected && tab.label === saved.selectedTab)) {
      return undefined;
    }
    const pins: PinmonyHomePin[] = saved.pins.filter((pin: PinmonyHomePin): boolean =>
      !!pin && typeof pin.id === 'string' && /^\d+$/.test(pin.id) && typeof pin.pinUrl === 'string' &&
      new RegExp('^https://(?:www\\.)?pinterest\\.com/pin/' + pin.id + '/?(?:[?#]|$)', 'i').test(pin.pinUrl) &&
      typeof pin.imageUrl === 'string' && /^https:\/\//i.test(pin.imageUrl) &&
      Number.isFinite(pin.imageWidth) && pin.imageWidth > 0 && Number.isFinite(pin.imageHeight) && pin.imageHeight > 0)
      .slice(0, 60).map((pin: PinmonyHomePin): PinmonyHomePin => ({
        id: pin.id, pinUrl: pin.pinUrl, imageUrl: pin.imageUrl,
        imageWidth: pin.imageWidth, imageHeight: pin.imageHeight,
        title: typeof pin.title === 'string' ? pin.title.slice(0, 160) : '', hasMore: false
      }));
    const snapshot: PinmonyHomeSnapshot = {
      kind: 'state', session: 0, pageKey: pageKey, selectedTab: saved.selectedTab,
      tabs: tabs, board: normalizeHomeBoard(saved.board), pins: pins, dataSource: saved.dataSource,
      loadingMore: false, refreshing: false, endReached: false
    };
    return { snapshot: snapshot };
  }

export function readHomeCache(cache: ApiCache, accountId: string, pageKey: string, trigger: string): PinmonyHomeSnapshot | undefined {
  try {
    const lookupStartedAt: number = Date.now();
    const result = cache.getWithMetadata<PinmonyHomeCacheRecord>(homeCacheKey(accountId, pageKey), CACHE_TTL.homeFeed);
    PinmonyRuntimeLog.info('HomeCache: lookup trigger=' + trigger + ' status=' + result.status +
      ' ageMs=' + result.ageMs.toString() + ' elapsedMs=' + (Date.now() - lookupStartedAt).toString());
    if (!result.value) {
      if (result.status === 'expired') PinmonyRuntimeLog.info('OfflineCache: expired');
      return undefined;
    }
    const normalized: PinmonyHomeCacheRecord | undefined = normalizeHomeCacheRecord(result.value, pageKey);
    if (!normalized) {
      cache.remove(homeCacheKey(accountId, pageKey));
      PinmonyRuntimeLog.warn('HomeCache: snapshot rejected reason=invalid-shape');
      return undefined;
    }
    PinmonyRuntimeLog.info('HomeCache: snapshot restored source=' + result.status +
      ' pins=' + normalized.snapshot.pins.length.toString() + ' actionsReady=false');
    return normalized.snapshot;
  } catch (_) {
    PinmonyRuntimeLog.warn('HomeCache: disk snapshot read failed');
    return undefined;
  }
}

export function writeHomeCache(cache: ApiCache, accountId: string, snapshot: PinmonyHomeSnapshot, onStored: () => void): void {
  const record: PinmonyHomeCacheRecord | undefined = normalizeHomeCacheRecord({ snapshot: snapshot }, snapshot.pageKey);
  if (!record) return;
  try {
    const writeStartedAt: number = Date.now();
    cache.put(homeCacheKey(accountId, snapshot.pageKey), record, CACHE_TTL.homeFeed);
    onStored();
    PinmonyRuntimeLog.info('HomeCache: snapshot persisted pins=' + record.snapshot.pins.length.toString() +
      ' elapsedMs=' + (Date.now() - writeStartedAt).toString() + ' ttlMs=' + CACHE_TTL.homeFeed.toString());
  } catch (_) { PinmonyRuntimeLog.warn('HomeCache: disk snapshot write failed'); }
}
