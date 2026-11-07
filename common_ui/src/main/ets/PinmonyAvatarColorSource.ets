export interface PinmonyAvatarColorIdentity {
  profileUrl: string;
  userId: string;
  username: string;
}
export type PinmonyAvatarColorListener = (color: number) => void;
export type PinmonyAvatarColorResolver = (identity: PinmonyAvatarColorIdentity, changed: PinmonyAvatarColorListener) => (() => void);
// Presentation-only port. Website requests and caches belong to the product service.
export class PinmonyAvatarColorSource {
  private static resolver: PinmonyAvatarColorResolver | undefined = undefined;
  private static listeners: Set<(reload: boolean) => void> = new Set<(reload: boolean) => void>();
  static connect(resolver: PinmonyAvatarColorResolver | undefined): void {
    PinmonyAvatarColorSource.resolver = resolver; PinmonyAvatarColorSource.invalidate(true);
  }
  static invalidate(reload: boolean = false): void { PinmonyAvatarColorSource.listeners.forEach((listener: (reload: boolean) => void): void => listener(reload)); }
  static observe(listener: (reload: boolean) => void): () => void {
    PinmonyAvatarColorSource.listeners.add(listener); return (): void => { PinmonyAvatarColorSource.listeners.delete(listener); };
  }
  static read(identity: PinmonyAvatarColorIdentity, changed: PinmonyAvatarColorListener): () => void {
    return PinmonyAvatarColorSource.resolver ? PinmonyAvatarColorSource.resolver(identity,changed) : (): void => {};
  }
}
