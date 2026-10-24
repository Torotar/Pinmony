interface LruCacheEntry<T> {
  value: T;
  createdAt: number;
  ttlMs: number;
  expiresAt: number;
}

export class LruCache<T> {
  private readonly entries: Map<string, LruCacheEntry<T>> = new Map<string, LruCacheEntry<T>>();
  private readonly maxSize: number;
  private readonly ttlMs: number;
  private readonly onEvict: (() => void) | undefined;

  constructor(maxSize: number, ttlMs: number, onEvict?: () => void) {
    if (!Number.isInteger(maxSize) || maxSize < 1) throw new Error('maxSize must be a positive integer');
    if (!Number.isFinite(ttlMs) || ttlMs < 0) throw new Error('ttlMs must be non-negative');
    this.maxSize = maxSize;
    this.ttlMs = ttlMs;
    this.onEvict = onEvict;
  }

  get(key: string, maxAgeMs: number = this.ttlMs): T | null {
    if (!Number.isFinite(maxAgeMs) || maxAgeMs < 0) return null;
    const entry: LruCacheEntry<T> | undefined = this.entries.get(key);
    if (!entry) return null;
    if (entry.expiresAt <= Date.now() || Date.now() - entry.createdAt >= Math.min(entry.ttlMs, maxAgeMs)) {
      this.entries.delete(key);
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
    this.entries.delete(key);
    this.entries.set(key, { value, createdAt, ttlMs, expiresAt: createdAt + ttlMs });
    while (this.entries.size > this.maxSize) {
      const oldest: IteratorResult<[string, LruCacheEntry<T>]> = this.entries.entries().next();
      if (oldest.done) break;
      this.entries.delete(oldest.value[0]);
      if (this.onEvict) this.onEvict();
    }
  }

  clear(): void {
    this.entries.clear();
  }

  remove(key: string): void {
    this.entries.delete(key);
  }
}
