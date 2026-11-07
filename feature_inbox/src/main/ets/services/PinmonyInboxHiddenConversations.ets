interface HiddenConversation { origin: string; account: string; conversation: string; }
// Local list presentation only. Never deletes server messages or writes a read receipt.
export class PinmonyInboxHiddenConversations {
  private static rows: HiddenConversation[] = [];
  private static save: ((value: string) => boolean) | undefined = undefined;
  static initialize(value: string, save: (value: string) => boolean): void {
    PinmonyInboxHiddenConversations.save = save;
    PinmonyInboxHiddenConversations.rows = [];
    try {
      if(value.length > 300000)return;
      const rows: HiddenConversation[] = JSON.parse(value) as HiddenConversation[];
      if(!Array.isArray(rows) || rows.length > 1000 || rows.some((row: HiddenConversation): boolean =>
        !row || !PinmonyInboxHiddenConversations.valid(row.origin,row.account,row.conversation)))return;
      PinmonyInboxHiddenConversations.rows = rows;
    } catch (_) {}
  }
  private static valid(origin: string, account: string, conversation: string): boolean {
    return typeof origin === 'string' && /^https:\/\/(?:www|[a-z]{2})\.pinterest\.com$/.test(origin) &&
      typeof account === 'string' && account.length > 0 && account.length <= 128 &&
      typeof conversation === 'string' && /^\d{1,40}$/.test(conversation);
  }
  static hidden(origin: string, account: string, conversation: string): boolean {
    return PinmonyInboxHiddenConversations.rows.some((row: HiddenConversation): boolean =>
      row.origin === origin && row.account === account && row.conversation === conversation);
  }
  static setHidden(origin: string, account: string, conversation: string, hidden: boolean): boolean {
    if(!PinmonyInboxHiddenConversations.valid(origin,account,conversation))return false;
    if(PinmonyInboxHiddenConversations.hidden(origin,account,conversation) === hidden)return true;
    const rows: HiddenConversation[] = PinmonyInboxHiddenConversations.rows.filter((row: HiddenConversation): boolean =>
      row.origin !== origin || row.account !== account || row.conversation !== conversation);
    if(hidden)rows.push({origin:origin,account:account,conversation:conversation});
    if(rows.length > 1000)return false;
    try {
      if(!PinmonyInboxHiddenConversations.save?.(JSON.stringify(rows)))return false;
      PinmonyInboxHiddenConversations.rows = rows;return true;
    } catch (_) { return false; }
  }
}
