import { PinmonyCreatedPin, PinmonyOrganizeSnapshot } from './PinmonyProfile';

export interface PinmonyPublishFlow extends PinmonyOrganizeSnapshot {
  token: number;
  page: string;
  profile: string;
  kind: string;
  pins: PinmonyCreatedPin[];
  completed: number;
  boardCreated?: boolean;
}
