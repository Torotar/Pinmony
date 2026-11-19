export interface PinmonyBoardInviteLink {
  boardUrl: string;
  inviteCode: string;
  inviterUserId: string;
}

export interface PinmonySubmittedLinkTarget {
  kind: 'pin' | 'profile' | 'board' | 'own-shared-board' | 'board-invite';
  pinId?: string;
  profileUrl?: string;
  boardUrl?: string;
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

// Accept only a complete board permalink; strip sharing/tracking parameters.
export function parseBoardPermalink(value: string): string {
  if (value.length > 2048 || hasBoardInviteLinkContext(value)) return '';
  const match: RegExpMatchArray | null = value.trim().match(
    /^https?:\/\/(?:(?:www|uk|m)\.)?pinterest\.com\/([a-z0-9_]{1,64})\/([a-z0-9%-][a-z0-9_%.-]{0,255})\/?(?:[?#][^\s\\]*)?$/i);
  if (!match || /^(pin|search|messages|inbox|updates|notifications|login|logout|signup|ideas|today|settings|edit|business|explore|users|help|about|privacy|terms|resource|resources|oauth|api|board|boards|_.*)$/i.test(match[1])) return '';
  try {
    const slug: string = decodeURIComponent(match[2]);
    if (/[\/\\%?#\s\x00-\x1f\x7f]/.test(slug) || slug.startsWith('_') || slug === '.' || slug === '..' || /^(followers|following)$/i.test(slug)) return '';
  } catch (_) { return ''; }
  return 'https://www.pinterest.com/' + match[1] + '/' + match[2] + '/';
}

// An observed board share redirect, distinct from a collaboration invitation.
// Drop both contextual parameters; only the authenticated owner may open the result.
export function parseOwnSharedBoardRedirect(value: string): string {
  if (value.length > 4096) return '';
  const parts: RegExpMatchArray | null = value.match(/^(https:\/\/[a-z.]+\/[^?#\s]+)\?([^#\s]+)$/i);
  if (!parts) return '';
  if (!/^(?:invite_code=[A-Za-z0-9_-]{1,256}&sender=[A-Za-z0-9_-]{1,256}|sender=[A-Za-z0-9_-]{1,256}&invite_code=[A-Za-z0-9_-]{1,256})$/.test(parts[2])) return '';
  return parseBoardPermalink(parts[1]);
}
