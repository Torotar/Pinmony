import { PinmonyDetailSource, PinmonyDetailSourceCard, PinmonyDetailSources } from 'common_ui';

export interface PinmonyDetailSiblingContext {
  source: PinmonyDetailSource;
  generation: number;
  current: PinmonyDetailSourceCard;
  // The destination stays mounted while its current Pin/card changes.
  presentationIdentity: string;
  switched: boolean;
}

export interface PinmonyDetailReturnRect {
  x: number;
  y: number;
  width: number;
  height: number;
}

export class PinmonyDetailSiblingNavigation {
  private contexts: Map<string, PinmonyDetailSiblingContext> = new Map<string, PinmonyDetailSiblingContext>();
  private revision: number = 0;
  private generation: number = -1;

  enter(pin: string, cardId: string, generation: number, returning: boolean): void {
    const source: PinmonyDetailSource | undefined = returning ? undefined : PinmonyDetailSources.take(pin, cardId);
    if (generation !== this.generation) { this.clear(); this.generation = generation; }
    this.revision++;
    if (returning) return;
    const card: PinmonyDetailSourceCard | undefined = source?.cards().find((item: PinmonyDetailSourceCard): boolean =>
      item.pinUrl === pin && (item.entryCardId || item.cardId) === cardId);
    this.contexts.delete(pin);
    if (source && card) this.contexts.set(pin, { source: source, generation: generation, current: card,
      presentationIdentity: 'sibling:' + generation.toString() + ':' + this.revision.toString(), switched: false });
    if (this.contexts.size > 32) this.contexts.delete(this.contexts.keys().next().value);
  }

  context(pin: string, generation: number): PinmonyDetailSiblingContext | undefined {
    const context: PinmonyDetailSiblingContext | undefined = this.contexts.get(pin);
    return context?.generation === generation ? context : undefined;
  }

  // Physical left advances in source order; physical right goes backwards.
  available(pin: string, generation: number): boolean {
    const context: PinmonyDetailSiblingContext | undefined = this.context(pin, generation);
    return !!context && context.source.cards().some((card: PinmonyDetailSourceCard): boolean =>
      card.pinUrl === pin && card.cardId === context.current.cardId);
  }

  next(pin: string, generation: number, step: number = 1): PinmonyDetailSourceCard | undefined {
    if (step !== 1 && step !== -1) return undefined;
    const context: PinmonyDetailSiblingContext | undefined = this.context(pin, generation);
    if (!context) return undefined;
    const cards: PinmonyDetailSourceCard[] = context.source.cards();
    const index: number = cards.findIndex((card: PinmonyDetailSourceCard): boolean =>
      card.pinUrl === pin && card.cardId === context.current.cardId);
    const candidates: PinmonyDetailSourceCard[] = index < 0 ? [] : step === 1 ? cards.slice(index + 1) : cards.slice(0, index).reverse();
    const next: PinmonyDetailSourceCard | undefined = candidates.find((card: PinmonyDetailSourceCard): boolean => card.pinUrl !== pin);
    return next && /^https:\/\/(?:[^/]+\.)?pinterest\.com\/pin\/\d+\/$/i.test(next.pinUrl) &&
      next.pinUrl.split('/')[2] === pin.split('/')[2] ? next : undefined;
  }

  advance(pin: string, generation: number, step: number = 1): PinmonyDetailSourceCard | undefined {
    const next: PinmonyDetailSourceCard | undefined = this.next(pin, generation, step);
    const context: PinmonyDetailSiblingContext | undefined = this.context(pin, generation);
    if (!next || !context) return undefined;
    this.revision++;
    this.contexts.delete(pin);
    this.contexts.set(next.pinUrl, { source: context.source, generation: generation, current: next,
      presentationIdentity: context.presentationIdentity, switched: true });
    return next;
  }

  async prepareReturn(pin: string, generation: number, measure: (cardId: string) => PinmonyDetailReturnRect | undefined,
    waitFrame: () => Promise<void>): Promise<PinmonyDetailReturnRect | undefined> {
    const context: PinmonyDetailSiblingContext | undefined = this.context(pin, generation);
    if (!context?.switched) return undefined;
    const revision: number = this.revision;
    const card: PinmonyDetailSourceCard | undefined = context.source.cards().find((item: PinmonyDetailSourceCard): boolean =>
      item.pinUrl === pin && item.cardId === context.current.cardId);
    if (!card) return undefined;
    // Photo-result sheets already return with a page transition. Restore their
    // own Scroller rather than flying toward a stale, dismissed sheet rectangle.
    if (context.source.pageOnly) { try { context.source.locate(card); } catch (_) {} return undefined; }
    let previous: PinmonyDetailReturnRect | undefined = measure(card.cardId);
    if (previous) { context.source.didLocate?.(); return previous; }
    try { context.source.locate(card); } catch (_) { return undefined; }
    for (let frame: number = 0; frame < 24; frame++) {
      await waitFrame();
      if (revision !== this.revision || !context.source.cards().some((item: PinmonyDetailSourceCard): boolean =>
        item.pinUrl === pin && item.cardId === card.cardId)) return undefined;
      const rect: PinmonyDetailReturnRect | undefined = measure(card.cardId);
      if (rect && previous && Math.abs(rect.x - previous.x) < 0.5 && Math.abs(rect.y - previous.y) < 0.5 &&
        Math.abs(rect.width - previous.width) < 0.5 && Math.abs(rect.height - previous.height) < 0.5) {
        context.source.didLocate?.();
        return rect;
      }
      previous = rect;
    }
    context.source.didLocate?.();
    return undefined;
  }

  clear(): void { this.revision++; this.contexts.clear(); PinmonyDetailSources.clear(); }
}
