import { StartupTask, common } from '@kit.AbilityKit';
import { PinmonyRuntimeLog } from 'common_foundation';
import { webview } from '@kit.ArkWeb';

@Sendable
export default class WebEngineTask extends StartupTask {
  async init(context: common.AbilityStageContext): Promise<string> {
    const startedAt: number = Date.now();
    try {
      webview.WebviewController.setWebDebuggingAccess(false);
    } catch (_) { PinmonyRuntimeLog.warn('Web: debug configuration unavailable'); }
    try {
      const features: webview.BackForwardCacheSupportedFeatures = new webview.BackForwardCacheSupportedFeatures();
      // Visible media is native; do not opt hidden Web media or native embeds into retention.
      features.nativeEmbed = false;
      features.mediaTakeOver = false;
      webview.WebviewController.enableBackForwardCache(features);
      webview.WebviewController.initializeWebEngine();
    } catch (_) { PinmonyRuntimeLog.warn('PinmonyReturn: document retention unavailable'); }
    PinmonyRuntimeLog.info('StartupTask: WebEngineTask complete elapsedMs=' + (Date.now() - startedAt).toString());
    return 'WebEngineTask';
  }
  onDependencyCompleted(_name: string, _result: Object): void {}
}
