import { PinmonyRelatedPin } from './PinmonyDetail';

export class PinmonyRelatedDataSource implements IDataSource {
  private items: PinmonyRelatedPin[] = [];
  private listeners: DataChangeListener[] = [];
  totalCount(): number { return this.items.length; }
  getData(index: number): PinmonyRelatedPin { return this.items[index]; }
  registerDataChangeListener(listener: DataChangeListener): void {
    if (!this.listeners.includes(listener)) this.listeners.push(listener);
  }
  unregisterDataChangeListener(listener: DataChangeListener): void {
    this.listeners = this.listeners.filter((item: DataChangeListener): boolean => item !== listener);
  }
  update(items: PinmonyRelatedPin[]): void {
    if (JSON.stringify(this.items) === JSON.stringify(items)) return;
    const append: boolean = items.length >= this.items.length && this.items.every((item: PinmonyRelatedPin, index: number): boolean =>
      JSON.stringify(item) === JSON.stringify(items[index]));
    const previous: number = this.items.length;
    this.items = items;
    this.listeners.forEach((listener: DataChangeListener) => {
      if (append) {
        for (let index: number = previous; index < items.length; index++) listener.onDataAdd(index);
      } else listener.onDataReloaded();
    });
  }
}
