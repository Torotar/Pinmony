// Keep the return target until the user scrolls. Layout/image callbacks may arrive
// several times, and their temporary clamped offsets must not replace that target.
export class PinmonyChatScrollPosition {
  private conversation: string = '';
  private target: number = -1;
  private reading: boolean = false;
  private laidOut: boolean = false;

  begin(conversation: string, offset: number): void {
    if (!conversation || this.conversation === conversation) return;
    this.conversation = conversation;
    this.target = Number.isFinite(offset) && offset >= 0 ? offset : -1;
    this.reading = false; this.laidOut = false;
  }

  latest(): void { this.target = -1; this.reading = false; }
  restore(offset: number): void {
    if (!Number.isFinite(offset) || offset < 0) return;
    this.target = offset; this.reading = false; this.laidOut = false;
  }
  canLoadHistory(): boolean { return this.reading; }

  layout(contentHeight: number, viewportHeight: number): number | undefined {
    if (!this.conversation || this.reading || contentHeight <= 0 || viewportHeight <= 0) return undefined;
    this.laidOut = true;
    const maximum: number = Math.max(0, contentHeight - viewportHeight);
    return this.target >= 0 ? Math.min(this.target, maximum) : maximum;
  }

  record(offset: number, userScroll: boolean): boolean {
    if (!this.laidOut || !Number.isFinite(offset) || offset < 0) return false;
    if (userScroll) this.reading = true;
    return this.reading;
  }
}
