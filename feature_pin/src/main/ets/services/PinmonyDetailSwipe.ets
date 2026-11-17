// Physical window coordinates deliberately do not follow the UI language.
export class PinmonyDetailSwipe {
  private armed: boolean = false;
  private startX: number = 0;
  private startY: number = 0;
  private identity: string = '';

  start(x: number, y: number, identity: string, allowed: boolean, now: number): void {
    this.armed = allowed;
    this.startX = x; this.startY = y; this.identity = identity;
  }

  move(x: number, y: number, now: number): void {
    if (Math.abs(y - this.startY) > 12 && Math.abs(y - this.startY) * 1.5 >= Math.abs(x - this.startX)) this.cancel();
  }

  end(x: number, y: number, identity: string, allowed: boolean, now: number): boolean {
    const accepted: boolean = this.armed && allowed && identity === this.identity &&
      Math.abs(x - this.startX) >= 48 &&
      Math.abs(x - this.startX) > Math.abs(y - this.startY) * 1.5;
    this.cancel();
    return accepted;
  }

  endOffset(x: number, y: number, identity: string, allowed: boolean, now: number): boolean {
    return this.end(this.startX + x, this.startY + y, identity, allowed, now);
  }

  cancel(): void { this.armed = false; }
}
