import { PINMONY_BUILD_IDENTITY } from '../app/PinmonyBuildIdentity';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyRuntimeLog } from 'common_foundation';
import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want, errorManager } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { webview } from '@kit.ArkWeb';
import { NetworkManager } from 'common_network';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | undefined = undefined;
  private lifecycleSequence: number = 0;
  private runtimeErrorSequence: number = 0;
  private lifecycleStartedAt: number = 0;
  private lifecycleLastEventAt: number = 0;
  private windowStageReady: boolean = false;
  private contentLoadStartedAt: number = 0;
  private contentLoaded: boolean = false;
  private readonly errorObserver: errorManager.GlobalObserver = (reason: errorManager.GlobalError): void => {
    this.recordRuntimeError(reason, 'exception');
  };
  private readonly rejectionObserver: errorManager.GlobalObserver = (reason: errorManager.GlobalError): void => {
    this.recordRuntimeError(reason, 'rejection');
  };

  private recordRuntimeError(reason: errorManager.GlobalError, kind: string): void {
    const name: string = typeof reason.name === 'string' && /^[A-Za-z]+$/.test(reason.name) ? reason.name : 'UnknownError';
    // Classify known errors without exporting arbitrary messages or business payloads.
    const message: string = typeof reason.message === 'string' ? reason.message : '';
    const category: string = /measure|MeasureUtils|constraintWidth/i.test(message) ? 'text-measure' :
      /ForEach|duplicate.*key/i.test(message) ? 'node-identity' :
      /Webview|WebView|controller|runJavaScript/i.test(message) ? 'web-controller' :
      /cancel|abort/i.test(message) ? 'cancellation' : 'unknown';
    PinmonyRuntimeLog.error('Runtime: unhandled error ' + name + ' kind=' + kind + ' category=' + category + ' sequence=' + (++this.runtimeErrorSequence).toString());
    PinmonyRuntimeLog.error('Runtime action context: ' + PinmonyRuntimeLog.recentActionContext());
    const rawStack: string = typeof reason.stack === 'string' ? reason.stack : '';
    // Keep source basenames/line numbers only, for both Ark and standard stack formats.
    const frames: string[] = rawStack.match(/[A-Za-z][A-Za-z0-9_-]*\.(?:ets|ts|js):[0-9]+(?::[0-9]+)?/g) || [];
    frames.slice(0, 12).forEach((line: string) => PinmonyRuntimeLog.error('Runtime stack: ' + line));
    if (frames.length === 0) PinmonyRuntimeLog.error('Runtime stack: unavailable');
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    PinmonyRuntimeLog.initialize(this.context.filesDir);
    try { PinmonyI18n.initialize(this.context); }
    catch (_) { PinmonyRuntimeLog.warn('LanguagePreference: restore failed'); PinmonyI18n.syncSystemLanguage(); }
    PinmonyRuntimeLog.info('LanguagePreference: restored=' + (AppStorage.get<string>('pinmonyLanguagePreference') || 'system') +
      ' effective=' + (AppStorage.get<string>('pinmonyLanguage') || 'unknown'));
    PinmonyRuntimeLog.info('RuntimeBuild: ' + PINMONY_BUILD_IDENTITY);
    this.lifecycleStartedAt = Date.now();
    this.lifecycleLastEventAt = this.lifecycleStartedAt;
    this.logLifecycle('create-start', 'windowStage=false content=false');
    NetworkManager.preConnect('https://www.pinterest.com').catch(() => {
      // Startup pre-connect is best effort and never blocks the ability.
    });
    PinmonyRuntimeLog.info('AbilityLifecycle: preconnect-dispatched');
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
    try {
      errorManager.on('globalErrorOccurred', this.errorObserver);
      errorManager.on('globalUnhandledRejectionDetected', this.rejectionObserver);
    } catch (_) { PinmonyRuntimeLog.warn('Runtime: exception observer unavailable'); }
    PersistentStorage.persistProp('themePreference', 'system');
    PersistentStorage.persistProp('screenOrientationPreference', 'system');
    PersistentStorage.persistProp('pinmonySessionOrigin', 'https://www.pinterest.com');
    PersistentStorage.persistProp('pinmonySessionConfirmed', false);
    try {
      const preference: string = AppStorage.get<string>('themePreference') || 'system';
      this.context.getApplicationContext().setColorMode(preference === 'dark' ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK : preference === 'light' ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    PersistentStorage.persistProp('bottomBarScrollCollapseEnabled', true);
    PersistentStorage.persistProp('pinwebHomeOfflineMarker', '');
    this.syncSystemColorMode();
    this.logLifecycle('create-complete', 'windowStage=false content=false');
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    this.logLifecycle('destroy-start', 'windowStage=' + this.windowStageReady.toString() +
      ' content=' + this.contentLoaded.toString());
    NetworkManager.destroy();
    try {
      errorManager.off('globalErrorOccurred', this.errorObserver);
      errorManager.off('globalUnhandledRejectionDetected', this.rejectionObserver);
    } catch (_) { PinmonyRuntimeLog.warn('Runtime: exception observer cleanup unavailable'); }
    this.windowStageReady = false;
    this.contentLoaded = false;
    this.logLifecycle('destroy-complete', 'windowStage=false content=false');
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
    PinmonyRuntimeLog.flush();
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    PinmonyI18n.syncSystemLanguage();
    this.logLifecycle('configuration-update', 'windowStage=' + this.windowStageReady.toString() +
      ' content=' + this.contentLoaded.toString() + ' colorMode=' +
      (typeof newConfig.colorMode === 'number' ? newConfig.colorMode.toString() : 'undefined'));
    this.syncSystemColorMode(newConfig.colorMode);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.windowStageReady = true;
    this.logLifecycle('window-stage-create', 'windowStage=true content=' + this.contentLoaded.toString());
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    try {
      this.mainWindow = windowStage.getMainWindowSync();
      if (deviceInfo.deviceType === 'tablet') {
        const preference: string = AppStorage.get<string>('screenOrientationPreference') || 'system';
        const orientation: window.Orientation = preference === 'auto' ? window.Orientation.AUTO_ROTATION :
          preference === 'portrait' ? window.Orientation.PORTRAIT : preference === 'landscape' ?
            window.Orientation.LANDSCAPE : window.Orientation.AUTO_ROTATION_RESTRICTED;
        this.mainWindow.setPreferredOrientation(orientation).catch(() => {
          PinmonyRuntimeLog.warn('Settings: saved orientation unavailable');
        });
      }
      this.mainWindow.on('avoidAreaChange', (data) => {
        if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
          PinmonyRuntimeLog.info('AbilityLifecycle: avoid-area type=system topPx=' +
            data.area.topRect.height.toString());
          this.updateStatusBarHeight(data.area.topRect.height);
        } else if (data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          PinmonyRuntimeLog.info('AbilityLifecycle: avoid-area type=navigation bottomPx=' +
            data.area.bottomRect.height.toString());
          AppStorage.setOrCreate<number>('gestureBarHeightPx', Math.max(0, data.area.bottomRect.height));
        }
      });
      this.mainWindow.setWindowLayoutFullScreen(true).then(() => {
        this.syncStatusBarHeight();
      }).catch((err: Error) => {
        hilog.error(DOMAIN, 'testTag', 'Failed to set full-screen layout. Cause: %{public}s', JSON.stringify(err));
      });
      this.syncStatusBarHeight();
      this.syncSystemColorMode();
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to configure window. Cause: %{public}s', JSON.stringify(err));
    }

    this.contentLoadStartedAt = Date.now();
    this.logLifecycle('content-load-start', 'windowStage=' + this.windowStageReady.toString() +
      ' content=false');
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        this.contentLoaded = false;
        this.logLifecycle('content-load-failed', 'code=' + err.code.toString());
        PinmonyRuntimeLog.error('Ability: loadContent failed, code ' + err.code.toString());
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      this.contentLoaded = true;
      const loadMs: number = this.contentLoadStartedAt > 0 ? Date.now() - this.contentLoadStartedAt : -1;
      this.logLifecycle('content-load-complete', 'loadMs=' + loadMs.toString() +
        ' windowStage=' + this.windowStageReady.toString());
      this.syncStatusBarHeight();
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    this.logLifecycle('window-stage-destroy', 'windowStage=true content=' + this.contentLoaded.toString());
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
    try {
      this.mainWindow?.off('avoidAreaChange');
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to remove avoid-area listener. Cause: %{public}s', JSON.stringify(err));
    }
    this.mainWindow = undefined;
    this.windowStageReady = false;
    this.contentLoaded = false;
  }

  private updateStatusBarHeight(heightPx: number): void {
    AppStorage.setOrCreate<number>('statusBarHeightPx', Math.max(0, heightPx));
  }

  private syncStatusBarHeight(): void {
    if (!this.mainWindow) {
      return;
    }
    try {
      const area: window.AvoidArea = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.updateStatusBarHeight(area.topRect.height);
      const gestureArea: window.AvoidArea = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      AppStorage.setOrCreate<number>('gestureBarHeightPx', Math.max(0, gestureArea.bottomRect.height));
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to read status-bar avoid area. Cause: %{public}s', JSON.stringify(err));
    }
  }

  private syncSystemColorMode(colorMode?: ConfigurationConstant.ColorMode): void {
    try {
      let currentMode: number | undefined = colorMode;
      if (currentMode === undefined || currentMode === ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET) {
        currentMode = this.context.resourceManager.getConfigurationSync().colorMode;
      }
      const preference: string = AppStorage.get<string>('themePreference') || 'system';
      const isDark: boolean = preference === 'dark' || preference === 'system' && currentMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      AppStorage.setOrCreate<boolean>('systemDarkMode', isDark);
      if (!this.mainWindow) {
        return;
      }
      const contentColor: string = isDark ? '#F7F8FA' : '#1B1E25';
      this.mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: contentColor,
        navigationBarContentColor: contentColor
      });
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to sync system color mode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onForeground(): void {
    // Ability has brought to foreground
    this.logLifecycle('foreground', 'windowStage=' + this.windowStageReady.toString() +
      ' content=' + this.contentLoaded.toString());
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
    this.syncSystemColorMode();
    this.syncStatusBarHeight();
  }

  onBackground(): void {
    // Ability has back to background
    this.logLifecycle('background', 'windowStage=' + this.windowStageReady.toString() +
      ' content=' + this.contentLoaded.toString());
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
    try {
      void webview.WebCookieManager.saveCookieAsync().then((): void => {
        PinmonyRuntimeLog.info('NativeSession: background cookie store saved');
      }).catch((): void => { PinmonyRuntimeLog.warn('NativeSession: background cookie store save unavailable'); });
    } catch (_) { PinmonyRuntimeLog.warn('NativeSession: background cookie store save unavailable'); }
    PinmonyRuntimeLog.flush();
  }

  private logLifecycle(event: string, state: string): void {
    const now: number = Date.now();
    const sinceStart: number = this.lifecycleStartedAt > 0 ? now - this.lifecycleStartedAt : -1;
    const sincePrevious: number = this.lifecycleLastEventAt > 0 ? now - this.lifecycleLastEventAt : -1;
    this.lifecycleLastEventAt = now;
    this.lifecycleSequence++;
    PinmonyRuntimeLog.info('AbilityLifecycle: event=' + event + ' sequence=' + this.lifecycleSequence.toString() +
      ' sinceStartMs=' + sinceStart.toString() + ' sincePreviousMs=' + sincePrevious.toString() + ' ' + state);
  }
}
