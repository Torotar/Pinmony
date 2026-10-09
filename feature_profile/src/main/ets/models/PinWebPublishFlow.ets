import { PinWebCreatedPin, PinWebOrganizeSnapshot } from './PinWebProfile';

export interface PinWebPublishFlow extends PinWebOrganizeSnapshot {
  token: number;
  page: string;
  profile: string;
  kind: string;
  pins: PinWebCreatedPin[];
  completed: number;
}
