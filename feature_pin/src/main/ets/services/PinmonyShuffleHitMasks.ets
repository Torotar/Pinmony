import { image } from '@kit.ImageKit';
import { util } from '@kit.ArkTS';
import { PinmonyImageDownload, PinmonyDownloadedImage } from 'common_network';
import { PinmonyShuffleHitPoint } from './PinmonyShuffleHitTest';
import { PinmonyShuffleItem } from '../models/PinmonyShuffle';
import { PinmonyRuntimeLog } from 'common_foundation';

interface PinmonyShuffleAlphaMask { width: number; height: number; alpha: Uint8Array; }

export class PinmonyShuffleHitMasks {
  private readonly downloads: Map<string,PinmonyImageDownload> = new Map<string,PinmonyImageDownload>();
  private readonly pending: Map<string,Promise<PinmonyShuffleAlphaMask | undefined>> = new Map<string,Promise<PinmonyShuffleAlphaMask | undefined>>();
  private readonly masks: Map<string,PinmonyShuffleAlphaMask> = new Map<string,PinmonyShuffleAlphaMask>();
  cancel(): void { this.downloads.forEach((download: PinmonyImageDownload) => download.cancel()); }
  suspend(): void { this.cancel(); this.pending.clear(); }
  clear(): void { this.suspend(); this.masks.clear(); }
  async opaque(hit: PinmonyShuffleHitPoint, current: () => boolean): Promise<boolean | undefined> {
    const url: string = hit.item.cutoutUrl || hit.item.imageUrl || '';
    const embedded: string = hit.item.hitMask || '';
    const key: string = embedded ? 'mask:' + embedded : url;
    if (!current() || !url) return undefined;
    if (!embedded && /\.jpe?g(?:\?|$)/i.test(url)) return true;
    let mask: PinmonyShuffleAlphaMask | undefined = this.masks.get(key);
    if (!mask) {
      let request: Promise<PinmonyShuffleAlphaMask | undefined> | undefined = this.pending.get(key);
      if (!request) {
        // Two transfers permit a user click alongside one speculative read.
        if (this.pending.size >= 2) {
          await Promise.race(Array.from(this.pending.values()));
          if (!current()) return undefined;
          return this.opaque(hit,current);
        }
        request = this.loadMask(url,current,embedded,key);
        this.pending.set(key,request);
      }
      mask = await request;
      if (this.pending.get(key) === request) this.pending.delete(key);
    }
    if (!current() || !mask) return undefined;
    const px: number = Math.min(mask.width - 1,Math.floor(hit.u * mask.width));
    const py: number = Math.min(mask.height - 1,Math.floor(hit.v * mask.height));
    return mask.alpha[py * mask.width + px] * hit.item.alpha >= 16;
  }
  private async loadMask(url: string, current: () => boolean, embedded: string = '', key: string = url): Promise<PinmonyShuffleAlphaMask | undefined> {
      const download: PinmonyImageDownload = new PinmonyImageDownload();
      this.downloads.set(url,download);
      let phase: string = 'transfer';
      let timedOut: boolean = false;
      let source: image.ImageSource | undefined;
      let pixel: image.PixelMap | undefined;
      const timer: number = setTimeout(() => { if (current()) { timedOut = true; download.cancel(); } },10000);
      try {
        let bytes: ArrayBuffer;
        if (embedded) {
          phase = 'decode';
          const decoded: Uint8Array = new util.Base64Helper().decodeSync(embedded);
          bytes = new ArrayBuffer(decoded.byteLength);
          new Uint8Array(bytes).set(decoded);
        } else {
          const response: PinmonyDownloadedImage = await download.read(url,current);
          bytes = response.data;
        }
        if (!current()) return undefined;
        phase = 'decode';
        source = image.createImageSource(bytes);
        const info: image.ImageInfo = await source.getImageInfo();
        if (info.size.width <= 0 || info.size.height <= 0 || info.size.width > 50000 || info.size.height > 50000) return undefined;
        const factor: number = Math.min(1,256 / Math.max(info.size.width,info.size.height));
        const width: number = Math.max(1,Math.round(info.size.width * factor));
        const height: number = Math.max(1,Math.round(info.size.height * factor));
        pixel = await source.createPixelMap({desiredSize:{width:width,height:height},desiredPixelFormat:image.PixelMapFormat.RGBA_8888});
        const decoded: image.ImageInfo = await pixel.getImageInfo();
        const maskWidth: number = decoded.size.width, maskHeight: number = decoded.size.height;
        if (maskWidth <= 0 || maskHeight <= 0 || maskWidth > 512 || maskHeight > 512) return undefined;
        const pixels: ArrayBuffer = new ArrayBuffer(maskWidth * maskHeight * 4);
        phase = 'pixels';
        await pixel.readPixelsToBuffer(pixels);
        if (!current()) return undefined;
        const rgba: Uint8Array = new Uint8Array(pixels), alpha: Uint8Array = new Uint8Array(maskWidth * maskHeight);
        let luminanceMask: boolean = false;
        if (embedded) {
          for (let index: number = 0; index < rgba.length; index += 4) {
            if (rgba[index] || rgba[index + 1] || rgba[index + 2]) { luminanceMask = true; break; }
          }
        }
        for (let index: number = 0; index < alpha.length; index++) {
          const offset: number = index * 4;
          alpha[index] = luminanceMask ? Math.round((rgba[offset] + rgba[offset + 1] + rgba[offset + 2]) / 3) : rgba[offset + 3];
        }
        const mask: PinmonyShuffleAlphaMask = {width:maskWidth,height:maskHeight,alpha:alpha};
        this.masks.set(key,mask);
        if (this.masks.size > 24) this.masks.delete(Array.from(this.masks.keys())[0]);
        return mask;
      } catch (_) {
        if (current()) PinmonyRuntimeLog.info('ShuffleHitTrace: event=mask-failed phase=' + phase + ' timeout=' + timedOut.toString());
        return undefined;
      }
      finally {
        clearTimeout(timer);
        if (this.downloads.get(url) === download) this.downloads.delete(url);
        try { if (pixel) await pixel.release(); } catch (_) {}
        try { if (source) await source.release(); } catch (_) {}
      }
  }

  async prepare(items: PinmonyShuffleItem[], current: () => boolean): Promise<void> {
    const candidates: PinmonyShuffleItem[] = items.filter((item: PinmonyShuffleItem): boolean =>
      !item.hidden && item.alpha > 0 && !!(item.cutoutUrl || item.imageUrl)).reverse()
      .sort((left: PinmonyShuffleItem, right: PinmonyShuffleItem): number => Number(!!right.hitMask) - Number(!!left.hitMask)).slice(0,24);
    for (const item of candidates) {
      if (!current()) return;
      await this.opaque({item:item,u:0.5,v:0.5},current);
    }
  }

}
