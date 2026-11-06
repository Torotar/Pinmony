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
