import { hashCacheString, PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyBusinessSessionContext } from 'common_session';

export interface PinmonyRecoveryRoute { kind: string; page: string; offset: number; section?: string; }
export interface PinmonyRecoveryState {
  version: number; savedAt: number; account: string; origin: string;
  tab: number; root: string; routes: PinmonyRecoveryRoute[];
  homeOffset: number; searchOffset: number; inboxOffset: number; profileOffset: number;
  homeCategory: string; inboxSection: string; profileSection: string; searchDraft: string;
}
export interface PinmonyPageRecoveryPorts {
  session: () => PinmonyBusinessSessionContext;
  active: () => boolean;
  root: (state: PinmonyRecoveryState) => void;
  rootReady: (state: PinmonyRecoveryState) => boolean;
  rootPosition: (state: PinmonyRecoveryState) => void;
  open: (route: PinmonyRecoveryRoute, parent: string) => boolean;
  ready: (route: PinmonyRecoveryRoute) => boolean;
  position: (route: PinmonyRecoveryRoute) => void;
}

// System Want backup contains route metadata only, never credentials, responses or write jobs.
export class PinmonyPageRecovery {
  private static readonly key: string = 'pinmony.pageRecovery.v1';
  private static provider: (() => PinmonyRecoveryState | undefined) | undefined;
  private static pending: PinmonyRecoveryState | undefined;
  private static epoch: number = 0;
  private static saveAttempt: number = 0;
  private revision: number = 0;
  private timer: number = -1;
  private running: boolean = false;

  static bind(provider: () => PinmonyRecoveryState | undefined): void { PinmonyPageRecovery.provider = provider; }
  static unbind(): void { PinmonyPageRecovery.provider = undefined; }
  static clear(): void {
    if (PinmonyPageRecovery.pending) PinmonyRuntimeLog.info('PageRecovery: phase=discard reason=cleared epoch=' + PinmonyPageRecovery.epoch);
    PinmonyPageRecovery.pending = undefined; PinmonyPageRecovery.epoch++;
  }
  static owner(account: string): string { return hashCacheString(account); }

