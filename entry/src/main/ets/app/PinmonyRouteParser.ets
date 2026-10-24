export class PinmonyRouteParser {
  static pinIdentity(value: string): string {
    const match: RegExpMatchArray | null = value.match(/\/pin\/(\d+)(?:\/|$)/i);
    return match ? match[1] : '';
  }

  static externalSourceUrl(value: string): string {
    const match: RegExpMatchArray | null = value.match(/^https:\/\/([^\/?#\s]+)(?:[\/?#]|$)/i);
    if (!match || /[@]/.test(match[1]) || /(^|\.)pinterest\.com$|(^|\.)pinimg\.com$|(^|\.)pin\.it$/i.test(match[1])) return '';
    return value;
  }

  static inboxUrlFromAddress(address: string): string {
    const match: RegExpMatchArray | null = address.match(
      /^(https:\/\/(?:[^/]+\.)?pinterest\.com)\/(messages|inbox|updates|notifications)\/?(?:[?#]|$)/i);
    return match ? match[1] + '/' + match[2] + '/' : '';
  }

  static searchUrlFromAddress(address: string): string {
    const match: RegExpMatchArray | null = address.match(
      /^(https:\/\/(?:[^/]+\.)?pinterest\.com\/search(?:\/[^?#]*)?\/?(?:\?[^#]*)?)/i);
    return match ? match[1] : '';
  }

  static profileUrlFromAddress(address: string): string {
    if (PinmonyRouteParser.inboxUrlFromAddress(address)) return '';
    const match: RegExpMatchArray | null = address.match(
      /^(https:\/\/(?:[^/]+\.)?pinterest\.com)\/([^/?#]+)(?:\/(_saved|_created))?\/?(?:[?#]|$)/i);
    if (match && !/^(pin|search|messages|inbox|login|signup|ideas|today|settings|edit)$/i.test(match[2])) {
      return match[1] + '/' + match[2] + '/';
    }
    return '';
  }

  static boardUrlFromAddress(address: string): string {
    const match: RegExpMatchArray | null = address.match(
      /^(https:\/\/(?:[^/]+\.)?pinterest\.com)\/([^/?#]+)\/([^/?#]+)\/?(?:[?#]|$)/i);
    if (!match || /^_|^(pin|users|search|ideas|today|settings|edit|messages|inbox|login|signup|business|explore)$/i.test(match[2]) ||
        /^_|^(followers|following)$/i.test(match[3])) return '';
    return match[1] + '/' + match[2] + '/' + match[3] + '/';
  }

  static extractPinUrl(value: string): string {
    let decoded: string = value;
    for (let attempt: number = 0; attempt < 3; attempt++) {
      const full: RegExpMatchArray | null = decoded.match(/https?:\/\/(?:[a-z0-9-]+\.)?pinterest\.com\/pin\/\d+\/?/i);
      if (full) {
        return full[0];
      }
      const short: RegExpMatchArray | null = decoded.match(/https?:\/\/(?:www\.)?pin\.it\/[a-z0-9]+/i);
      if (short) {
        return short[0];
      }
      try {
        const next: string = decodeURIComponent(decoded);
        if (next === decoded) {
          break;
        }
        decoded = next;
      } catch (error) {
        break;
      }
    }
    return '';
  }

  static isExternalShareTarget(url: string): boolean {
    return /^(sms:|fb-messenger:\/\/|facebook-messenger:\/\/|whatsapp:\/\/)/i.test(url) ||
      /^https?:\/\/(?:[^/]+\.)?(?:twitter\.com|x\.com|facebook\.com|fb\.com|messenger\.com|whatsapp\.com|wa\.me)(?:\/|\?|$)/i.test(url);
  }

}
