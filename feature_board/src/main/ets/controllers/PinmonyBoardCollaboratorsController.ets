import { PinmonyI18n } from 'common_foundation';
import { PinmonyTaskRegistry } from 'common_foundation';
import { PinmonyBoardDetail } from '../models/PinmonyBoardDetail';
import { PinmonyBoardCollaborators } from '../models/PinmonyBoardCollaborators';

interface BoardPermissionValues { permission: number; invites: boolean; }

export interface PinmonyBoardCollaboratorsPorts {
  board: () => PinmonyBoardDetail | undefined;
  currentPage: () => string;
  canOpen: () => boolean;
  foreground: () => boolean;
  state: () => PinmonyBoardCollaborators | undefined;
  setState: (state: PinmonyBoardCollaborators | undefined) => void;
  token: () => number;
  nextToken: () => number;
  runScript: (script: string) => Promise<string>;
  jsonText: (value: string) => string;
  feedback: (value: string) => void;
  trace: () => void;
}

export class PinmonyBoardCollaboratorsController {
  private readonly tasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private generation: number = 0;
  private polling: boolean = false;

  private readonly ports: PinmonyBoardCollaboratorsPorts;
  constructor(ports: PinmonyBoardCollaboratorsPorts) { this.ports = ports; }

  pause(): void {
    this.generation++;
    this.polling = false;
    this.tasks.invalidate();
  }

  private current(token: number, generation: number): boolean {
    const state: PinmonyBoardCollaborators | undefined = this.ports.state();
    return generation === this.generation && token === this.ports.token() && !!state &&
      state.token === token && state.page === this.ports.currentPage() && this.ports.foreground();
  }

  async open(): Promise<void> {
    const board: PinmonyBoardDetail | undefined = this.ports.board();
    if (!this.ports.canOpen() || !(board?.editable || board?.collaborator) || !board?.ready || !board.session ||
        (board.flow?.phase && board.flow.phase !== 'edit') || board.flow?.loading || board.flow?.busy ||
        board.flow?.uncertain || this.ports.currentPage() !== board.pageKey || this.ports.state()) return;
    this.pause();
    this.ports.trace();
    const token: number = this.ports.nextToken();
    const generation: number = this.generation;
    this.ports.setState({ token: token, page: board.pageKey, phase: 'members', loading: true, busy: false,
      uncertain: false, error: '', feedback: '', permission: 1, invites: false, users: [], suggestions: [] });
    try {
      const opened: string = await this.ports.runScript('window.PinmonyBoardApi && window.PinmonyBoardApi.collaboratorsOpen(' +
        board.session.toString() + ',' + JSON.stringify(board.pageKey) + ',' + token.toString() + ')');
      if (!this.current(token, generation)) return;
      if (opened !== 'true' && opened !== '"true"') throw new Error('unavailable');
      this.poll(token);
    } catch (_) {
      const state: PinmonyBoardCollaborators | undefined = this.ports.state();
      if (state && this.current(token, generation)) {
        state.loading = false; state.error = PinmonyI18n.message('合作用户入口暂不可用，请返回重试');
        this.ports.setState(state);
      }
    }
  }

  poll(token: number): void {
    const generation: number = this.generation;
    if (this.polling || !this.current(token, generation)) return;
    this.tasks.invalidate();
    this.polling = true;
    this.ports.runScript('JSON.stringify(window.PinmonyBoardApi && window.PinmonyBoardApi.collaboratorsRead(' + token.toString() + '))')
      .then((raw: string): void => {
        if (!this.current(token, generation)) return;
        const state: PinmonyBoardCollaborators | null = JSON.parse(this.ports.jsonText(raw)) as PinmonyBoardCollaborators | null;
        if (!state || state.token !== token || state.page !== this.ports.currentPage() ||
            !['members', 'invite', 'permissions'].includes(state.phase) || !Array.isArray(state.users) ||
            !Array.isArray(state.suggestions) || state.users.length > 500 || state.suggestions.length > 100) {
          this.close(); return;
        }
        if (state.feedback && state.feedback !== this.ports.state()?.feedback) this.ports.feedback(state.feedback);
        this.ports.setState(state);
        this.tasks.timeout((): void => this.poll(token), 250);
      }).catch((): void => {
        const state: PinmonyBoardCollaborators | undefined = this.ports.state();
        if (state && this.current(token, generation)) {
          if(state.busy){state.busy = false;state.uncertain = true;state.error = PinmonyI18n.message('操作结果未确认，请关闭后重新查看，勿重复提交');}
          else state.error = PinmonyI18n.message('合作用户状态读取失败，请返回重新查看');
          state.loading = false;
          this.ports.setState(state);
        }
      }).finally((): void => { if (generation === this.generation) this.polling = false; });
  }

  action(action: string, value: string): void {
    const state: PinmonyBoardCollaborators | undefined = this.ports.state();
    if (!state || state.busy || state.uncertain || !this.current(state.token, this.generation)) return;
    let encoded: string = JSON.stringify(value);
    if (action === 'save') {
      try {
        const permission: BoardPermissionValues = JSON.parse(value) as BoardPermissionValues;
        if (state.owner !== true || ![0, 1].includes(permission.permission) || typeof permission.invites !== 'boolean') return;
        encoded = JSON.stringify(permission);
      } catch (_) { return; }
    }
    this.ports.runScript('window.PinmonyBoardApi && window.PinmonyBoardApi.collaboratorsAction(' +
      state.token.toString() + ',' + JSON.stringify(action) + ',' + encoded + ')').catch(() => {});
  }

  close(): void {
    if (this.ports.state()?.busy) return;
    const token: number = this.ports.state()?.token || 0;
    this.pause();
    this.ports.nextToken(); this.ports.setState(undefined);
    this.ports.runScript('window.PinmonyBoardApi && window.PinmonyBoardApi.collaboratorsAction(' +
      token.toString() + ',"close","")').catch(() => {});
  }
}
