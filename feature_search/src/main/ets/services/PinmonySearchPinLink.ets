// Only a complete, trusted Pin URL is a navigation intent. Never extract a URL
// from arbitrary text, credentials, a redirect parameter, or a lookalike host.
export function searchPinLinkIdentity(value: string): string {
  if (value.length > 2048) return '';
  const match: RegExpMatchArray | null = value.trim().match(
    /^https?:\/\/(?:(?:www|uk|m)\.)?pinterest\.com\/pin\/([0-9]{1,30})(?:\/(?:sent\/)?)?(?:[?#][^\s\\]*)?$/i);
  return match ? match[1] : '';
}

export function searchShortPinLink(value: string): string {
  if (value.length > 128) return '';
  const match: RegExpMatchArray | null = value.trim().match(/^https:\/\/(?:www\.)?pin\.it\/([a-z0-9]{1,64})\/?$/i);
  return match ? 'https://pin.it/' + match[1] : '';
}

// Canonical profile only; boards and application routes are not usernames.
export function searchProfileLink(value: string): string {
  if (value.length > 2048) return '';
  const match: RegExpMatchArray | null = value.trim().match(
    /^https?:\/\/(?:(?:www|uk|m)\.)?pinterest\.com\/([a-z0-9_]{1,64})(?:\/(?:_(?:saved|created)\/?)?)?(?:[?#][^\s\\]*)?$/i);
  if (!match || /^(pin|search|messages|inbox|updates|notifications|login|logout|signup|ideas|today|settings|edit|business|explore|users|help|about|privacy|terms|resource|resources|oauth|api|_.*)$/i.test(match[1])) return '';
  return 'https://www.pinterest.com/' + match[1] + '/';
}
