import { PinmonySearchResult } from '../models/PinmonySearch';

function resultKey(item: PinmonySearchResult): string {
  const pin = item.targetUrl.match(/\/pin\/(\d+)(?:\/|[?#]|$)/i);
  return pin ? item.kind + ':pin:' + pin[1] : item.kind + ':' + item.targetUrl.split('#')[0];
}

export function findSearchResult(results: PinmonySearchResult[], targetUrl: string): PinmonySearchResult | undefined {
  const pin = targetUrl.match(/^https:\/\/(?:[^/]+\.)?pinterest\.com\/pin\/(\d+)(?:\/|[?#]|$)/i);
  return results.find((item: PinmonySearchResult): boolean => item.targetUrl === targetUrl ||
    !!pin && item.kind === 'pin' && resultKey(item) === 'pin:pin:' + pin[1]);
}

// Rebind controls without changing the list the reader left behind.
export function retainSearchResults(previous: PinmonySearchResult[], live: PinmonySearchResult[]): PinmonySearchResult[] {
  const retained: PinmonySearchResult[] = previous.map((item: PinmonySearchResult): PinmonySearchResult => {
    const match: PinmonySearchResult | undefined = live.find((candidate: PinmonySearchResult): boolean =>
      resultKey(candidate) === resultKey(item));
    return { id: match ? match.id : 'cached-search:' + item.targetUrl, kind: item.kind,
      title: match && match.title && !/^(?:标题暂不可用|Pin|图片)$/i.test(match.title) ? match.title : item.title,
      subtitle: item.subtitle, targetUrl: item.targetUrl, imageUrl: item.imageUrl,
      imageWidth: item.imageWidth, imageHeight: item.imageHeight,
      enabled: /^https:\/\/(?:[^/]+\.)?pinterest\.com\//i.test(item.targetUrl) };
  });
  return retained;
}

// A virtualized webpage reports only its mounted window. Keep earlier windows
// and append newly discovered links, regardless of overlap with the old tail.
export function mergeSearchFeedResults(previous: PinmonySearchResult[], live: PinmonySearchResult[]): PinmonySearchResult[] {
  const merged: PinmonySearchResult[] = retainSearchResults(previous, live);
  live.forEach((item: PinmonySearchResult) => {
    if (merged.some((candidate: PinmonySearchResult): boolean => resultKey(candidate) === resultKey(item))) return;
    merged.push({ id: item.id, kind: item.kind, title: item.title, subtitle: item.subtitle,
      targetUrl: item.targetUrl, imageUrl: item.imageUrl, imageWidth: item.imageWidth,
      imageHeight: item.imageHeight, enabled: /^https:\/\/(?:[^/]+\.)?pinterest\.com\//i.test(item.targetUrl) });
  });
  return merged;
}
