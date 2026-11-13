import { PinmonyI18n } from 'common_foundation';
import { PinmonyLoggedOutAccounts, PinmonySessionAccount } from 'feature_settings';

@Component
export struct PinmonyOtherAccountsLogin {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  @StorageLink('gestureBarHeightPx') private gestureBarHeightPx: number = 0;
  @ObjectLink accounts: PinmonyLoggedOutAccounts;
  @Prop loading: boolean = false;
  private mounted: boolean = false;
  private choosing: boolean = false;
  private appearance: number = 0;
  aboutToAppear(): void { this.appearance++; this.mounted = true; }
  aboutToDisappear(): void { this.appearance++; this.mounted = false; this.choosing = false; }
  private text(key: string): string { return PinmonyI18n.text(key, this.uiLanguage); }
  private choose(): void {
    if (!this.mounted || this.choosing || this.loading || this.accounts.busy || !this.accounts.active) return;
    if (this.accounts.restoreFailed) { void this.accounts.retryRestore(); return; }
    if (this.accounts.uncertain) { void this.accounts.verifySelected(); return; }
    const rows: PinmonySessionAccount[] = this.accounts.accounts;
    if (rows.length === 1) { void this.accounts.choose(rows[0].id); return; }
    if (rows.length < 2) return;
    const appearance: number = this.appearance;
    this.choosing = true;
    this.getUIContext().showActionSheet({
      title: this.text('pm_login_other_account'),
      message: this.text('pm_session_other'),
      sheets: rows.map((account: PinmonySessionAccount): SheetInfo => ({ title: account.name + ' (@' + account.username + ')',
        action: (): void => {
          if (appearance !== this.appearance) return;
          this.choosing = false;
          if (this.mounted && this.accounts.active && rows === this.accounts.accounts && !this.loading) void this.accounts.choose(account.id);
        } })),
      confirm: { value: this.text('pm_cancel_2cd0f3be'), action: (): void => { if (appearance === this.appearance) this.choosing = false; } },
      cancel: (): void => { if (appearance === this.appearance) this.choosing = false; }
    });
  }
  build() {
    Column({ space: 12 }) {
      if (this.accounts.error) {
        Text(PinmonyI18n.render(this.accounts.error, this.uiLanguage)).fontSize(14)
          .fontColor($r('app.color.secondary_text')).width('100%')
      }
      if (this.accounts.accounts.length > 0 || this.accounts.uncertain || this.accounts.restoreFailed) {
        Button(this.text(this.accounts.restoreFailed ? 'pm_retry_b8784c8d' : this.accounts.uncertain ? 'pm_session_verify' : 'pm_login_other_account'), { type: ButtonType.Normal })
        .fontSize(17).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .backgroundColor($r('app.color.accent')).height(48).borderRadius(16).width('100%')
        .enabled(!this.loading && !this.accounts.busy).onClick(() => this.choose())
      }
    }.width('100%').padding({ left: 24, right: 24, top: 12, bottom: this.getUIContext().px2vp(this.gestureBarHeightPx) + 16 })
      .backgroundColor($r('app.color.page_background'))
  }
}
