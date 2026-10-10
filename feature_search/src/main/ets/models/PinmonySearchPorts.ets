export interface PinmonySearchPorts {
  currentPageKey: () => string;
  isActive: () => boolean;
  preservingPinSearch: () => boolean;
  runScript: (script: string) => Promise<string>;
  ensureContext: (requireData: boolean, allowedSheet?: string, isCurrent?: () => boolean) => Promise<boolean>;
  markInteracted: () => void;
  clearTabGuard: (reason: string) => void;
  finishPull: () => void;
  recordPageKey: (pageKey: string) => void;
  setDetailReturn: (pageKey: string) => void;
  navigateSearch: (target: string, source: string) => void;
  navigateResult: (target: string, source: string) => void;
  cancelNavigation: (clearRetained: boolean) => void;
  clearOpeningDetail: () => void;
  sheetKind: () => string;
  setFilterVisible: (visible: boolean) => void;
  prepareRead: () => boolean;
  requestRead: () => void;
  pinIdentity: (url: string) => string;
  traceAction: (name: string, detail?: string) => void;
  showMessage: (message: string) => void;
}
