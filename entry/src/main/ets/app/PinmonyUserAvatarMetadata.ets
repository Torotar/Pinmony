// Only inherit metadata omitted by a partial response for the same verified user.
// An explicit invalid value stays invalid; never invent a color from the name.
export interface PinmonyAvatarUserMetadata {
  id?: string;
  avatar_color_index?: number;
}
export function inheritUserAvatarColor(target: PinmonyAvatarUserMetadata | undefined,
  known: (PinmonyAvatarUserMetadata | undefined)[]): void {
  if (!target || !/^\d{1,40}$/.test(target.id || '') || target.avatar_color_index !== undefined) return;
  const source: PinmonyAvatarUserMetadata | undefined = known.find((user: PinmonyAvatarUserMetadata | undefined): boolean =>
    user?.id === target.id && Number.isInteger(user?.avatar_color_index) && user!.avatar_color_index! >= 1 && user!.avatar_color_index! <= 10);
  if (source) target.avatar_color_index = source.avatar_color_index;
}
