import { image } from '@kit.ImageKit';
import { PinmonyImageDownload, PinmonyDownloadedImage, acceptsImageDownloadUrl } from './PinmonyImageDownload';
import { Priority } from './PinmonyNativeNetwork';
import { PinmonyRuntimeLog } from 'common_foundation';

const CACHE_BYTES: number = 24 * 1024 * 1024;
const MAX_DECODE_PIXELS: number = 3 * 1024 * 1024;
const MAX_PIPELINE_PAYLOADS: number = 4;
const MAX_CONCURRENT_DECODES: number = 2;

export interface PinmonyJpegLease {
  taskId: number;
  bitmap?: image.PixelMap;
  ready: Promise<image.PixelMap>;
  release: () => void;
  setActive: (active: boolean) => void;
  setPriority?: (priority: number) => void;
}

class PinmonyJpegEntry {
  refs: number = 0;
  bytes: number = 0;
  touched: number = 0;
  bitmap: image.PixelMap | undefined = undefined;
  task: Promise<image.PixelMap> | undefined = undefined;
  transfer: PinmonyImageDownload = new PinmonyImageDownload();
  owners: Map<number, number> = new Map<number, number>();
  id: number = 0;
}

interface PinmonyJpegWaiter {
  source: string;
  entry: PinmonyJpegEntry;
  resolve: () => void;
  reject: (error: Error) => void;
}

