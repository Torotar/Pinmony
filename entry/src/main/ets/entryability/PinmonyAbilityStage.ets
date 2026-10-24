import { AbilityStage } from '@kit.AbilityKit';
import { PinmonyRuntimeLog } from 'common_foundation';
export default class PinmonyAbilityStage extends AbilityStage {
  onCreate(): void {
    AppStorage.setOrCreate<number>('pinmonyAbilityStageReadyAt', Date.now());
    PinmonyRuntimeLog.info('AbilityStageLifecycle: create');
    const readyAt: number = Date.now();
    AppStorage.setOrCreate<boolean>('pinmonyStartupAbilityConstructed', false);
    // Bounded probes show whether the JS loop runs during the stage/ability gap.
    // They cannot measure imports before this module executes or the desktop tap.
    const delays: number[] = [0, 1000, 2000, 3000, 4000];
    let sample: number = 0;
    const probe = (): void => {
      if (AppStorage.get<boolean>('pinmonyStartupAbilityConstructed')) return;
      const scheduledAt: number = Date.now();
      const delay: number = delays[sample];
      setTimeout((): void => {
        const now: number = Date.now();
        PinmonyRuntimeLog.info('StartupBoundary: stage-loop-probe sample=' + sample.toString() +
          ' sinceStageMs=' + (now - readyAt).toString() +
          ' lateMs=' + Math.max(0, now - scheduledAt - delay).toString() +
          ' abilityConstructed=' + (!!AppStorage.get<boolean>('pinmonyStartupAbilityConstructed')).toString());
        sample++;
        if (sample < delays.length) probe();
      }, delay);
    };
    probe();
  }
}
