// Fixed-capacity diagnostics. Appending never copies the retained history.
export class PinmonyLogBuffer {
  private readonly capacity: number;
  private readonly entries: string[] = [];
  private head: number = 0;
  private count: number = 0;
  constructor(capacity: number) { this.capacity = Math.max(1, Math.floor(capacity)); }
  push(line: string): void {
    if (this.count < this.capacity) {
      this.entries[(this.head + this.count) % this.capacity] = line;
      this.count++;
    } else {
      this.entries[this.head] = line;
      this.head = (this.head + 1) % this.capacity;
    }
  }
  snapshot(): string[] {
    const result: string[] = [];
    for (let i: number = 0; i < this.count; i++) result.push(this.entries[(this.head + i) % this.capacity]);
    return result;
  }
  clear(): void { this.entries.length = 0; this.head = 0; this.count = 0; }
}
