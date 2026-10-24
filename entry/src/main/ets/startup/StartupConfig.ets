import { StartupConfig, StartupConfigEntry } from '@kit.AbilityKit';
import { PinmonyRuntimeLog } from 'common_foundation';
export default class PinmonyStartupConfig extends StartupConfigEntry {
  onConfig(): StartupConfig {
    const startedAt: number = Date.now();
    return {
      timeoutMs: 10000,
      startupListener: {
        onCompleted: (error): void => {
          if (error) PinmonyRuntimeLog.error('StartupTask: framework failed code=' + error.code.toString());
          else PinmonyRuntimeLog.info('StartupTask: framework complete elapsedMs=' + (Date.now() - startedAt).toString());
        }
      }
    };
  }
}
