// A one-shot presentation signal after freshly read content is ready. Live scroll
// bookkeeping does not publish this signal or restart restoration.
export class PinmonyScrollRecovery {
  static publish(kind: string, page: string, offset: number): void {
    if (!Number.isFinite(offset) || offset < 0 || offset > 1000000) return;
    AppStorage.setOrCreate<string>('pinmonyRecoveryScrollKind', kind);
    AppStorage.setOrCreate<string>('pinmonyRecoveryScrollPage', page);
    AppStorage.setOrCreate<number>('pinmonyRecoveryScrollOffset', offset);
    AppStorage.setOrCreate<number>('pinmonyRecoveryScrollRevision', (AppStorage.get<number>('pinmonyRecoveryScrollRevision') || 0) + 1);
  }
  static offset(kind: string, page: string): number | undefined {
    if (AppStorage.get<string>('pinmonyRecoveryScrollKind') !== kind || AppStorage.get<string>('pinmonyRecoveryScrollPage') !== page) return undefined;
    return AppStorage.get<number>('pinmonyRecoveryScrollOffset');
  }
}
