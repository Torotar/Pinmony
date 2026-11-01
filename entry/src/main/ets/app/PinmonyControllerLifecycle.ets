import { PinmonyRuntimeLog } from 'common_foundation';

export interface PinmonyControllerHooks {
  name: string;
  pause: () => void;
  resume?: () => void;
}
export interface PinmonyHostControllerHooks {
  name: string;
  pause: () => void;
  resume?: () => void;
  reset: () => void;
}
// Explicit composition, preserving feature ownership and registration order.
export class PinmonyControllerLifecycle {
  private readonly hooks: PinmonyControllerHooks[];
  private readonly hostHooks: PinmonyHostControllerHooks[];
  constructor(hooks: PinmonyControllerHooks[], hostHooks: PinmonyHostControllerHooks[] = []) {
    this.hooks = hooks.slice();
    this.hostHooks = hostHooks.slice();
  }
  pause(): void { this.apply(false); }
  resume(): void { this.apply(true); }
  // Host-only participants keep their state during ordinary route coordination.
  background(): void { this.applyHost('pause'); this.pause(); }
  destroy(): void { this.background(); }
  resumeHost(): void { this.applyHost('resume'); }
  resetHost(): void { this.applyHost('reset'); }
  private applyHost(phase: string): void {
    this.hostHooks.forEach((hook: PinmonyHostControllerHooks): void => {
      try {
        if (phase === 'pause') hook.pause();
        else if (phase === 'reset') hook.reset();
        else if (hook.resume) hook.resume();
      } catch (_) {
        PinmonyRuntimeLog.warn('ControllerLifecycle: hook failed name=' + hook.name + ' phase=' + phase);
      }
    });
  }
  private apply(resume: boolean): void {
    this.hooks.forEach((hook: PinmonyControllerHooks): void => {
      try { if (resume) { if (hook.resume) hook.resume(); } else hook.pause(); }
      catch (_) { PinmonyRuntimeLog.warn('ControllerLifecycle: hook failed name=' + hook.name + ' phase=' + (resume ? 'resume' : 'pause')); }
    });
  }
}
