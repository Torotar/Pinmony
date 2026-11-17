// Source pages own order and positioning; detail never merges unrelated feeds.
export interface PinmonyDetailSourceCard {
  pinUrl: string;
  cardId: string;
  entryCardId?: string;
  imageUrl: string;
  imageWidth: number;
  imageHeight: number;
}

export interface PinmonyDetailSource {
  identity: string;
  pageUrl: string;
  session: number;
  pageOnly?: boolean;
  cards: () => PinmonyDetailSourceCard[];
  locate: (card: PinmonyDetailSourceCard) => void;
  didLocate?: () => void;
}

export class PinmonyDetailSources {
  private static pending: PinmonyDetailSource | undefined = undefined;
  private static revision: number = 0;

  static stage(source: PinmonyDetailSource): void {
    PinmonyDetailSources.pending = source;
    const revision: number = ++PinmonyDetailSources.revision;
    // An unavailable/rejected click must not lend its source to a later route.
    Promise.resolve().then((): void => {
      if (revision === PinmonyDetailSources.revision) PinmonyDetailSources.pending = undefined;
    });
  }

  static take(pinUrl: string, cardId: string): PinmonyDetailSource | undefined {
    const source: PinmonyDetailSource | undefined = PinmonyDetailSources.pending;
    PinmonyDetailSources.pending = undefined;
    return source?.cards().some((card: PinmonyDetailSourceCard): boolean =>
      card.pinUrl === pinUrl && (card.entryCardId || card.cardId) === cardId) ? source : undefined;
  }

  static clear(): void { PinmonyDetailSources.revision++; PinmonyDetailSources.pending = undefined; }
}
