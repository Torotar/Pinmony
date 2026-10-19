import { PinmonyI18n } from 'common_foundation';
import { PinmonyBoardStore } from '../stores/PinmonyBoardStore';
import { PinmonyBoardDetail, PinmonyBoardPin } from '../models/PinmonyBoardDetail';
import { boardVisiblePins } from '../services/PinmonyBoardPresentation';
export interface PinmonyBoardOperationsPorts {
  foreground: () => boolean;
  epoch: () => number;
  document: () => string;
  currentBoard: () => string;
  movePage: () => string;
  clearMovePage: () => void;
  hasDetail: () => boolean;
  returnTarget: (page: string) => void;
  load: (page: string) => void;
  reload: () => void;
  cancelled: (pin: string) => boolean;
  retain: (board: PinmonyBoardDetail) => void;
  rememberPin: (pin: string, page: string) => void;
  runScript: (script: string) => Promise<string>;
  feedback: (message: string) => void;
}
interface BoardAction { action: string; }
export class PinmonyBoardOperationsController {
  private readonly store: PinmonyBoardStore;
  private readonly ports: PinmonyBoardOperationsPorts;
  private generation: number = 0;
  private dispatching: boolean = false;
  constructor(store: PinmonyBoardStore, ports: PinmonyBoardOperationsPorts) { this.store = store; this.ports = ports; }
  pause(): void { this.generation++; this.dispatching = false; }
  operate(method: string, id: string = ''): void {
    if (!this.ports.foreground() || !['open', 'more', 'retry', 'refresh', 'flow'].includes(method)) return;
    const board: PinmonyBoardDetail | undefined = this.store.boardDetail;
    if (method === 'flow' && board?.pageKey === this.ports.movePage()) {
      try {
        const action: BoardAction = JSON.parse(id) as BoardAction;
        if (action.action === 'select') id = JSON.stringify({ action: 'close' });
        if (action.action === 'select' || action.action === 'close') this.ports.clearMovePage();
      } catch (_) { return; }
    }
    if (this.store.presentationOnly) {
      if (method === 'retry' && board && !this.ports.hasDetail()) {
        board.error = ''; if (!board.ready) board.loading = true;
        this.ports.returnTarget(board.pageKey);
      }
      return;
    }
    if (this.store.pendingBoardUrl) {
      if (method === 'retry' && board) {
        try { this.ports.load(board.pageKey); } catch (_) { this.ports.feedback(PinmonyI18n.message('无法重新打开图板，请重试')); }
      }
      return;
    }
    if (!board || this.ports.currentBoard() !== board.pageKey || this.dispatching) return;
    if (method === 'refresh' && (board.refreshing || board.loading)) return;
    if (!board.session) { if (method === 'retry') this.ports.reload(); return; }
    if (method === 'open') {
      if (boardVisiblePins(board).some((pin: PinmonyBoardPin): boolean => pin.id === id && this.ports.cancelled(pin.pinUrl))) return;
      this.ports.retain(board);
      const target: PinmonyBoardPin | undefined = boardVisiblePins(board).find((pin: PinmonyBoardPin): boolean => pin.id === id);
      this.ports.rememberPin(target?.pinUrl || '', board.pageKey);
    }
    const session: number = board.session;
    const generation: number = this.generation, epoch: number = this.ports.epoch(), document: string = this.ports.document();
    const current = (): boolean => generation === this.generation && epoch === this.ports.epoch() && this.ports.foreground() &&
      document === this.ports.document() && this.store.boardDetail?.session === session && this.ports.currentBoard() === board.pageKey;
    this.dispatching = true;
    this.ports.runScript('window.PinmonyBoardApi && window.PinmonyBoardApi.' + method + '(' + session.toString() + ',' +
      JSON.stringify(board.pageKey) + (method === 'open' || method === 'flow' ? ',' + JSON.stringify(id) : '') + ')')
      .then((result: string): void => {
        if (current() && method === 'open' && result !== 'true' && result !== '"true"') this.ports.feedback(PinmonyI18n.message('当前 Pin 图不可用，请重试'));
      }).catch((): void => { if (current()) this.ports.feedback(PinmonyI18n.message('图板接口不可用，请重试')); })
      .finally((): void => { if (generation === this.generation) this.dispatching = false; });
  }
}
