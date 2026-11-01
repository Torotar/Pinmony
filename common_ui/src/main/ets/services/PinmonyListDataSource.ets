// Stable ArkUI data owner. Content keys retain unchanged nodes on reload;
// append notifications avoid rebuilding the already visible prefix.
export class PinmonyListDataSource<T extends Object> implements IDataSource {
  private items: T[] = [];
  private keys: string[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number { return this.items.length; }
  getData(index: number): T { return this.items[index]; }
  key(index: number): string { return this.keys[index]; }
  registerDataChangeListener(listener: DataChangeListener): void {
    if (!this.listeners.includes(listener)) this.listeners.push(listener);
  }
  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener);
    if (index >= 0) this.listeners.splice(index, 1);
  }
  update(items: T[], keys: string[]): void {
    if (items.length !== keys.length) throw new Error('list-key-count');
    const previousCount: number = this.keys.length;
    const commonCount: number = Math.min(previousCount, keys.length);
    let prefix: number = 0;
    while (prefix < commonCount && this.keys[prefix] === keys[prefix]) prefix++;
    let suffix: number = 0;
    while (suffix < commonCount - prefix &&
      this.keys[previousCount - 1 - suffix] === keys[keys.length - 1 - suffix]) suffix++;
    this.items = items.slice(); this.keys = keys.slice();
    if (prefix === previousCount && previousCount === keys.length) return;
    if (prefix + suffix === previousCount && keys.length > previousCount) {
      for (let index: number = prefix; index < keys.length - suffix; index++) {
        this.listeners.forEach((listener: DataChangeListener): void => listener.onDataAdd(index));
      }
    } else if (prefix + suffix === keys.length && previousCount > keys.length) {
      for (let index: number = previousCount - suffix - 1; index >= prefix; index--) {
        this.listeners.forEach((listener: DataChangeListener): void => listener.onDataDelete(index));
      }
    } else {
      this.listeners.forEach((listener: DataChangeListener): void => listener.onDataReloaded());
    }
  }
}
