import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { picker, fileUri, fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';
import { PinWebRuntimeLog } from 'common_foundation';

export class PinWebSystemActions {
  private readonly downloadDelegate: webview.WebDownloadDelegate = new webview.WebDownloadDelegate();
  private active: boolean = true;
  private generation: number = 0;
  private readonly selectingDownloads: Map<string, webview.WebDownloadItem> = new Map<string, webview.WebDownloadItem>();
  private readonly cancelledDownloads: Set<string> = new Set<string>();
  private readonly context: () => common.UIAbilityContext;
  private readonly showMessage: (message: string) => void;
  constructor(context: () => common.UIAbilityContext, showMessage: (message: string) => void) {
    this.context = context;
    this.showMessage = showMessage;
  }

  activate(): void { this.active = true; }

  dispose(): void {
    this.active = false; this.generation++;
    this.selectingDownloads.forEach((item: webview.WebDownloadItem): void => {
      try { this.cancelDownload(item); } catch (_) { PinWebRuntimeLog.warn('PhotoDownload: cancellation unavailable'); }
    });
    this.selectingDownloads.clear();
  }

  copyText(value: string): Promise<void> {
    return pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, value));
  }

  openLink(url: string): Promise<void> { return this.context().openLink(url); }

  exportRuntimeLog(): Promise<boolean> { return PinWebRuntimeLog.export(this.context()); }

  async pickImage(): Promise<string> {
    const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    const selected: photoAccessHelper.PhotoSelectResult = await new photoAccessHelper.PhotoViewPicker().select(options);
    return selected.photoUris[0] || '';
  }

  async readJpeg(uri: string): Promise<ArrayBuffer> {
    const file: fileIo.File = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
    try {
      const source: image.ImageSource = image.createImageSource(file.fd);
      try {
        const packer: image.ImagePacker = image.createImagePacker();
        try { return await packer.packToData(source, { format: 'image/jpeg', quality: 90 }); }
        finally { await packer.release(); }
      } finally { await source.release(); }
    } finally { await fileIo.close(file); }
  }

  private cancelDownload(item: webview.WebDownloadItem): void {
    this.cancelledDownloads.add(item.getGuid());
    item.cancel();
  }

  private async chooseDownloadPath(item: webview.WebDownloadItem): Promise<void> {
    const generation: number = this.generation;
    this.selectingDownloads.set(item.getGuid(), item);
    PinWebRuntimeLog.info('PhotoDownload: destination-requested');
    try {
      const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      options.pickerMode = picker.DocumentPickerMode.DOWNLOAD;
      const selected: string[] = await new picker.DocumentViewPicker().save(options);
      if (!this.active || generation !== this.generation) return;
      if (selected.length === 0 || !selected[0]) {
        this.cancelDownload(item);
        return;
      }
      const directory: string = new fileUri.FileUri(selected[0]).path;
      if (!directory) {
        this.cancelDownload(item);
        this.showMessage('无法访问下载目录');
        return;
      }
      let name: string = item.getSuggestedFileName().replace(/[\\/\x00-\x1f:*?"<>|]/g, '_');
      if (!name || name === '.' || name === '..') {
        name = 'pinterest-image';
      }
      item.start(directory + '/pin-' + Date.now().toString() + '-' + name);
      PinWebRuntimeLog.info('PhotoDownload: file-started');
      this.showMessage('正在下载到所选目录');
    } catch (error) {
      if (!this.active || generation !== this.generation) return;
      PinWebRuntimeLog.error('PinWeb: download setup failed');
      try {
        this.cancelDownload(item);
      } catch (cancelError) {
        PinWebRuntimeLog.error('PinWeb: download cancellation failed');
      }
      this.showMessage('无法开始下载');
    } finally { this.selectingDownloads.delete(item.getGuid()); }
  }

  installDownloadDelegate(controller: webview.WebviewController): void {
    this.downloadDelegate.onBeforeDownload((item: webview.WebDownloadItem) => {
      if (!this.active) { this.cancelDownload(item); return; }
      this.chooseDownloadPath(item);
    });
    this.downloadDelegate.onDownloadFinish((_item: webview.WebDownloadItem) => {
      PinWebRuntimeLog.info('PhotoDownload: completed');
      if (this.active) this.showMessage('下载完成，请在所选目录查看');
    });
    this.downloadDelegate.onDownloadFailed((item: webview.WebDownloadItem) => {
      if (this.cancelledDownloads.delete(item.getGuid())) {
        PinWebRuntimeLog.info('PhotoDownload: cancelled');
        return;
      }
      PinWebRuntimeLog.error('PinWeb: download failed, code ' + item.getLastErrorCode());
      PinWebRuntimeLog.warn('PhotoDownload: failed reason=delegate-error');
      if (this.active) this.showMessage('下载失败，请重试');
    });
    try {
      controller.setDownloadDelegate(this.downloadDelegate);
    } catch (error) {
      PinWebRuntimeLog.error('PinWeb: download delegate unavailable');
    }
  }
}
