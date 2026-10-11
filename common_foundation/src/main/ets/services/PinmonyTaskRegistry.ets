// Page-owned timer registry. Invalidating a page cancels its delayed work and
// prevents a callback queued before navigation from updating UI state.
export class PinmonyTaskRegistry {
  private timeoutIds: Set<number> = new Set<number>();
  private intervalIds: Set<number> = new Set<number>();
  private generation: number = 0;
  private waiters: Map<number, (completed: boolean) => void> = new Map<number, (completed: boolean) => void>();

  // Unlike a cancelled timeout callback, an awaited delay must always settle.
  wait(delayMs: number): Promise<boolean> {
    return new Promise<boolean>((resolve: (completed: boolean) => void): void => {
      let id: number = -1;
      id = this.timeout((): void => { this.waiters.delete(id); resolve(true); }, delayMs);
      this.waiters.set(id, resolve);
    });
  }

  timeout(callback: () => void, delayMs: number): number {
    const generation: number = this.generation;
    let id: number = -1;
    id = setTimeout((): void => {
      this.timeoutIds.delete(id);
      if (generation === this.generation) callback();
    }, Math.max(0, delayMs));
    this.timeoutIds.add(id);
    return id;
  }

  interval(callback: () => void, delayMs: number): number {
    const generation: number = this.generation;
    const id: number = setInterval((): void => {
      if (generation === this.generation) callback();
    }, Math.max(1, delayMs));
    this.intervalIds.add(id);
    return id;
  }

  cancelTimeout(id: number): void {
    if (id < 0) return;
    clearTimeout(id);
    this.timeoutIds.delete(id);
    const resolve = this.waiters.get(id);
    this.waiters.delete(id);
    if (resolve) resolve(false);
  }

  cancelInterval(id: number): void {
    if (id < 0) return;
    clearInterval(id);
    this.intervalIds.delete(id);
  }

  invalidate(): number {
    const pendingBefore: number = this.pendingCount();
    this.generation++;
    this.clearAll();
    return pendingBefore;
  }

  clearAll(): void {
    this.waiters.forEach((resolve: (completed: boolean) => void): void => resolve(false));
    this.waiters.clear();
    this.timeoutIds.forEach((id: number): void => clearTimeout(id));
    this.intervalIds.forEach((id: number): void => clearInterval(id));
    this.timeoutIds.clear();
    this.intervalIds.clear();
  }

  pendingCount(): number {
    return this.timeoutIds.size + this.intervalIds.size;
  }
}
