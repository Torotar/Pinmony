import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { PinmonyRuntimeLog } from './PinmonyRuntimeLog';

interface PublishAnchor { right: boolean; fraction: number; xFraction?: number; }

export class PinmonyPublishAnchor {
  private static storage: preferences.Preferences | undefined = undefined;
  static initialize(context: common.Context): void {
    try {
      PinmonyPublishAnchor.storage = preferences.getPreferencesSync(context, {name:'pinmony_publish_anchor'});
      const raw: preferences.ValueType = PinmonyPublishAnchor.storage.getSync('anchor', '');
      if(typeof raw !== 'string' || !raw)return;
      const anchor: PublishAnchor = JSON.parse(raw) as PublishAnchor;
      if(typeof anchor.right !== 'boolean' || !Number.isFinite(anchor.fraction) || anchor.fraction < 0 || anchor.fraction > 1)throw new Error('anchor');
      const xFraction: number = anchor.xFraction === undefined ? (anchor.right ? 1 : 0) : anchor.xFraction;
      if(!Number.isFinite(xFraction) || xFraction < 0 || xFraction > 1)throw new Error('anchor-x');
      AppStorage.setOrCreate('pinmonyPublishAnchorXFraction', xFraction);
      AppStorage.setOrCreate('pinmonyPublishAnchorRight', anchor.right);
      AppStorage.setOrCreate('pinmonyPublishAnchorFraction', anchor.fraction);
      AppStorage.setOrCreate('pinmonyPublishAnchorMoved', true);
      PinmonyRuntimeLog.info('PublishAnchorTrace: event=disk-restored');
    }catch (_) {PinmonyRuntimeLog.warn('PublishAnchorTrace: event=disk-read-failed');}
  }
  static save(right: boolean, fraction: number, xFraction: number = right ? 1 : 0): void {
    if(!Number.isFinite(fraction) || fraction < 0 || fraction > 1 || !Number.isFinite(xFraction) || xFraction < 0 || xFraction > 1)return;
    try {
      if(!PinmonyPublishAnchor.storage)throw new Error('storage');
      const anchor: PublishAnchor = {right:right,fraction:fraction,xFraction:xFraction};
      PinmonyPublishAnchor.storage.putSync('anchor', JSON.stringify(anchor));
      PinmonyPublishAnchor.storage.flushSync();
      PinmonyRuntimeLog.info('PublishAnchorTrace: event=disk-saved');
    }catch (_) {PinmonyRuntimeLog.warn('PublishAnchorTrace: event=disk-write-failed');}
  }
}
