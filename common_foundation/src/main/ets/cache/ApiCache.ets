import { LruCache } from './LruCache';
import { DiskCache, DiskCacheReadResult } from './DiskCache';
import { PinmonyRuntimeLog } from '../services/PinmonyRuntimeLog';

export interface ApiCacheReadResult<T> {
  value: T | null;
  status: 'memory' | 'disk' | 'miss' | 'expired' | 'corrupt';
  ageMs: number;
}

interface CacheTtlMap {
  homeFeed: number;
  search: number;
  boardAndPinDetail: number;
  userProfile: number;
  detailPrefetch: number;
}

export const CACHE_TTL: CacheTtlMap = {
  homeFeed: 5 * 60 * 1000,
  search: 10 * 60 * 1000,
  boardAndPinDetail: 30 * 60 * 1000,
  userProfile: 60 * 60 * 1000,
  detailPrefetch: 120 * 1000
};

export class ApiCache {
  private readonly memory: LruCache<Object | string | number | boolean | null>;
  private readonly inFlight: Map<string, Promise<Object | string | number | boolean>> =
    new Map<string, Promise<Object | string | number | boolean>>();

  constructor(cacheDir: string, maxSize: number = 128) {
    this.memory = new LruCache<Object | string | number | boolean | null>(maxSize, CACHE_TTL.userProfile,
      (): void => PinmonyRuntimeLog.info('CacheAudit: memory lru eviction'));
    this.disk = new DiskCache(cacheDir);
  }

  private readonly disk: DiskCache;

  get<T extends Object | string | number | boolean>(key: string, maxAgeMs: number): T | null {
    return this.getWithMetadata<T>(key, maxAgeMs).value;
  }

  getWithMetadata<T extends Object | string | number | boolean>(key: string,
    maxAgeMs: number): ApiCacheReadResult<T> {
    const memoryValue: Object | string | number | boolean | null = this.memory.get(key, maxAgeMs);
    if (memoryValue !== null) return { value: memoryValue as T, status: 'memory', ageMs: -1 };
    const diskResult: DiskCacheReadResult<T> = this.disk.getWithMetadata<T>(key, maxAgeMs);
    if (diskResult.value !== null) {
      this.memory.put(key, diskResult.value, maxAgeMs, diskResult.ageMs);
      return { value: diskResult.value, status: 'disk', ageMs: diskResult.ageMs };
    }
    const status: 'miss' | 'expired' | 'corrupt' = diskResult.status === 'hit' ? 'miss' : diskResult.status;
    return { value: null, status: status, ageMs: diskResult.ageMs };
  }

  put<T extends Object | string | number | boolean>(key: string, value: T, ttlMs: number): void {
    // An explicit confirmed value supersedes older reads for this key.
    this.inFlight.delete(key);
    this.store(key, value, ttlMs);
  }

  async readThrough<T extends Object | string | number | boolean>(key: string, ttlMs: number,
    fetcher: () => Promise<T>, onValue?: (value: T, source: string) => void): Promise<T> {
    const memoryValue: Object | string | number | boolean | null = this.memory.get(key, ttlMs);
    if (memoryValue !== null) {
      const value: T = memoryValue as T;
      this.refreshInBackground(key, ttlMs, fetcher, onValue);
      if (onValue) onValue(value, 'memory');
      return value;
    }

    const existing: Promise<Object | string | number | boolean> | undefined = this.inFlight.get(key);
    if (existing) return await existing as T;
    const diskResult: DiskCacheReadResult<T> = this.disk.getWithMetadata<T>(key, ttlMs);
    const diskValue: T | null = diskResult.value;
    if (diskValue !== null) {
      this.memory.put(key, diskValue, ttlMs, diskResult.ageMs);
      this.refreshInBackground(key, ttlMs, fetcher, onValue);
      if (onValue) onValue(diskValue, 'disk');
      return diskValue;
    }

    const request: Promise<T> = Promise.resolve().then((): Promise<T> => {
      // Invalidation can happen before the deferred fetch is dispatched.
      if (this.inFlight.get(key) !== tracked) throw new Error('cache-invalidated');
      return fetcher();
    });
    const tracked: Promise<Object | string | number | boolean> = request.then((value: T): T => {
      if (this.inFlight.get(key) !== tracked) throw new Error('cache-invalidated');
      this.store(key, value, ttlMs);
      if (onValue) onValue(value, 'network');
      return value;
    });
    this.inFlight.set(key, tracked);
    try {
      return await tracked as T;
    } finally {
      // A replacement read may already own the same key.
      if (this.inFlight.get(key) === tracked) this.inFlight.delete(key);
    }
  }

  remove(key: string): void {
    this.inFlight.delete(key);
    this.memory.remove(key);
    this.disk.remove(key);
  }

  clear(): number {
    this.inFlight.clear();
    this.memory.clear();
    return this.disk.clear();
  }

  trimMemory(): void { this.memory.clear(); }

  private refreshInBackground<T extends Object | string | number | boolean>(key: string, ttlMs: number,
    fetcher: () => Promise<T>, onValue?: (value: T, source: string) => void): void {
    const pending: Promise<Object | string | number | boolean> | undefined = this.inFlight.get(key);
    if (pending) return;
    const request: Promise<T> = Promise.resolve().then((): Promise<T> => {
      if (this.inFlight.get(key) !== tracked) throw new Error('cache-invalidated');
      return fetcher();
    });
    const tracked: Promise<Object | string | number | boolean> = request.then((value: T): T => {
      if (this.inFlight.get(key) !== tracked) throw new Error('cache-invalidated');
      this.store(key, value, ttlMs);
      if (onValue) onValue(value, 'network');
      return value;
    });
    this.inFlight.set(key, tracked);
    tracked.catch((): void => {}).finally((): void => {
      if (this.inFlight.get(key) === tracked) this.inFlight.delete(key);
    });
  }

  private store<T extends Object | string | number | boolean>(key: string, value: T, ttlMs: number): void {
    this.memory.put(key, value, ttlMs);
    const writeStartedAt: number = Date.now();
    this.disk.put(key, value);
    PinmonyRuntimeLog.info('CacheAudit: disk write committed elapsedMs=' +
      (Date.now() - writeStartedAt).toString() + ' ttlMs=' + ttlMs.toString());
  }
}
