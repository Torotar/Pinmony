export interface PinmonyDescriptionPart { text: string; query: string; }

// Keep the original description intact. Only explicit #tags become search links.
export function splitDescriptionTags(description: string): PinmonyDescriptionPart[] {
  const parts: PinmonyDescriptionPart[] = [];
  const pattern: RegExp = /#[\p{L}\p{N}_][\p{L}\p{N}\p{M}_]*/gu;
  let offset: number = 0;
  let match: RegExpExecArray | null = pattern.exec(description);
  while (match) {
    const prefix: string = description.slice(Math.max(0, match.index - 1), match.index);
    if (!prefix || !/[\p{L}\p{N}\p{M}_#]/u.test(prefix)) {
      if (match.index > offset) parts.push({ text: description.slice(offset, match.index), query: '' });
      const tag: string = match[0];
      parts.push({ text: tag, query: tag.length <= 301 ? tag.slice(1) : '' });
      offset = match.index + tag.length;
    }
    match = pattern.exec(description);
  }
  if (offset < description.length) parts.push({ text: description.slice(offset), query: '' });
  return parts;
}

export function descriptionTagSearchUrl(pin: string, description: string, query: string): string {
  const origin: RegExpMatchArray | null = pin.match(/^https:\/\/(?:www|uk)\.pinterest\.com(?=\/pin\/\d+\/$)/);
  if (!origin || !query || !splitDescriptionTags(description).some((part: PinmonyDescriptionPart): boolean =>
    part.query === query)) return '';
  return origin[0] + '/search/pins/?q=' + encodeURIComponent(query);
}
