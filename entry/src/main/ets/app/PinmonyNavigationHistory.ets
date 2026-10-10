const HOME_URL: string = 'https://www.pinterest.com/';

// Native back navigation confirms the destination before removing its child.
export class PinmonyNavigationHistory {
  private pages: string[] = [HOME_URL];
  private pendingTarget: string = '';

  reset(): void {
    this.pages = [HOME_URL];
    this.pendingTarget = '';
  }

  key(url: string): string {
    const address: string = url.split('#')[0];
    const pin = address.match(/^(https:\/\/(?:[^/]+\.)?pinterest\.com)\/pin\/(\d+)(?:\/|[?]|$)/i);
    return pin ? pin[1] + '/pin/' + pin[2] + '/' : address;
  }

  visit(url: string, mode: string = 'push'): void {
    const target: string = this.key(url);
    if (!/^https?:\/\//i.test(target)) return;
    if (this.pendingTarget) {
      if (target === this.pendingTarget) {
        const index: number = this.pages.lastIndexOf(target);
        this.pages = index >= 0 ? this.pages.slice(0, index + 1) : [HOME_URL, target];
        this.pendingTarget = '';
        return;
      }
      // Source-document callbacks can arrive while a back navigation is in flight.
      // Only the requested destination confirms that navigation.
      return;
    }
    if (mode === 'observe') return;
    if (/^https:\/\/(?:[^/]+\.)?pinterest\.com\/(?:\?.*)?$/i.test(target)) {
      this.pages = [target];
      return;
    }
    if (this.pages[this.pages.length - 1] === target) return;
    if (mode === 'pop' || mode === 'load') {
      const index: number = this.pages.lastIndexOf(target);
      if (index >= 0) {
        this.pages = this.pages.slice(0, index + 1);
        return;
      }
    }
    const current: string = this.pages[this.pages.length - 1];
    if (mode === 'replace' && this.pages.length > 1 && current.split('?')[0] === target.split('?')[0]) {
      this.pages[this.pages.length - 1] = target;
    } else {
      this.pages.push(target);
    }
    if (this.pages.length > 64) this.pages.splice(1, 1);
  }

  prepareBack(fallback: string = HOME_URL): string {
    if (this.pendingTarget) return '';
    const current: string = this.pages[this.pages.length - 1];
    const target: string = this.pages.length > 1 ? this.pages[this.pages.length - 2] : this.key(fallback);
    if (!target || target === current) return '';
    this.pendingTarget = target;
    return target;
  }

  prepareBackTo(url: string): string {
    if (this.pendingTarget) return '';
    const target: string = this.key(url);
    if (!/^https?:\/\//i.test(target) || target === this.pages[this.pages.length - 1]) return '';
    this.pendingTarget = target;
    return target;
  }

  isPending(): boolean {
    return !!this.pendingTarget;
  }

  cancelBack(): void {
    this.pendingTarget = '';
  }
}
