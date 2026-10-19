import { PinmonyI18n } from 'common_foundation';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { PinmonyRuntimeLog } from 'common_foundation';

export interface PinmonyPublishPhoto { uri: string; data: string; }

export async function pickPublishPhotoUris(maxCount: number = 10): Promise<string[]> {
  try {
  const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
  options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
  options.maxSelectNumber = Math.max(1, Math.min(10, maxCount));
  const result: photoAccessHelper.PhotoSelectResult = await new photoAccessHelper.PhotoViewPicker().select(options);
  return result.photoUris.slice(0, options.maxSelectNumber);
  } catch (_) { throw new Error(PinmonyI18n.message('无法选择照片，请重试')); }
}

export async function readPublishPhoto(uri: string): Promise<PinmonyPublishPhoto> {
  if (!/^file:\/\/media\//.test(uri)) throw new Error('图片地址不可用');
  try {
  const file: fileIo.File = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
  try {
    const size: number = (await fileIo.stat(file.fd)).size;
    if (size < 12 || size > 4 * 1024 * 1024) throw new Error(PinmonyI18n.message('请选择不超过 4 MB 的照片'));
    const bytes: ArrayBuffer = new ArrayBuffer(size);
    let offset: number = 0;
    while (offset < size) {
      const chunk: ArrayBuffer = new ArrayBuffer(size - offset);
      const count: number = await fileIo.read(file.fd, chunk);
      if (count <= 0) throw new Error(PinmonyI18n.message('图片读取未完成'));
      new Uint8Array(bytes).set(new Uint8Array(chunk, 0, count), offset); offset += count;
    }
    const head: Uint8Array = new Uint8Array(bytes);
    const mime: string = head[0] === 0x89 && head[1] === 0x50 && head[2] === 0x4e && head[3] === 0x47 ? 'png' :
      head[0] === 0xff && head[1] === 0xd8 && head[2] === 0xff ? 'jpeg' :
      head[0] === 0x52 && head[1] === 0x49 && head[8] === 0x57 && head[9] === 0x45 ? 'webp' : '';
    if (!mime) throw new Error(PinmonyI18n.message('目前支持 PNG、JPEG 和 WebP 照片'));
    return { uri: uri, data: 'data:image/' + mime + ';base64,' + new util.Base64Helper().encodeToStringSync(head) };
  } finally { await fileIo.close(file); }
  } catch (error) {
    // Preserve size/format/partial-read failures for the native publishing UI.
    PinmonyRuntimeLog.warn('PublishPhoto: read failed');
    throw error as Error;
  }
}

export interface PinmonyProfileAvatarPhoto { data: string; bytes: ArrayBuffer; mime: string; }
export async function readProfileAvatarPhoto(uri: string): Promise<PinmonyProfileAvatarPhoto> {
  const photo: PinmonyPublishPhoto = await readPublishPhoto(uri);
  const comma: number = photo.data.indexOf(',');
  const mime: string = photo.data.slice(5, photo.data.indexOf(';'));
  const decoded: Uint8Array = new util.Base64Helper().decodeSync(photo.data.slice(comma + 1));
  const bytes: ArrayBuffer = new ArrayBuffer(decoded.length);
  new Uint8Array(bytes).set(decoded);
  return { data: photo.data, bytes: bytes, mime: mime };
}
