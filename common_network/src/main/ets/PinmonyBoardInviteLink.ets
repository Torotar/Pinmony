export interface PinmonyBoardInviteLink {
  boardUrl: string;
  inviteCode: string;
  inviterUserId: string;
}

export interface PinmonySubmittedLinkTarget {
  kind: 'pin' | 'profile' | 'board-invite';
  pinId?: string;
  profileUrl?: string;
  invitation?: PinmonyBoardInviteLink;
}

// Detect sensitive invitation input even when its key is URL encoded or its value is invalid.
export function hasBoardInviteLinkContext(value: string): boolean {
  if (!/^https?:\/\//i.test(value.trim())) return false;
  const query: number = value.indexOf('?');
  if (query < 0) return false;
  return value.slice(query + 1).split(/[&#]/).some((part: string): boolean => {
    try { return decodeURIComponent(part.split('=')[0]).toLowerCase() === 'invite_code'; }
    catch (_) { return false; }
  });
}

// These parameters grant invitation context: never persist or log this object.
export function parseBoardInviteLink(value: string): PinmonyBoardInviteLink | undefined {
  if (value.length > 4096) return undefined;
  const match: RegExpMatchArray | null = value.trim().match(
    /^https:\/\/(?:(?:www|uk|m)\.)?pinterest\.com\/([A-Za-z0-9_]{1,64})\/([^/?#\s\\]+)\/\?([^#\s\\]+)$/i);
  if (!match || /^(pin|search|resource|resources|settings|login|logout|signup|oauth|api|inbox|messages|updates|notifications|ideas|business|users|_.*)$/i.test(match[1])) return undefined;
  try {
    const slug: string = decodeURIComponent(match[2]);
    if (!slug || /[\/?#\\\s\u0000-\u001f]/.test(slug) || slug === '.' || slug === '..') return undefined;
    const params: Map<string, string> = new Map<string, string>();
    for (const part of match[3].split('&')) {
      const pair: string[] = part.split('=');
      if (pair.length !== 2) return undefined;
      const key: string = decodeURIComponent(pair[0]), item: string = decodeURIComponent(pair[1]);
      if (params.has(key)) return undefined;
      params.set(key, item);
    }
    const code: string = params.get('invite_code') || '', inviter: string = params.get('inviter_user_id') || '';
    if (!/^[A-Za-z0-9_-]{1,256}$/.test(code) || !/^\d{1,30}$/.test(inviter) || (params.get('board_collab_inviter') || '').toLowerCase() !== 'true') return undefined;
    return { boardUrl: 'https://www.pinterest.com/' + match[1] + '/' + encodeURIComponent(slug) + '/', inviteCode: code, inviterUserId: inviter };
  } catch (_) { return undefined; }
}
