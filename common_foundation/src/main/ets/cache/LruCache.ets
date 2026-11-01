interface LruCacheEntry<T> {
  value: T;
  createdAt: number;
  ttlMs: number;
  expiresAt: number;
  weight: number;
}

export class LruCache<T> {
  private readonly entries: Map<string, LruCacheEntry<T>> = new Map<string, LruCacheEntry<T>>();
  private readonly maxSize: number;
  private readonly ttlMs: number;
  private readonly onEvict: (() => void) | undefined;
  private readonly maxWeight: number;
  private readonly weightOf: ((value: T) => number) | undefined;
  private totalWeight: number = 0;

  constructor(maxSize: number, ttlMs: number, onEvict?: () => void,
    maxWeight: number = Number.MAX_SAFE_INTEGER, weightOf?: (value: T) => number) {
    if (!Number.isInteger(maxSize) || maxSize < 1) throw new Error('maxSize must be a positive integer');
    if (!Number.isFinite(ttlMs) || ttlMs < 0) throw new Error('ttlMs must be non-negative');
    this.maxSize = maxSize;
    this.ttlMs = ttlMs;
    this.onEvict = onEvict;
    if (!Number.isFinite(maxWeight) || maxWeight < 0) throw new Error('invalid-cache-weight');
    this.maxWeight = maxWeight; this.weightOf = weightOf;
  }

  get(key: string, maxAgeMs: number = this.ttlMs): T | null {
    if (!Number.isFinite(maxAgeMs) || maxAgeMs < 0) return null;
    const entry: LruCacheEntry<T> | undefined = this.entries.get(key);
    if (!entry) return null;
    if (entry.expiresAt <= Date.now() || Date.now() - entry.createdAt >= Math.min(entry.ttlMs, maxAgeMs)) {
      this.remove(key);
      return null;
    }
    this.entries.delete(key);
    this.entries.set(key, entry);
    return entry.value;
  }

  put(key: string, value: T, ttlMs: number = this.ttlMs, ageMs: number = 0): void {
    if (!Number.isFinite(ttlMs) || ttlMs < 0) throw new Error('ttlMs must be non-negative');
    if (!Number.isFinite(ageMs) || ageMs < 0) throw new Error('ageMs must be non-negative');
    const now: number = Date.now();
    const createdAt: number = now - ageMs;
    this.remove(key);
    const weight: number = this.weightOf ? this.weightOf(value) : 1;
    if (!Number.isFinite(weight) || weight < 0 || weight > this.maxWeight) return;
    this.entries.set(key, { value, createdAt, ttlMs, expiresAt: createdAt + ttlMs, weight });
    this.totalWeight += weight;
    while (this.entries.size > this.maxSize || this.totalWeight > this.maxWeight) {
      const oldest: IteratorResult<[string, LruCacheEntry<T>]> = this.entries.entries().next();
      if (oldest.done) break;
      this.remove(oldest.value[0]);
      if (this.onEvict) this.onEvict();
    }
  }

  clear(): void {
    this.entries.clear();
    this.totalWeight = 0;
  }

  remove(key: string): void {
    const entry: LruCacheEntry<T> | undefined = this.entries.get(key);
    if (entry) this.totalWeight -= entry.weight;
    this.entries.delete(key);
  }
}
