/** Component-owned callbacks that must not write state during native rendering. */
export class PinmonyUiCommitQueue {
  private jobs: Map<string, () => void> = new Map<string, () => void>();
  private timer: number = -1;
  private epoch: number = 0;
  private active: boolean = true;

  activate(): void { this.active = true; }

  post(key: string, commit: () => void): void {
    if (!this.active) return;
    this.jobs.set(key, commit);
    if (this.timer !== -1) return;
    const epoch: number = this.epoch;
    this.timer = setTimeout((): void => {
      this.timer = -1;
      const jobs: Map<string, () => void> = this.jobs;
      this.jobs = new Map<string, () => void>();
      jobs.forEach((job: () => void): void => {
        if (this.active && epoch === this.epoch) job();
      });
    }, 0);
  }

  clear(): void {
    this.epoch++;
    if (this.timer !== -1) clearTimeout(this.timer);
    this.timer = -1;
    this.jobs.clear();
  }

  dispose(): void { this.active = false; this.clear(); }
}
