import { PinmonyI18n } from 'common_foundation';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { picker, fileUri, fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { pasteboard, BusinessError } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';
import { PinmonyRuntimeLog } from 'common_foundation';

import { PinmonyImageDownload, PinmonyDownloadedImage, acceptsImageDownloadUrl, PinmonyMediaFile, PinmonyMediaFileLease, acceptsMediaFileUrl } from 'common_network';

export class PinmonyMediaSharePreparationError extends Error {}

interface PinmonySharedImageFile {
  path: string;
  type: string;
  bytes: number;
  createdAt: number;
}

export class PinmonySystemActions {
  private readonly imageDownload: PinmonyImageDownload = new PinmonyImageDownload();
  private readonly shareImageDownload: PinmonyImageDownload = new PinmonyImageDownload();
  private shareVideoDownload: PinmonyMediaFile | undefined = undefined;
  private imageShareBusy: boolean = false;
  private imageShareSequence: number = 0;
  private readonly sharedImageFiles: Map<string, PinmonySharedImageFile> = new Map<string, PinmonySharedImageFile>();
  private sharedImageScope: string = '';
  private readonly imageShareControllers: Map<systemShare.ShareController, () => void> = new Map<systemShare.ShareController, () => void>();
  private imageDownloadBusy: boolean = false;private imageDownloadSequence: number = 0;
  private readonly downloadDelegate: webview.WebDownloadDelegate = new webview.WebDownloadDelegate();
  private active: boolean = true;
  private generation: number = 0;
  private readonly selectingDownloads: Map<string, webview.WebDownloadItem> = new Map<string, webview.WebDownloadItem>();
  private readonly cancelledDownloads: Set<string> = new Set<string>();
  private readonly context: () => common.UIAbilityContext;
  private readonly showMessage: (message: string) => void;
  private readonly showShareLoading: (() => (() => void)) | undefined;
  private dismissShareLoading: (() => void) | undefined = undefined;
  constructor(context: () => common.UIAbilityContext, showMessage: (message: string) => void,
    showShareLoading?: () => (() => void)) {
    this.context = context;
    this.showMessage = showMessage;
    this.showShareLoading = showShareLoading;
  }

  activate(): void { this.active = true; }

  dispose(): void {
    this.dismissShareLoading?.(); this.dismissShareLoading = undefined;
    this.active = false; this.generation++;this.imageDownload.cancel();this.imageDownloadBusy = false;
    this.shareImageDownload.cancel(); this.imageShareBusy = false;
    this.shareVideoDownload?.cancel();
    this.sharedImageFiles.clear();
    this.imageShareControllers.forEach((dismiss: () => void, controller: systemShare.ShareController): void => {
      try { controller.off('dismiss', dismiss); controller.off('shareCompleted'); } catch (_) {}
    });
    this.imageShareControllers.clear();
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

  async shareImage(source: string, title: string, current: () => boolean): Promise<void> {
    await this.shareImages([source], title, current);
  }

  async shareImages(sources: string[], title: string, current: () => boolean, scope: string = ''): Promise<void> {
    if (!sources.every((source: string): boolean => acceptsImageDownloadUrl(source)))
      throw new Error(PinmonyI18n.message('pm_sharing_incomplete_please_retry_2a3623dc'));
    await this.shareMedia(sources, title, current, scope);
  }

  async shareMedia(sources: string[], title: string, current: () => boolean, scope: string = ''): Promise<void> {
    if (!this.active || this.imageShareBusy || !current()) return;
    if (scope !== this.sharedImageScope) {
      this.sharedImageFiles.clear();
      this.sharedImageScope = scope;
    }
    if (!sources.length || sources.length > 100 || !sources.every((source: string): boolean => acceptsImageDownloadUrl(source) || acceptsMediaFileUrl(source)))
      throw new PinmonyMediaSharePreparationError(PinmonyI18n.message('pm_sharing_incomplete_please_retry_2a3623dc'));
    const generation: number = this.generation;
    const sequence: number = ++this.imageShareSequence;
    const live = (): boolean => this.active && generation === this.generation && current();
    this.imageShareBusy = true;
    const outputs: string[] = [];
    const prepared: Map<string, PinmonySharedImageFile> = new Map<string, PinmonySharedImageFile>();
    let presented: boolean = false;
    let stage: string = 'prepare';
    let sharing: systemShare.ShareController | undefined = undefined;
    let closeLoading: (() => void) | undefined = undefined;
    const finishLoading = (): void => {
      closeLoading?.();
      if (this.dismissShareLoading === closeLoading) this.dismissShareLoading = undefined;
      closeLoading = undefined;
    };
    try {
      let loadingShown: boolean = false;
      const context: common.UIAbilityContext = this.context();
      const directory: string = context.cacheDir + '/pinmony-shared-images';
      if (!await fileIo.access(directory)) await fileIo.mkdir(directory);
      // Receivers may still read after the panel closes. Keep published files
      // for a day and prune only our own expired cache entries on the next share.
      const files: string[] = await fileIo.listFile(directory);
      for (const name of files) {
        const match: RegExpMatchArray | null = name.match(/^pin-([0-9]{13})-[0-9]+\.(jpg|png|gif|webp|avif|mp4)$/);
        if (match && Date.now() - Number(match[1]) > 86400000) {
          try { await fileIo.unlink(directory + '/' + name); } catch (_) {}
        }
      }
      if (!live()) return;
      let data: systemShare.SharedData | undefined = undefined;
      let totalBytes: number = 0;
      for (let index: number = 0; index < sources.length; index++) {
      const source: string = sources[index];
      let cached: PinmonySharedImageFile | undefined = prepared.get(source) || this.sharedImageFiles.get(source);
      if (cached) {
        let available: boolean = false;
        try {
          available = Date.now() - cached.createdAt < 86400000 && await fileIo.access(cached.path) &&
            (await fileIo.stat(cached.path)).size === cached.bytes;
        } catch (_) {}
        if (!live()) return;
        if (!available) { this.sharedImageFiles.delete(source); cached = undefined; }
      }
      let output: string;
      let type: string;
      if (cached) {
        totalBytes += cached.bytes;
        output = cached.path;
        type = cached.type;
        PinmonyRuntimeLog.info('SystemShareTrace: phase=image-cache-hit');
      } else {
      if (!loadingShown) {
        if (this.showShareLoading) {
          closeLoading = this.showShareLoading();
          this.dismissShareLoading = closeLoading;
        } else this.showMessage(PinmonyI18n.message('pm_loading_please_wait_b6aaac70'));
        loadingShown = true;
      }
      stage = 'download';
      if (acceptsMediaFileUrl(source)) {
        if (!this.shareVideoDownload) this.shareVideoDownload = new PinmonyMediaFile(
          (_event: string): void => {});
        const lease: PinmonyMediaFileLease = await this.shareVideoDownload.read(source, context.cacheDir, live);
        try {
          if (!live()) return;
          totalBytes += lease.size;
          if (totalBytes > 32 * 1024 * 1024) throw new Error('media-share-size');
          type = utd.getUniformDataTypeByFilenameExtension('.mp4', utd.UniformDataType.VIDEO);
          if (!type) throw new Error('media-share-type');
          output = directory + '/pin-' + Date.now().toString() + '-' + (sequence * 100 + index).toString() + '.mp4';
          outputs.push(output);
          stage = 'write';
          await fileIo.copyFile(lease.fd, output);
          if ((await fileIo.stat(output)).size !== lease.size) throw new Error('media-share-file-size');
          prepared.set(source, { path: output, type: type, bytes: lease.size, createdAt: Date.now() });
        } finally { lease.release(); }
      } else {
      const result: PinmonyDownloadedImage = await this.shareImageDownload.read(sources[index], live);
      if (!live()) return;
      totalBytes += result.data.byteLength;
      if (totalBytes > 32 * 1024 * 1024) throw new Error('image-share-size');
      type = utd.getUniformDataTypeByFilenameExtension('.' + result.extension, utd.UniformDataType.IMAGE);
      if (!type) throw new Error('image-share-type');
      output = directory + '/pin-' + Date.now().toString() + '-' + (sequence * 100 + index).toString() + '.' + result.extension;
      outputs.push(output);
      stage = 'write';
      const file: fileIo.File = await fileIo.open(output, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try {
        let offset: number = 0;
        while (offset < result.data.byteLength) {
          const written: number = await fileIo.write(file.fd, result.data.slice(offset));
          if (written <= 0) throw new Error('image-share-write');
          offset += written;
        }
      } finally { await fileIo.close(file); }
      if ((await fileIo.stat(output)).size !== result.data.byteLength) throw new Error('image-share-file-size');
      prepared.set(source, { path: output, type: type, bytes: result.data.byteLength, createdAt: Date.now() });
      }
      }
      if (totalBytes > 32 * 1024 * 1024) throw new Error('image-share-size');
      if (!live()) return;
      const uri: string = fileUri.getUriFromPath(output);
      const record: systemShare.SharedRecord = acceptsMediaFileUrl(source) ?
        { utd: type, uri: uri, title: title.slice(0, 300) } :
        { utd: type, uri: uri, thumbnailUri: uri, title: title.slice(0, 300) };
      if (data) data.addRecord(record);
      else data = new systemShare.SharedData(record);
      }
      if (!data || !live()) return;
      const controller: systemShare.ShareController = new systemShare.ShareController(data);
      sharing = controller;
      stage = 'panel';
      controller.on('shareCompleted', (result: systemShare.ShareOperationResult): void => {
        // This callback identifies the system target; it is not proof that the
        // receiving device saved every file. Never log target-provided strings.
        PinmonyRuntimeLog.info('SystemShareTrace: phase=target-returned harmonyShare=' +
          (result.targetAbilityInfo?.name === systemShare.ShareAbilityName.HARMONYSHARE).toString());
      });
      const onDismiss = (): void => {
        PinmonyRuntimeLog.info('SystemShareTrace: phase=panel-dismissed');
        this.imageShareControllers.delete(controller);
        try { controller.off('dismiss', onDismiss); controller.off('shareCompleted'); } catch (_) {}
      };
      controller.on('dismiss', onDismiss);
      this.imageShareControllers.set(controller, onDismiss);
      PinmonyRuntimeLog.info('SystemShareTrace: phase=panel-requested images=' + sources.length.toString() +
        ' bytes=' + totalBytes.toString());
      await controller.show(context, {
        selectionMode: sources.length > 1 ? systemShare.SelectionMode.BATCH : systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      });
      presented = true;
      finishLoading();
      PinmonyRuntimeLog.info('SystemShareTrace: phase=panel-presented');
      if (this.active && generation === this.generation && scope === this.sharedImageScope) {
        prepared.forEach((cached: PinmonySharedImageFile, source: string): void => {
          this.sharedImageFiles.delete(source);
          this.sharedImageFiles.set(source, cached);
        });
        // Bound the session index; published files remain available to receivers.
        const keys: string[] = [];
        this.sharedImageFiles.forEach((_cached: PinmonySharedImageFile, source: string): void => { keys.push(source); });
        for (let index: number = 0; index < keys.length - 100; index++) this.sharedImageFiles.delete(keys[index]);
      }
    } catch (error) {
      const code: number | undefined = (error as BusinessError)?.code;
      PinmonyRuntimeLog.warn('SystemShareTrace: phase=failed stage=' + stage + ' code=' +
        (typeof code === 'number' && Number.isSafeInteger(code) ? code.toString() : 'unavailable'));
      if (sharing) {
        const dismiss: (() => void) | undefined = this.imageShareControllers.get(sharing);
        try { if (dismiss) sharing.off('dismiss', dismiss); sharing.off('shareCompleted'); } catch (_) {}
        this.imageShareControllers.delete(sharing);
      }
      if (live()) {
        if (stage !== 'panel') throw new PinmonyMediaSharePreparationError(PinmonyI18n.message('pm_sharing_incomplete_please_retry_2a3623dc'));
        throw new Error(PinmonyI18n.message('pm_sharing_incomplete_please_retry_2a3623dc'));
      }
    } finally {
      finishLoading();
      if (!presented) for (const output of outputs) { try { await fileIo.unlink(output); } catch (_) {} }
      if (generation === this.generation && sequence === this.imageShareSequence) this.imageShareBusy = false;
    }
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

  async jpegFromBytes(bytes: ArrayBuffer): Promise<ArrayBuffer> {
    const source: image.ImageSource = image.createImageSource(bytes);
    const packer: image.ImagePacker = image.createImagePacker();
    try { return await packer.packToData(source, { format: 'image/jpeg', quality: 90 }); }
    catch (error) { throw new Error(error instanceof Error ? error.message : String(error)); }
    finally { await packer.release(); await source.release(); }
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
