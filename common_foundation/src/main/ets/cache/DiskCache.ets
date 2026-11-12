import fs from '@ohos.file.fs';
import { hashCacheString } from './CacheKey';
import { parseCacheJson, stringifyCacheJson } from './CacheCodec';

export interface DiskCacheReadResult<T> {
  value: T | null;
  status: 'hit' | 'miss' | 'expired' | 'corrupt';
  ageMs: number;
}

export class DiskCache {
  private readonly directory: string;

  constructor(cacheDir: string) {
    if (!cacheDir) throw new Error('cacheDir is required');
    this.directory = cacheDir.replace(/[\\/]+$/, '') + '/api_cache';
  }

  private ensureDirectory(): void {
    let exists: boolean = false;
    try { exists = fs.accessSync(this.directory); } catch (_) {}
    if (!exists) {
      try { fs.mkdirSync(this.directory, true); }
      catch (_) { throw new Error('cache-directory-unavailable'); }
    }
  }

  get<T>(key: string, maxAgeMs: number): T | null {
    return this.getWithMetadata<T>(key, maxAgeMs).value;
  }

  getWithMetadata<T>(key: string, maxAgeMs: number): DiskCacheReadResult<T> {
    this.ensureDirectory();
    const path: string = this.filePath(key);
    try {
      const stat = fs.statSync(path);
      // HarmonyOS Stat.mtime is Unix time in seconds; runtime ages use milliseconds.
      const modifiedAtMs: number = stat.mtime * 1000;
      const ageMs: number = Math.max(0, Date.now() - modifiedAtMs);
      if (ageMs > maxAgeMs) {
        fs.unlinkSync(path);
        return { value: null, status: 'expired', ageMs: ageMs };
      }
      try {
        return { value: JSON.parse(fs.readTextSync(path)) as T, status: 'hit', ageMs: ageMs };
      } catch (_) {
        this.remove(key);
        return { value: null, status: 'corrupt', ageMs: ageMs };
      }
    } catch (_) {
      return { value: null, status: 'miss', ageMs: -1 };
    }
  }

  put(key: string, data: Object | string | number | boolean | null): void {
    this.ensureDirectory();
    const path: string = this.filePath(key);
    const temporaryPath: string = path + '.tmp';
    let file: fs.File | undefined = undefined;
    let failed: boolean = false;
    try {
      // Commit through a sibling file so interruption cannot expose partial JSON.
      file = fs.openSync(temporaryPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, JSON.stringify(data));
      fs.closeSync(file);
      file = undefined;
      fs.renameSync(temporaryPath, path);
    } catch (_) {
      failed = true;
      throw new Error('cache-write-failed');
    } finally {
      try { if (file) fs.closeSync(file); }
      catch (_) { if (!failed) throw new Error('cache-close-failed'); }
      try { fs.unlinkSync(temporaryPath); } catch (_) {}
    }
  }

  remove(key: string): void {
    try { fs.unlinkSync(this.filePath(key)); } catch (_) {}
  }

  clear(): number {
    let names: string[] = [];
    try { names = fs.listFileSync(this.directory); } catch (_) { return 0; }
    let removed: number = 0;
    names.forEach((name: string): void => {
      try {
        fs.unlinkSync(this.directory + '/' + name);
        removed++;
      } catch (_) {}
    });
    return removed;
  }

  private filePath(key: string): string {
    return this.directory + '/' + hashCacheString(key) + '.json';
  }

  async getWithMetadataAsync<T>(key: string, maxAgeMs: number, current: () => boolean): Promise<DiskCacheReadResult<T>> {
    const path: string = this.filePath(key);
    try {
      const stat: fs.Stat = await fs.stat(path);
      if (stat.size > 2 * 1024 * 1024) {
        if (current()) await fs.unlink(path);
        return { value: null, status: 'corrupt', ageMs: -1 };
      }
      const ageMs: number = Math.max(0, Date.now() - stat.mtime * 1000);
      if (!current()) return { value: null, status: 'miss', ageMs: -1 };
      if (ageMs > maxAgeMs) {
        await fs.unlink(path);
        return { value: null, status: 'expired', ageMs: ageMs };
      }
      const text: string = await fs.readText(path, { length: 2 * 1024 * 1024 });
      if (!current()) return { value: null, status: 'miss', ageMs: -1 };
      try {
        const value: T = await parseCacheJson<T>(text);
        if (!current()) return { value: null, status: 'miss', ageMs: -1 };
        return { value: value, status: 'hit', ageMs: ageMs };
      }
      catch (_) {
        if (current()) await fs.unlink(path);
        return { value: null, status: 'corrupt', ageMs: ageMs };
      }
    } catch (_) { return { value: null, status: 'miss', ageMs: -1 }; }
  }

  async putAsync(key: string, data: Object | string | number | boolean | null, current: () => boolean): Promise<void> {
    const path: string = this.filePath(key), temporaryPath: string = path + '.async.tmp';
    let file: fs.File | undefined = undefined;
    try {
      try { await fs.mkdir(this.directory, true); }
      catch (_) { await fs.stat(this.directory); }
      if (!current()) throw new Error('cache-invalidated');
      const bytes: ArrayBuffer = await stringifyCacheJson(data);
      if (!current()) throw new Error('cache-invalidated');
      file = await fs.open(temporaryPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      const written: number = await fs.write(file.fd, bytes);
      if (written !== bytes.byteLength) throw new Error('cache-short-write');
      await fs.close(file); file = undefined;
      if (!current()) throw new Error('cache-invalidated');
      await fs.rename(temporaryPath, path);
      // Invalidation may have happened while rename was executing.
      if (!current()) { await fs.unlink(path); throw new Error('cache-invalidated'); }
    } finally {
      if (file) try { await fs.close(file); } catch (_) {}
      try { await fs.unlink(temporaryPath); } catch (_) {}
    }
  }

  async removeAsync(key: string): Promise<void> {
    try { await fs.unlink(this.filePath(key)); } catch (_) {}
  }

  async clearAsync(): Promise<number> {
    let names: string[];
    try { names = await fs.listFile(this.directory); } catch (_) { return 0; }
    let removed: number = 0;
    for (const name of names) {
      try { await fs.unlink(this.directory + '/' + name); removed++; } catch (_) {}
    }
    return removed;
  }
}