  static route(kind: string, page: string, origin: string, offset: number = 0): PinmonyRecoveryRoute | undefined {
    if (typeof page !== 'string' || page.length > 4096 || !page.startsWith(origin + '/') || /[\s\\#]/.test(page)) return undefined;
    const path: string = page.slice(origin.length);
    const valid: boolean = kind === 'pin' ? /^\/pin\/\d{1,40}\/$/.test(path) :
      kind === 'profile' ? /^\/[A-Za-z0-9_]+\/(?:_created\/)?$/.test(path) :
      kind === 'chat' ? /^\d{1,40}$/.test(path.slice(1)) :
      kind === 'board' && /^\/[A-Za-z0-9_]+\/[A-Za-z0-9_%~-]+\/$/.test(path) &&
        !/^\/(?:search|pin|settings|ideas|messages|news|business)\//.test(path);
    if (!valid || !Number.isFinite(offset) || offset < 0 || offset > 1000000) return undefined;
    return { kind: kind, page: kind === 'profile' ? page.replace(/_created\/$/, '') : page, offset: offset,
      section: kind === 'profile' && path.endsWith('/_created/') ? 'created' : undefined };
  }

  private static validate(text: string): PinmonyRecoveryState | undefined {
    if (!text || text.length > 32768) return undefined;
    try {
      const state: PinmonyRecoveryState = JSON.parse(text) as PinmonyRecoveryState;
      if (!state || state.version !== 1 || typeof state.savedAt !== 'number' || !Number.isFinite(state.savedAt) ||
          Date.now() - state.savedAt > 7 * 24 * 60 * 60 * 1000 || state.savedAt > Date.now() + 60000 ||
          typeof state.account !== 'string' || !/^[a-f0-9]{32,64}$/.test(state.account) ||
          !/^https:\/\/(?:www|uk)\.pinterest\.com$/.test(state.origin) ||
          !Number.isInteger(state.tab) || state.tab < 0 || state.tab > 3 ||
          typeof state.root !== 'string' || state.root.length > 4096 || !state.root.startsWith(state.origin + '/') ||
          /[\s\\#]/.test(state.root) || !Array.isArray(state.routes) || state.routes.length > 12 ||
          typeof state.searchDraft !== 'string' || state.searchDraft.length > 300 ||
          typeof state.homeCategory !== 'string' || !/^[A-Za-z0-9_-]{0,100}$/.test(state.homeCategory) ||
          !['updates', 'messages'].includes(state.inboxSection) || !['saved', 'created'].includes(state.profileSection)) return undefined;
      const rootPath: string = state.root.slice(state.origin.length);
      if (!(state.tab === 0 ? rootPath === '/' : state.tab === 1 ? /^\/search\/(?:[a-z_]+\/)?(?:\?[^#]*)?$/.test(rootPath) :
        state.tab === 2 ? ['/inbox/', '/news/', '/messages/'].includes(rootPath) : /^\/[A-Za-z0-9_]+\/(?:_created\/)?$/.test(rootPath))) return undefined;
      if (![state.homeOffset, state.searchOffset, state.inboxOffset, state.profileOffset].every((offset: number): boolean =>
        typeof offset === 'number' && Number.isFinite(offset) && offset >= 0 && offset <= 1000000)) return undefined;
      if (!state.routes.every((route: PinmonyRecoveryRoute): boolean => !!route && !!PinmonyPageRecovery.route(route.kind, route.page, state.origin, route.offset))) return undefined;
      const routes: PinmonyRecoveryRoute[] = [];
      for (const route of state.routes) {
        const normalized: PinmonyRecoveryRoute = PinmonyPageRecovery.route(route.kind, route.page, state.origin, route.offset)!;
        if (route.section !== undefined) {
          if (route.kind !== 'profile' || !['saved', 'created'].includes(route.section)) return undefined;
          normalized.section = route.section;
        }
        routes.push(normalized);
      }
      state.routes = routes;
      return state;
    } catch (_) { return undefined; }
  }

  static save(): string {
    const attempt: number = ++PinmonyPageRecovery.saveAttempt;
    const startedAt: number = Date.now();
    try {
      if (!PinmonyPageRecovery.provider) {
        PinmonyRuntimeLog.info('PageRecovery: phase=save-skipped attempt=' + attempt + ' reason=no-provider');
        return '';
      }
      const state: PinmonyRecoveryState | undefined = PinmonyPageRecovery.provider?.();
      if (!state) {
        PinmonyRuntimeLog.info('PageRecovery: phase=save-skipped attempt=' + attempt + ' reason=no-state');
        return '';
      }
      const text: string = state ? JSON.stringify(state) : '';
      if (!PinmonyPageRecovery.validate(text)) {
        PinmonyRuntimeLog.warn('PageRecovery: phase=save-rejected attempt=' + attempt + ' reason=invalid-or-oversize chars=' + text.length);
        return '';
      }
      PinmonyRuntimeLog.info('PageRecovery: phase=snapshot-ready attempt=' + attempt + ' tab=' + state.tab +
        ' depth=' + state.routes.length + ' chars=' + text.length + ' draftChars=' + state.searchDraft.length +
        ' elapsedMs=' + (Date.now() - startedAt));
      return text;
    } catch (_) {
      PinmonyRuntimeLog.warn('PageRecovery: phase=save-failed attempt=' + attempt + ' reason=capture-or-serialize');
      return '';
    }
  }
  static receive(parameters: Record<string, Object> | undefined, recovered: boolean): void {
    PinmonyPageRecovery.epoch++;
    PinmonyPageRecovery.pending = undefined;
    const epoch: number = PinmonyPageRecovery.epoch;
    if (!recovered || !parameters || parameters['pinmonyMessageNotice']) {
      const reason: string = !recovered ? 'ordinary-or-external-launch' : !parameters ? 'no-parameters' : 'notice-priority';
      PinmonyRuntimeLog.info('PageRecovery: phase=receive-skipped epoch=' + epoch + ' reason=' + reason);
      return;
    }
    const text: Object | undefined = parameters[PinmonyPageRecovery.key];
    if (typeof text === 'string') PinmonyPageRecovery.pending = PinmonyPageRecovery.validate(text);
    const state: PinmonyRecoveryState | undefined = PinmonyPageRecovery.pending;
    if (state) PinmonyRuntimeLog.info('PageRecovery: phase=received epoch=' + epoch + ' tab=' + state.tab +
      ' depth=' + state.routes.length + ' ageMs=' + (Date.now() - state.savedAt));
    else PinmonyRuntimeLog.warn('PageRecovery: phase=receive-rejected epoch=' + epoch +
      ' reason=' + (typeof text === 'string' ? 'invalid-or-expired' : 'missing-state'));
  }
  static parameterKey(): string { return PinmonyPageRecovery.key; }

  cancel(reason: string = 'caller'): void {
    if (this.running) PinmonyRuntimeLog.info('PageRecovery: phase=cancelled revision=' + this.revision + ' reason=' + reason);
    this.revision++; this.running = false;
    if (this.timer >= 0) clearTimeout(this.timer);
    this.timer = -1;
  }
  start(ports: PinmonyPageRecoveryPorts): boolean {
    const state: PinmonyRecoveryState | undefined = PinmonyPageRecovery.pending;
    const session: PinmonyBusinessSessionContext = ports.session();
    if (!state || !session.authenticated || !session.accountId || !ports.active() || this.running) return false;
    PinmonyPageRecovery.pending = undefined;
    if (state.account !== PinmonyPageRecovery.owner(session.accountId) || state.origin !== session.origin) {
      PinmonyRuntimeLog.info('PageRecovery: phase=discard epoch=' + PinmonyPageRecovery.epoch + ' reason=owner-or-origin-mismatch');
      return false;
    }
    this.cancel(); this.running = true;
    const revision: number = this.revision;
    const epoch: number = PinmonyPageRecovery.epoch;
    const recoveryStartedAt: number = Date.now();
    PinmonyRuntimeLog.info('PageRecovery: phase=start epoch=' + epoch + ' revision=' + revision +
      ' tab=' + state.tab + ' depth=' + state.routes.length);
    const account: string = session.accountId, generation: number = session.generation, origin: string = session.origin;
    const live = (): boolean => epoch === PinmonyPageRecovery.epoch && revision === this.revision && ports.active() && ports.session().authenticated &&
      ports.session().accountId === account && ports.session().generation === generation && ports.session().origin === origin;
    let index: number = -1, opened: boolean = false, startedAt: number = Date.now();
    try { ports.root(state); } catch (_) { this.cancel('root-exception'); return false; }
    const advance = (): void => {
      this.timer = -1;
      if (!live()) { this.cancel('context-changed'); return; }
      if (Date.now() - startedAt > 20000) { this.cancel('ready-timeout'); return; }
      try {
        if (index === -1) {
          if (!ports.rootReady(state)) { this.timer = setTimeout(advance, 80); return; }
          ports.rootPosition(state); index = 0;
          PinmonyRuntimeLog.info('PageRecovery: phase=root-positioned epoch=' + epoch + ' revision=' + revision + ' tab=' + state.tab);
        }
        if (index >= state.routes.length) {
          this.running = false;
          PinmonyRuntimeLog.info('PageRecovery: phase=completed epoch=' + epoch + ' revision=' + revision +
            ' depth=' + state.routes.length + ' elapsedMs=' + (Date.now() - recoveryStartedAt) + ' frameConfirmed=false');
          return;
        }
        const route: PinmonyRecoveryRoute = state.routes[index];
        if (!opened) {
          if (!ports.open(route, index === 0 ? state.root : state.routes[index - 1].page)) { this.cancel('route-unavailable'); return; }
          PinmonyRuntimeLog.info('PageRecovery: phase=route-open epoch=' + epoch + ' revision=' + revision + ' index=' + index + ' kind=' + route.kind);
          opened = true; startedAt = Date.now();
        }
        if (ports.ready(route)) {
          ports.position(route);
          PinmonyRuntimeLog.info('PageRecovery: phase=route-positioned epoch=' + epoch + ' revision=' + revision + ' index=' + index + ' kind=' + route.kind);
          index++; opened = false; startedAt = Date.now();
        }
        this.timer = setTimeout(advance, 80);
      } catch (_) { this.cancel('route-exception'); }
    };
    advance(); return true;
  }
}
