import { image } from '@kit.ImageKit';
import { PinmonyImageDownload, PinmonyDownloadedImage, acceptsImageDownloadUrl } from 'common_network';

// Public Pinterest avatar CDN only; never use site cookies or persist avatar bytes.
export class PinmonyInboxNoticeAvatar {
  private readonly download: PinmonyImageDownload = new PinmonyImageDownload();
  cancel(): void { this.download.cancel(); }
  async read(url: string, current: () => boolean): Promise<image.PixelMap | undefined> {
    if(!acceptsImageDownloadUrl(url) || !current())return undefined;
    let source: image.ImageSource | undefined = undefined;
    let pixels: image.PixelMap | undefined = undefined;
    const timer: number = setTimeout((): void => this.download.cancel(), 3000);
    try {
      const reply: PinmonyDownloadedImage = await this.download.read(url,current);
      if(!current() || reply.data.byteLength > 1024 * 1024)return undefined;
      source = image.createImageSource(reply.data);
      const info: image.ImageInfo = await source.getImageInfo();
      if(!current() || info.size.width <= 0 || info.size.height <= 0 || info.size.width * info.size.height > 16000000)return undefined;
      pixels = await source.createPixelMap({desiredSize:{width:128,height:128}});
      if(!current() || pixels.getPixelBytesNumber() > 192 * 1024) { await pixels.release(); return undefined; }
      return pixels;
    } catch (_) { if(pixels)try { await pixels.release(); } catch (_) {} return undefined; }
    finally { clearTimeout(timer); if(source)try { await source.release(); } catch (_) {} }
  }
}
