import { PinmonyI18n } from 'common_foundation';
import { PinmonyTaskRegistry } from 'common_foundation';
import { PinmonyInboxStore } from '../stores/PinmonyInboxStore';
import { PinmonyBoardInvitation, PinmonyBoardInvitations } from '../models/PinmonyBoardInvitation';

export interface PinmonyBoardInvitationPorts {
  nativeEnabled?: () => boolean;
  nativeOpen?: (preview: boolean) => Promise<void>;
  nativePause?: () => void;
  nativeAccept?: () => Promise<void>;
  authenticated: () => boolean;
  foreground: () => boolean;
  page: () => string;
  username: () => string;
  avatar: () => string;
  script: () => string;
  runScript: (script: string) => Promise<string>;
  jsonText: (value: string) => string;
  feedback: (message: string) => void;
}

export class PinmonyBoardInvitationController {
  private readonly store: PinmonyInboxStore;
  private readonly ports: PinmonyBoardInvitationPorts;
  private readonly tasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private generation: number = 0;
  private reading: boolean = false;
  private previewMode: boolean = false;
  constructor(store: PinmonyInboxStore, ports: PinmonyBoardInvitationPorts) { this.store = store; this.ports = ports; }
  pause(): void { this.ports.nativePause?.(); this.generation++; this.tasks.invalidate(); this.reading = false; }
  clearPreview(): void {
    this.pause(); this.store.boardInvitationToken++; this.store.boardInvitationPreview = undefined;
    this.store.invitationReadPage = ''; this.store.invitationBannerVisible = false;
    this.store.invitationBusy = false; this.store.joinedBoardAvatar = '';
  }
  reset(): void { this.clearPreview(); this.store.boardInvitations = undefined; this.store.invitationAllVisible = false; }
  preparePreview(item: PinmonyBoardInvitation): boolean {
    if (!this.ports.authenticated() || !this.ports.foreground() || !this.validItem(item)) return false;
    this.clearPreview(); this.store.boardInvitationPreview = item;
    this.store.invitationBannerVisible = true; this.store.invitationBusy = true; this.store.invitationAllVisible = false;
    return true;
  }
  private current(token: number, page: string, generation: number): boolean {
    return generation === this.generation && token === this.store.boardInvitationToken &&
      this.ports.authenticated() && this.ports.foreground() && page === this.ports.page();
  }
  async open(preview: boolean = false): Promise<void> {
    if(this.ports.nativeEnabled?.()){await this.ports.nativeOpen?.(preview);return;}
    if (!this.ports.authenticated() || !this.ports.foreground() || (preview && !this.store.boardInvitationPreview)) return;
    this.pause(); this.previewMode = preview;
    const token: number = ++this.store.boardInvitationToken;
    const page: string = this.ports.page(), generation: number = this.generation;
    this.store.invitationReadPage = page;
    if (!preview) this.store.boardInvitations = { token: token, page: page, loading: true, busy: false, uncertain: false, error: '', feedback: '', items: [] };
    else this.store.invitationBusy = true;
    try {
      await this.ports.runScript(this.ports.script() + 'window.PinmonyBoardInvitations.open(' + token.toString() + ',' +
        JSON.stringify(preview ? this.store.boardInvitationPreview : null) + ',' + JSON.stringify(this.ports.username()) + ')');
      if (this.current(token, page, generation)) this.poll(token, preview);
    } catch (_) { if (this.current(token, page, generation)) this.fail(preview, PinmonyI18n.message("pm_unable_to_load_board_invitations_4d08df75")); }
  }
  resume(): void {
    if(this.ports.nativeEnabled?.()){if(this.store.invitationReadPage === this.ports.page())this.ports.nativeOpen?.(!!this.store.boardInvitationPreview);return;}
    if (this.store.invitationReadPage && this.store.invitationReadPage === this.ports.page()) this.poll(this.store.boardInvitationToken, this.previewMode);
  }
  private validItem(item: PinmonyBoardInvitation): boolean {
    return !!item && /^\d{1,30}$/.test(item.boardId) && /^\d{1,30}$/.test(item.invitedUser) &&
      /^https:\/\/(?:www|uk)\.pinterest\.com\/[^/?#]+\/[^/?#]+\/$/.test(item.boardUrl) &&
      typeof item.boardName === 'string' && typeof item.inviter === 'string' && typeof item.invitedAvatar === 'string' &&
      typeof item.inviterAvatar === 'string' && typeof item.imageUrl === 'string' && typeof item.createdAt === 'string' &&
      (item.status === 'new' || item.status === 'accepted');
  }
  private fail(preview: boolean, error: string): void {
    if (preview) { this.store.invitationBusy = true; this.ports.feedback(error + PinmonyI18n.message("pm_preview_again_8b57e592")); }
    else if (this.store.boardInvitations) {
      const state: PinmonyBoardInvitations = this.store.boardInvitations;
      this.store.boardInvitations = { token: state.token, page: state.page, loading: false, busy: state.busy,
        uncertain: state.uncertain, error: error, feedback: state.feedback, items: state.items };
    }
  }
  poll(token: number, preview: boolean): void {
    if(this.ports.nativeEnabled?.())return;
    const page: string = this.store.invitationReadPage, generation: number = this.generation;
    if (this.reading || !this.current(token, page, generation)) return;
    this.tasks.invalidate(); this.reading = true;
    this.ports.runScript('JSON.stringify(window.PinmonyBoardInvitations && window.PinmonyBoardInvitations.read(' + token.toString() + '))')
      .then((raw: string): void => {
        if (!this.current(token, page, generation)) return;
        const state: PinmonyBoardInvitations | null = JSON.parse(this.ports.jsonText(raw)) as PinmonyBoardInvitations | null;
        if (!state || state.token !== token || state.page !== page || typeof state.loading !== 'boolean' || typeof state.busy !== 'boolean' ||
            typeof state.uncertain !== 'boolean' || typeof state.error !== 'string' || typeof state.feedback !== 'string' ||
            !Array.isArray(state.items) || state.items.length > 100 || !state.items.every((item: PinmonyBoardInvitation): boolean => this.validItem(item))) {
          this.fail(preview, PinmonyI18n.message("pm_unable_to_load_invitation_status_3b7db431")); return;
        }
        if (preview) {
          const item: PinmonyBoardInvitation | undefined = state.items[0];
          const expected: PinmonyBoardInvitation | undefined = this.store.boardInvitationPreview;
          if (!item || !expected || item.boardId !== expected.boardId || item.boardUrl !== expected.boardUrl || item.invitedUser !== expected.invitedUser) {
            this.fail(true, PinmonyI18n.message("pm_invitation_status_mismatch_5dd76795")); return;
          }
          this.store.invitationBusy = state.loading || state.busy || state.uncertain || !!state.error;
          if (item.status === 'accepted' && expected.status !== 'accepted') {
            this.store.boardInvitationPreview = item; this.store.invitationBannerVisible = false;
            this.store.joinedBoardAvatar = item.invitedAvatar || this.ports.avatar();
            if (state.feedback) this.ports.feedback(state.feedback);
          }
          if (state.error) { this.ports.feedback(state.error); return; }
        } else this.store.boardInvitations = state;
        if (state.loading || state.busy) this.tasks.timeout((): void => this.poll(token, preview), 250);
      }).catch((): void => { if (this.current(token, page, generation)) this.fail(preview, PinmonyI18n.message("pm_unable_to_load_invitation_status_3b7db431")); })
      .finally((): void => { if (generation === this.generation) this.reading = false; });
  }
  accept(): void {
    if(this.ports.nativeEnabled?.()){this.ports.nativeAccept?.();return;}
    const token: number = this.store.boardInvitationToken, page: string = this.store.invitationReadPage;
    if (!this.current(token, page, this.generation) || this.store.invitationBusy || !this.store.invitationBannerVisible ||
        this.store.boardInvitationPreview?.status !== 'new' || this.store.boardInvitationPreview.boardUrl !== page) return;
    this.pause();
    const generation: number = this.generation;
    this.store.invitationBusy = true;
    this.ports.runScript('window.PinmonyBoardInvitations && window.PinmonyBoardInvitations.accept(' + token.toString() + ')')
      .then((): void => { if (this.current(token, page, generation)) this.poll(token, true); })
      .catch((): void => { if (this.current(token, page, generation)) this.fail(true, PinmonyI18n.message("pm_invitation_acceptance_not_confirmed_28de5619")); });
  }
}
