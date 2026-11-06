import { PinmonyDetailSnapshot, PinmonyVisualResult } from 'feature_pin';
import { PinmonyVisualSearchContinuation } from './PinmonyDetailNativeAuxiliary';

// Read-only presentation beneath a child Pin; it never grants action ownership.
export interface PinmonyDetailSearchPresentation {
  identity: string;
  detail: PinmonyDetailSnapshot;
  result: PinmonyVisualResult;
  renderIdentity: string;
  traceId: number;
  scrollOffset: number;
  continuation: PinmonyVisualSearchContinuation;
}
