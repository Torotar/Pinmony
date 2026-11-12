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
  private diskQueue: Promise<void> = Promise.resolve();
  private epoch: number = 0;
  private readonly versions: Map<string, number> = new Map<string, number>();

  private invalidateKey(key: string): void { this.versions.set(key, (this.versions.get(key) || 0) + 1); }
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
    this.invalidateKey(key);
    // An explicit confirmed value supersedes older reads for this key.
    this.inFlight.delete(key);
    this.store(key, value, ttlMs);
  }

  async readThrough<T extends Object | string | number | boolean>(key: string, ttlMs: number,
    fetcher: () => Promise<T>, onValue?: (value: T, source: string) => void): Promise<T> {
    const memoryValue: Object | string | number | boolean | null = this.memory.get(key, ttlMs);
    if (memoryValue !== null) {
      this.refreshInBackground(key, ttlMs, fetcher, onValue);
      if (onValue) onValue(memoryValue as T, 'memory');
      return memoryValue as T;
    }
    const existing: Promise<Object | string | number | boolean> | undefined = this.inFlight.get(key);
    if (existing) return await existing as T;
    const epoch: number = this.epoch, version: number = this.versions.get(key) || 0;
    const current = (): boolean => epoch === this.epoch && version === (this.versions.get(key) || 0) && this.inFlight.get(key) === tracked;
    let diskHit: boolean = false;
    const tracked: Promise<Object | string | number | boolean> = Promise.resolve().then(async (): Promise<T> => {
      if (!current()) throw new Error('cache-invalidated');
      const disk: ApiCacheReadResult<T> = await this.getWithMetadataAsync<T>(key, ttlMs);
      if (!current()) throw new Error('cache-invalidated');
      if (disk.value !== null) {
        diskHit = true;
        if (onValue) onValue(disk.value, disk.status);
        return disk.value;
      }
      const value: T = await fetcher();
      if (!current()) throw new Error('cache-invalidated');
      await this.storeAsync(key, value, ttlMs, current);
      if (!current()) throw new Error('cache-invalidated');
      if (onValue) onValue(value, 'network');
      return value;
    });
    this.inFlight.set(key, tracked);
    try { return await tracked as T; }
    finally {
      if (this.inFlight.get(key) === tracked) {
        this.inFlight.delete(key);
        if (diskHit) this.refreshInBackground(key, ttlMs, fetcher, onValue);
      }
    }
  }

  remove(key: string): void {
    this.invalidateKey(key);
    this.inFlight.delete(key);
    this.memory.remove(key);
    this.disk.remove(key);
  }

  clear(): number {
    this.epoch++; this.versions.clear();
    this.inFlight.clear();
    this.memory.clear();
    return this.disk.clear();
  }

  trimMemory(): void { this.memory.clear(); }

  async getWithMetadataAsync<T extends Object | string | number | boolean>(key: string,
    maxAgeMs: number): Promise<ApiCacheReadResult<T>> {
    const cached: Object | string | number | boolean | null = this.memory.get(key, maxAgeMs);
    if (cached !== null) return { value: cached as T, status: 'memory', ageMs: -1 };
    const epoch: number = this.epoch, version: number = this.versions.get(key) || 0;
    const current = (): boolean => epoch === this.epoch && version === (this.versions.get(key) || 0);
    const operation: Promise<ApiCacheReadResult<T>> = this.diskQueue.then(async (): Promise<ApiCacheReadResult<T>> => {
      if (!current()) return { value: null, status: 'miss', ageMs: -1 };
      const warm: Object | string | number | boolean | null = this.memory.get(key, maxAgeMs);
      if (warm !== null) return { value: warm as T, status: 'memory', ageMs: -1 };
      const result: DiskCacheReadResult<T> = await this.disk.getWithMetadataAsync<T>(key, maxAgeMs, current);
      if (!current()) return { value: null, status: 'miss', ageMs: -1 };
      if (result.value !== null) this.memory.put(key, result.value, maxAgeMs, result.ageMs);
      return { value: result.value, status: result.status === 'hit' ? 'disk' : result.status, ageMs: result.ageMs };
    });
    this.diskQueue = operation.then((): void => {}, (): void => {});
    return operation;
  }

  async putAsync<T extends Object | string | number | boolean>(key: string, value: T, ttlMs: number,
    owner: () => boolean = (): boolean => true): Promise<void> {
    if (!owner()) throw new Error('cache-invalidated');
    this.invalidateKey(key); this.inFlight.delete(key); this.memory.put(key, value, ttlMs);
    const epoch: number = this.epoch, version: number = this.versions.get(key) || 0;
    const current = (): boolean => epoch === this.epoch && version === (this.versions.get(key) || 0) && owner();
    const operation: Promise<void> = this.diskQueue.then(async (): Promise<void> => {
      if (!current()) throw new Error('cache-invalidated');
      await this.disk.putAsync(key, value, current);
      if (!current()) throw new Error('cache-invalidated');
    });
    this.diskQueue = operation.catch((): void => {});
    return operation;
  }

  removeAsync(key: string): Promise<void> {
    this.invalidateKey(key); this.inFlight.delete(key); this.memory.remove(key);
    const operation: Promise<void> = this.diskQueue.then((): Promise<void> => this.disk.removeAsync(key));
    this.diskQueue = operation.catch((): void => {});
    return operation;
  }

  clearAsync(): Promise<number> {
    this.epoch++; this.versions.clear(); this.inFlight.clear(); this.memory.clear();
    const operation: Promise<number> = this.diskQueue.then((): Promise<number> => this.disk.clearAsync());
    this.diskQueue = operation.then((): void => {}, (): void => {});
    return operation;
  }

  private refreshInBackground<T extends Object | string | number | boolean>(key: string, ttlMs: number,
    fetcher: () => Promise<T>, onValue?: (value: T, source: string) => void): void {
    const pending: Promise<Object | string | number | boolean> | undefined = this.inFlight.get(key);
    if (pending) return;
    const request: Promise<T> = Promise.resolve().then((): Promise<T> => {
      if (this.inFlight.get(key) !== tracked) throw new Error('cache-invalidated');
      return fetcher();
    });
    const tracked: Promise<Object | string | number | boolean> = request.then(async (value: T): Promise<T> => {
      if (this.inFlight.get(key) !== tracked) throw new Error('cache-invalidated');
      const current = (): boolean => this.inFlight.get(key) === tracked;
      await this.storeAsync(key, value, ttlMs, current);
      if (!current()) throw new Error('cache-invalidated');
      if (onValue) onValue(value, 'network');
      return value;
    });
    this.inFlight.set(key, tracked);
    tracked.catch((): void => {}).finally((): void => {
      if (this.inFlight.get(key) === tracked) this.inFlight.delete(key);
    });
  }

  private async storeAsync<T extends Object | string | number | boolean>(key: string, value: T, ttlMs: number,
    owner: () => boolean): Promise<void> {
    if (!owner()) throw new Error('cache-invalidated');
    this.memory.put(key, value, ttlMs);
    const epoch: number = this.epoch, version: number = this.versions.get(key) || 0;
    const current = (): boolean => owner() && epoch === this.epoch && version === (this.versions.get(key) || 0);
    const operation: Promise<void> = this.diskQueue.then(async (): Promise<void> => {
      if (!current()) throw new Error('cache-invalidated');
      await this.disk.putAsync(key, value, current);
    });
    this.diskQueue = operation.catch((): void => {});
    await operation;
  }

  private store<T extends Object | string | number | boolean>(key: string, value: T, ttlMs: number): void {
    this.memory.put(key, value, ttlMs);
    const writeStartedAt: number = Date.now();
    this.disk.put(key, value);
    PinmonyRuntimeLog.info('CacheAudit: disk write committed elapsedMs=' +
      (Date.now() - writeStartedAt).toString() + ' ttlMs=' + ttlMs.toString());
  }
}
