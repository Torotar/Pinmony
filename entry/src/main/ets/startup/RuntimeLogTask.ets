import { StartupTask, common } from '@kit.AbilityKit';
import { PinmonyRuntimeLog } from 'common_foundation';

@Sendable
export default class RuntimeLogTask extends StartupTask {
  async init(context: common.AbilityStageContext): Promise<string> {
    const startedAt: number = Date.now();
    // History restoration is asynchronous and is not awaited by startup.
    PinmonyRuntimeLog.initialize(context.filesDir);
    PinmonyRuntimeLog.info('StartupTask: RuntimeLogTask complete elapsedMs=' + (Date.now() - startedAt).toString());
    return 'RuntimeLogTask';
  }
  onDependencyCompleted(_name: string, _result: Object): void {}
}
