import { PinmonyDetailAction } from './PinmonyDetail';
import { PinmonyPinStore } from '../stores/PinmonyPinStore';

export interface PinmonyDetailPorts {
  store: PinmonyPinStore;
  postApiEnabled: () => boolean;
  postExtensionsEnabled: () => boolean;
  isAuthenticated: () => boolean;
  isForeground: () => boolean;
  isOffline: (operation: string) => boolean;
  currentPinUrl: () => string;
  pinIdentity: (url: string) => string;
  beginDetailOpening: (pin: string) => void;
  loadDetailUrl: (pin: string) => void;
  runScript: (script: string) => Promise<string>;
  markJourney: (event: string) => void;
  openComments: () => void;
  cancelSave: (pin: string) => Promise<void>;
  openBoards: () => Promise<void>;
  openShare: (pin: string) => Promise<string>;
  openMore: () => Promise<void>;
  externalSourceUrl: (url: string) => string;
  openExternalLink: (url: string) => Promise<void>;
  traceAction: (name: string, detail: string) => void;
  showMessage: (message: string) => void;
}
