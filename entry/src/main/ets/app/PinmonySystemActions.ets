import { PinmonyI18n } from 'common_foundation';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { picker, fileUri, fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';
import { PinmonyRuntimeLog } from 'common_foundation';

import { PinmonyImageDownload, PinmonyDownloadedImage, acceptsImageDownloadUrl } from 'common_network';

export class PinmonySystemActions {
  private readonly imageDownload: PinmonyImageDownload = new PinmonyImageDownload();
  private imageDownloadBusy: boolean = false;private imageDownloadSequence: number = 0;
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
    this.active = false; this.generation++;this.imageDownload.cancel();this.imageDownloadBusy = false;
    this.selectingDownloads.forEach((item: webview.WebDownloadItem): void => {
      try { this.cancelDownload(item); } catch (_) { PinmonyRuntimeLog.warn('PhotoDownload: cancellation unavailable'); }
    });
    this.selectingDownloads.clear();
  }

  async shareLink(url: string, title: string): Promise<void> {
    try {
    const data: systemShare.SharedData = new systemShare.SharedData({
      utd: utd.UniformDataType.HYPERLINK, content: url, title: title
    });
    const controller: systemShare.ShareController = new systemShare.ShareController(data);
    await controller.show(this.context(), {
      selectionMode: systemShare.SelectionMode.SINGLE,
      previewMode: systemShare.SharePreviewMode.DEFAULT
    });
    } catch (_) { throw new Error(PinmonyI18n.message("pm_unable_to_open_share_panel_43eea06a")); }
  }

  async copyText(value: string): Promise<void> {
    try { await pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, value)); }
    catch (_) { throw new Error(PinmonyI18n.message("pm_unable_to_copy_link_please_retry_d1b1765b")); }
  }

  async openLink(url: string): Promise<void> {
    try { await this.context().openLink(url); }
    catch (_) { throw new Error(PinmonyI18n.message("pm_unable_to_open_link_please_retry_99322633")); }
  }

  exportRuntimeLog(): Promise<boolean> { return PinmonyRuntimeLog.export(this.context()); }

  async pickImage(): Promise<string> {
    try {
    const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    const selected: photoAccessHelper.PhotoSelectResult = await new photoAccessHelper.PhotoViewPicker().select(options);
    return selected.photoUris[0] || '';
    } catch (_) { throw new Error(PinmonyI18n.message("pm_unable_to_choose_photo_please_retry_50d94255")); }
  }

  async readJpeg(uri: string): Promise<ArrayBuffer> {
    try {
    const file: fileIo.File = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
    try {
      const source: image.ImageSource = image.createImageSource(file.fd);
      try {
        const packer: image.ImagePacker = image.createImagePacker();
        try { return await packer.packToData(source, { format: 'image/jpeg', quality: 90 }); }
        finally { await packer.release(); }
      } finally { await source.release(); }
    } finally { await fileIo.close(file); }
    } catch (_) { throw new Error(PinmonyI18n.message("pm_unable_to_read_photo_please_retry_b7f672b3")); }
  }

  async downloadImage(source: string): Promise<void> {
    if(!this.active || this.imageDownloadBusy || !acceptsImageDownloadUrl(source))return;
    this.imageDownloadBusy = true;const generation: number = this.generation;let output: string = '';
    try {
      const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();options.pickerMode = picker.DocumentPickerMode.DOWNLOAD;
      const selected: string[] = await new picker.DocumentViewPicker().save(options);
      if(!this.active || generation !== this.generation || !selected[0])return;
      const directory: string = new fileUri.FileUri(selected[0]).path;if(!directory)throw new Error('directory');
      this.showMessage(PinmonyI18n.message("pm_downloading_to_the_selected_folder_7f7c1d0f"));
      const result: PinmonyDownloadedImage = await this.imageDownload.read(source,(): boolean => this.active && generation === this.generation);
      if(!this.active || generation !== this.generation)return;
      output = directory + '/pin-' + Date.now().toString() + '-' + (++this.imageDownloadSequence).toString() + '.' + result.extension;
      const file: fileIo.File = await fileIo.open(output,fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try {let offset: number = 0;while(offset < result.data.byteLength){const written: number = await fileIo.write(file.fd,result.data.slice(offset));if(written <= 0)throw new Error('write');offset += written;}}
      finally {await fileIo.close(file);}
      if(this.active && generation === this.generation)this.showMessage(PinmonyI18n.message("pm_download_complete_check_the_selected_folder_bac45b27"));
    }catch (_) {if(output){try {await fileIo.unlink(output);}catch (_) {}}if(this.active && generation === this.generation)this.showMessage(PinmonyI18n.message("pm_download_failed_please_retry_45f5dfb2"));}
    finally {if(generation === this.generation)this.imageDownloadBusy = false;}
  }

  private cancelDownload(item: webview.WebDownloadItem): void {
    this.cancelledDownloads.add(item.getGuid());
    item.cancel();
  }

  private async chooseDownloadPath(item: webview.WebDownloadItem): Promise<void> {
    const generation: number = this.generation;
    this.selectingDownloads.set(item.getGuid(), item);
    PinmonyRuntimeLog.info('PhotoDownload: destination-requested');
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
        this.showMessage(PinmonyI18n.message("pm_unable_to_access_download_folder_32830afc"));
        return;
      }
      let name: string = item.getSuggestedFileName().replace(/[\\/\x00-\x1f:*?"<>|]/g, '_');
      if (!name || name === '.' || name === '..') {
        name = 'pinterest-image';
      }
      item.start(directory + '/pin-' + Date.now().toString() + '-' + name);
      PinmonyRuntimeLog.info('PhotoDownload: file-started');
      this.showMessage(PinmonyI18n.message("pm_downloading_to_the_selected_folder_7f7c1d0f"));
    } catch (error) {
      if (!this.active || generation !== this.generation) return;
      PinmonyRuntimeLog.error('Pinmony: download setup failed');
      try {
        this.cancelDownload(item);
      } catch (cancelError) {
        PinmonyRuntimeLog.error('Pinmony: download cancellation failed');
      }
      this.showMessage(PinmonyI18n.message("pm_unable_to_start_download_7e24b28f"));
    } finally { this.selectingDownloads.delete(item.getGuid()); }
  }

  installDownloadDelegate(controller: webview.WebviewController): void {
    this.downloadDelegate.onBeforeDownload((item: webview.WebDownloadItem) => {
      if (!this.active) { this.cancelDownload(item); return; }
      this.chooseDownloadPath(item);
    });
    this.downloadDelegate.onDownloadFinish((_item: webview.WebDownloadItem) => {
      PinmonyRuntimeLog.info('PhotoDownload: completed');
      if (this.active) this.showMessage(PinmonyI18n.message("pm_download_complete_check_the_selected_folder_bac45b27"));
    });
    this.downloadDelegate.onDownloadFailed((item: webview.WebDownloadItem) => {
      if (this.cancelledDownloads.delete(item.getGuid())) {
        PinmonyRuntimeLog.info('PhotoDownload: cancelled');
        return;
      }
      PinmonyRuntimeLog.error('Pinmony: download failed, code ' + item.getLastErrorCode());
      PinmonyRuntimeLog.warn('PhotoDownload: failed reason=delegate-error');
      if (this.active) this.showMessage(PinmonyI18n.message("pm_download_failed_please_retry_45f5dfb2"));
    });
    try {
      controller.setDownloadDelegate(this.downloadDelegate);
    } catch (error) {
      PinmonyRuntimeLog.error('Pinmony: download delegate unavailable');
    }
  }
}
