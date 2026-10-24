import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { PinmonyRuntimeLog } from './PinmonyRuntimeLog';

interface PublishAnchor { right: boolean; fraction: number; }

export class PinmonyPublishAnchor {
  private static storage: preferences.Preferences | undefined = undefined;
  static initialize(context: common.Context): void {
    try {
      PinmonyPublishAnchor.storage = preferences.getPreferencesSync(context, {name:'pinmony_publish_anchor'});
      const raw: preferences.ValueType = PinmonyPublishAnchor.storage.getSync('anchor', '');
      if(typeof raw !== 'string' || !raw)return;
      const anchor: PublishAnchor = JSON.parse(raw) as PublishAnchor;
      if(typeof anchor.right !== 'boolean' || !Number.isFinite(anchor.fraction) || anchor.fraction < 0 || anchor.fraction > 1)throw new Error('anchor');
      AppStorage.setOrCreate('pinmonyPublishAnchorRight', anchor.right);
      AppStorage.setOrCreate('pinmonyPublishAnchorFraction', anchor.fraction);
      AppStorage.setOrCreate('pinmonyPublishAnchorMoved', true);
      PinmonyRuntimeLog.info('PublishAnchorTrace: event=disk-restored');
    }catch (_) {PinmonyRuntimeLog.warn('PublishAnchorTrace: event=disk-read-failed');}
  }
  static save(right: boolean, fraction: number): void {
    if(!Number.isFinite(fraction) || fraction < 0 || fraction > 1)return;
    try {
      if(!PinmonyPublishAnchor.storage)throw new Error('storage');
      const anchor: PublishAnchor = {right:right,fraction:fraction};
      PinmonyPublishAnchor.storage.putSync('anchor', JSON.stringify(anchor));
      PinmonyPublishAnchor.storage.flushSync();
      PinmonyRuntimeLog.info('PublishAnchorTrace: event=disk-saved');
    }catch (_) {PinmonyRuntimeLog.warn('PublishAnchorTrace: event=disk-write-failed');}
  }
}
