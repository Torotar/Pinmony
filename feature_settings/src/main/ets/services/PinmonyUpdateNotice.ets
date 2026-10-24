import { common, bundleManager } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { PinmonyReleaseClient, isNewerRelease } from './PinmonyRelease';
import { PinmonyRuntimeLog } from 'common_foundation';

export class PinmonyUpdateNotice {
  private static started: boolean = false;
  private static storage: preferences.Preferences | undefined = undefined;
  private static seen: string = '';
  private static latest: string = '';
  private static aboutVisible: boolean = false;
  private static client: PinmonyReleaseClient = new PinmonyReleaseClient();
  static async start(context: common.Context): Promise<void> {
    if (PinmonyUpdateNotice.started) return;
    PinmonyUpdateNotice.started = true;
    try {
      PinmonyUpdateNotice.storage = preferences.getPreferencesSync(context, { name: 'pinmony_update_notice' });
      const seen: preferences.ValueType = PinmonyUpdateNotice.storage.getSync('seenVersion', '');
      PinmonyUpdateNotice.seen = typeof seen === 'string' ? seen : '';
      const installed: string = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT).versionName;
      const release = await PinmonyUpdateNotice.client.latest(installed);
      PinmonyUpdateNotice.confirm(release?.tag_name || '', installed);
    } catch (_) { PinmonyRuntimeLog.warn('UpdateNotice: startup-check-unavailable'); }
  }
  static confirm(tag: string, installed: string): void {
    if (PinmonyUpdateNotice.latest && isNewerRelease(PinmonyUpdateNotice.latest, tag)) return;
    PinmonyUpdateNotice.latest = tag;
    const available: boolean = isNewerRelease(tag, installed);
    if (available && PinmonyUpdateNotice.aboutVisible) PinmonyUpdateNotice.markSeen();
    AppStorage.setOrCreate('pinmonyUpdateUnread', available &&
      (!PinmonyUpdateNotice.seen || isNewerRelease(tag, PinmonyUpdateNotice.seen)));
  }
  static setAboutVisible(visible: boolean): void {
    PinmonyUpdateNotice.aboutVisible = visible;
    if (visible && AppStorage.get<boolean>('pinmonyUpdateUnread')) PinmonyUpdateNotice.markSeen();
  }
  private static markSeen(): void {
    if (!PinmonyUpdateNotice.latest) return;
    PinmonyUpdateNotice.seen = PinmonyUpdateNotice.latest;
    AppStorage.setOrCreate('pinmonyUpdateUnread', false);
    try {
      PinmonyUpdateNotice.storage?.putSync('seenVersion', PinmonyUpdateNotice.seen);
      PinmonyUpdateNotice.storage?.flushSync();
    } catch (_) { PinmonyRuntimeLog.warn('UpdateNotice: read-state-save-unavailable'); }
  }
}
