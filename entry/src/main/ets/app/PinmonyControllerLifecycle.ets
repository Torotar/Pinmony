import { PinmonyRuntimeLog } from 'common_foundation';

export interface PinmonyControllerHooks {
  name: string;
  pause: () => void;
  resume?: () => void;
}
// Explicit composition, preserving feature ownership and registration order.
export class PinmonyControllerLifecycle {
  private readonly hooks: PinmonyControllerHooks[];
  constructor(hooks: PinmonyControllerHooks[]) { this.hooks = hooks.slice(); }
  pause(): void { this.apply(false); }
  resume(): void { this.apply(true); }
  private apply(resume: boolean): void {
    this.hooks.forEach((hook: PinmonyControllerHooks): void => {
      try { if (resume) { if (hook.resume) hook.resume(); } else hook.pause(); }
      catch (_) { PinmonyRuntimeLog.warn('ControllerLifecycle: hook failed name=' + hook.name + ' phase=' + (resume ? 'resume' : 'pause')); }
    });
  }
}