/** Only public CDN JPEGs. Never turn an authenticated URL into a native request. */
export function acceptsSoftwareJpeg(source: string): boolean {
  return acceptsImageDownloadUrl(source) && /\.jpe?g(?:\?[^#]*)?$/i.test(source);
}

/** Shared leases keep one transfer/decode per URL; only unreferenced bitmaps are evicted. */
export class PinmonyJpegDecode {
  private static entries: Map<string, PinmonyJpegEntry> = new Map<string, PinmonyJpegEntry>();
  private static downloads: number = 0;
  private static decodes: number = 0;
  private static buffered: number = 0;
  private static downloadQueue: PinmonyJpegWaiter[] = [];
  private static decodeQueue: PinmonyJpegWaiter[] = [];
  private static sequence: number = 0;
  private static clock: number = 0;

  /** Priority 0 is idle prefetch, 1 ordinary content, 2 visible detail content. */
  static acquire(source: string, active: boolean = true, priority: number = 1): PinmonyJpegLease {
    if (!acceptsSoftwareJpeg(source)) throw new Error('jpeg-url');
    let entry: PinmonyJpegEntry | undefined = PinmonyJpegDecode.entries.get(source);
    if (!entry) {
      entry = new PinmonyJpegEntry();
      entry.id = ++PinmonyJpegDecode.sequence;
      PinmonyJpegDecode.entries.set(source, entry);
    }
    const current: PinmonyJpegEntry = entry;
    current.refs++;
    const owner: number = ++PinmonyJpegDecode.sequence;
    let rank: number = priority >= 2 ? 2 : priority === 0 ? 0 : 1;
    current.owners.set(owner, active ? rank : -1);
    current.touched = ++PinmonyJpegDecode.clock;
    if (!current.task) current.task = PinmonyJpegDecode.decode(source, current);
    let released: boolean = false;
    PinmonyJpegDecode.pump();
    if (current.bitmap) PinmonyJpegDecode.trace(current, 'cache-hit', Date.now());
    return { taskId: current.id, bitmap: current.bitmap, ready: current.task,
      setPriority: (priority: number): void => {
        if (released) return;
        rank = priority >= 2 ? 2 : priority === 0 ? 0 : 1;
        if ((current.owners.get(owner) ?? -1) >= 0) current.owners.set(owner, rank);
        PinmonyJpegDecode.pump();
      },
      setActive: (enabled: boolean): void => {
        if (released) return;
        current.owners.set(owner, enabled ? rank : -1);
        PinmonyJpegDecode.pump();
      }, release: (): void => {
      if (released) return;
      released = true;
      current.refs--;
      current.owners.delete(owner);
      current.touched = ++PinmonyJpegDecode.clock;
      if (current.refs === 0 && current.bitmap && PinmonyJpegDecode.entries.get(source) !== current) {
        current.bitmap.release().catch((): void => {});
        current.bitmap = undefined;
      }
      if (current.refs === 0 && !current.bitmap) {
        current.transfer.cancel();
        if (PinmonyJpegDecode.entries.get(source) === current) PinmonyJpegDecode.entries.delete(source);
      }
      PinmonyJpegDecode.trim();
      PinmonyJpegDecode.pump();
    } };
  }

  /** Session reset: displayed owners retain their bitmap only until they unmount. */
  static clear(): void {
    PinmonyJpegDecode.entries.forEach((entry: PinmonyJpegEntry): void => {
      entry.transfer.cancel();
      if (entry.refs === 0 && entry.bitmap) {
        entry.bitmap.release().catch((): void => {});
        entry.bitmap = undefined;
      }
    });
    PinmonyJpegDecode.entries.clear();
    PinmonyJpegDecode.pump();
  }

  static clearUnused(): void {
    PinmonyJpegDecode.entries.forEach((entry: PinmonyJpegEntry, key: string): void => {
      if (entry.refs !== 0) return;
      PinmonyJpegDecode.entries.delete(key);
      entry.transfer.cancel();
      entry.bitmap?.release().catch((): void => {});
      entry.bitmap = undefined;
    });
    PinmonyJpegDecode.pump();
  }

  private static priority(entry: PinmonyJpegEntry): number {
    let result: number = -1;
    entry.owners.forEach((priority: number): void => { result = Math.max(result, priority); });
    return result;
  }

  private static next(queue: PinmonyJpegWaiter[], background: boolean): PinmonyJpegWaiter | undefined {
    let selected: number = -1;
    let priority: number = -1;
    for (let index: number = queue.length - 1; index >= 0; index--) {
      const waiter: PinmonyJpegWaiter = queue[index];
      if (waiter.entry.refs === 0 || PinmonyJpegDecode.entries.get(waiter.source) !== waiter.entry) {
        queue.splice(index, 1); waiter.reject(new Error('jpeg-cancelled')); continue;
      }
    }
    for (let index: number = 0; index < queue.length; index++) {
      // Once bytes are downloaded, drain paused owners at background priority
      // so buffered payloads cannot block a newly visible page indefinitely.
      const raw: number = PinmonyJpegDecode.priority(queue[index].entry);
      const value: number = queue === PinmonyJpegDecode.decodeQueue ? Math.max(0, raw) : raw;
      if (value > priority && (value > 0 || background)) { selected = index; priority = value; }
    }
    return selected < 0 ? undefined : queue.splice(selected, 1)[0];
  }

  private static pump(): void {
    // Decode first. Four total in-flight payloads bound memory; only two may allocate bitmaps.
    while (PinmonyJpegDecode.decodes < MAX_CONCURRENT_DECODES) {
      const next: PinmonyJpegWaiter | undefined = PinmonyJpegDecode.next(PinmonyJpegDecode.decodeQueue,
        PinmonyJpegDecode.decodes === 0);
      if (!next) break;
      PinmonyJpegDecode.buffered--; PinmonyJpegDecode.decodes++; next.resolve();
    }
    while (PinmonyJpegDecode.downloads + PinmonyJpegDecode.buffered + PinmonyJpegDecode.decodes < MAX_PIPELINE_PAYLOADS) {
      const next: PinmonyJpegWaiter | undefined = PinmonyJpegDecode.next(PinmonyJpegDecode.downloadQueue,
        PinmonyJpegDecode.downloads + PinmonyJpegDecode.buffered + PinmonyJpegDecode.decodes === 0);
      if (!next) break;
      PinmonyJpegDecode.downloads++; next.resolve();
    }
    // Prune cancelled waiters even when both resource limits are occupied.
    for (const queue of [PinmonyJpegDecode.downloadQueue, PinmonyJpegDecode.decodeQueue]) {
      for (let index: number = queue.length - 1; index >= 0; index--) {
        const waiter: PinmonyJpegWaiter = queue[index];
        if (waiter.entry.refs === 0 || PinmonyJpegDecode.entries.get(waiter.source) !== waiter.entry) {
          queue.splice(index, 1); waiter.reject(new Error('jpeg-cancelled'));
        }
      }
    }
  }

  private static wait(source: string, entry: PinmonyJpegEntry, decode: boolean): Promise<void> {
    return new Promise<void>((resolve: () => void, reject: (error: Error) => void): void => {
      const waiter: PinmonyJpegWaiter = { source: source, entry: entry, resolve: resolve, reject: reject };
      (decode ? PinmonyJpegDecode.decodeQueue : PinmonyJpegDecode.downloadQueue).push(waiter);
      PinmonyJpegDecode.pump();
    });
  }

  private static trace(entry: PinmonyJpegEntry, phase: string, started: number): void {
    PinmonyRuntimeLog.info('ImagePipelineTrace: task=' + entry.id.toString() + ' phase=' + phase +
      ' priority=' + PinmonyJpegDecode.priority(entry).toString() + ' elapsedMs=' + Math.max(0, Date.now() - started).toString());
  }

  private static trim(): void {
    let bytes: number = 0;
    PinmonyJpegDecode.entries.forEach((entry: PinmonyJpegEntry): void => { bytes += entry.bytes; });
    const idle: string[] = [];
    PinmonyJpegDecode.entries.forEach((entry: PinmonyJpegEntry, key: string): void => {
      if (entry.refs === 0 && entry.bitmap) idle.push(key);
    });
    idle.sort((a: string, b: string): number =>
      (PinmonyJpegDecode.entries.get(a)?.touched || 0) - (PinmonyJpegDecode.entries.get(b)?.touched || 0));
    for (const key of idle) {
      if (bytes <= CACHE_BYTES && PinmonyJpegDecode.entries.size <= 48) break;
      const entry: PinmonyJpegEntry | undefined = PinmonyJpegDecode.entries.get(key);
      if (!entry || entry.refs !== 0) continue;
      PinmonyJpegDecode.entries.delete(key);
      bytes -= entry.bytes;
      entry.bitmap?.release().catch((): void => {});
    }
  }

  private static async decode(source: string, entry: PinmonyJpegEntry): Promise<image.PixelMap> {
    let downloading: boolean = false;
    let decoding: boolean = false;
    let buffered: boolean = false;
    let decoder: image.ImageSource | undefined = undefined;
    const live = (): boolean => entry.refs > 0 && PinmonyJpegDecode.entries.get(source) === entry;
    try {
      const queuedAt: number = Date.now();
      while (!downloading) {
        await PinmonyJpegDecode.wait(source, entry, false);
        downloading = true;
        if (live() && PinmonyJpegDecode.priority(entry) < 0) {
          // Page covering can occur between slot reservation and this continuation.
          PinmonyJpegDecode.downloads--; downloading = false; PinmonyJpegDecode.pump();
        }
      }
      PinmonyJpegDecode.trace(entry, 'download-queue', queuedAt);
      if (!live()) throw new Error('jpeg-cancelled');
      const transferAt: number = Date.now();
      const priority: number = PinmonyJpegDecode.priority(entry);
      const downloaded: PinmonyDownloadedImage = await entry.transfer.read(source, live,
        priority >= 2 ? Priority.HIGH : priority === 0 ? Priority.LOW : Priority.NORMAL);
      PinmonyJpegDecode.trace(entry, 'download', transferAt);
      if (!live() || downloaded.extension !== 'jpg') throw new Error('jpeg-format');
      PinmonyJpegDecode.downloads--; downloading = false;
      PinmonyJpegDecode.buffered++; buffered = true;
      const decodeQueuedAt: number = Date.now();
      await PinmonyJpegDecode.wait(source, entry, true);
      buffered = false; decoding = true;
      PinmonyJpegDecode.trace(entry, 'decode-queue', decodeQueuedAt);
      const decodeAt: number = Date.now();
      if (!live()) throw new Error('jpeg-cancelled');
      decoder = image.createImageSource(downloaded.data);
      const info: image.ImageInfo = await decoder.getImageInfo();
      const width: number = info.size.width;
      const height: number = info.size.height;
      if (!live() || width <= 0 || height <= 0 || width * height > MAX_DECODE_PIXELS) {
        throw new Error('jpeg-size');
      }
      const bitmap: image.PixelMap = await decoder.createPixelMapUsingAllocator(
        { desiredDynamicRange: image.DecodingDynamicRange.SDR }, image.AllocatorType.SHARE_MEMORY);
      if (!live()) { await bitmap.release(); throw new Error('jpeg-cancelled'); }
      entry.bitmap = bitmap;
      entry.bytes = bitmap.getPixelBytesNumber();
      PinmonyJpegDecode.trace(entry, 'decode', decodeAt);
      PinmonyJpegDecode.trim();
      return bitmap;
    } catch (_) {
      if (PinmonyJpegDecode.entries.get(source) === entry) PinmonyJpegDecode.entries.delete(source);
      throw new Error('jpeg-decode-unavailable');
    } finally {
      try { await decoder?.release(); } catch (_) {}
      if (downloading) PinmonyJpegDecode.downloads--;
      if (decoding) PinmonyJpegDecode.decodes--;
      if (buffered) PinmonyJpegDecode.buffered--;
      PinmonyJpegDecode.pump();
    }
  }
}
