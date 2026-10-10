import BuildProfile from '../../../../BuildProfile';
import { PinmonyRuntimeLog } from './PinmonyRuntimeLog';

// Explicit developer override; release builds always retain normal prefetch behavior.
export const PIN_TEST_REQUEST_MODE_ENABLED: boolean = true;
export const PIN_TEST_REQUEST_MODE: boolean = BuildProfile.DEBUG && PIN_TEST_REQUEST_MODE_ENABLED;
let reported: boolean = false;

export function allowsSpeculativeReads(): boolean {
  if (!reported) {
    reported = true;
    PinmonyRuntimeLog.info('RequestPolicy: test-mode enabled=' + PIN_TEST_REQUEST_MODE.toString() +
      ' speculativeReads=' + (!PIN_TEST_REQUEST_MODE).toString());
  }
  return !PIN_TEST_REQUEST_MODE;
}
