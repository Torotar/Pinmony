import fs from '@ohos.file.fs';
import { hashCacheString } from './CacheKey';

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
}
