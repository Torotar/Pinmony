import { PinmonyCreatedPin, PinmonyOrganizeSnapshot } from '../models/PinmonyProfile';
import { PinmonyOrganizePage } from './PinmonyOrganizePage';

// Publish owns this entry point so its board flow can evolve independently
// from the profile's ordinary "整理到图板" flow.
@Component
export struct PinmonyPublishBoardPage {
  @Prop state: PinmonyOrganizeSnapshot = {} as PinmonyOrganizeSnapshot;
  @Prop pins: PinmonyCreatedPin[] = [];
  @Prop pinsLoading: boolean = false;
  onAction: (action: string, value: string, secret: boolean) => void = () => {};

  build() {
    PinmonyOrganizePage({ state: this.state, pins: this.pins, pinsLoading: this.pinsLoading,
      publishing: true, standaloneBoard: this.state.phase === 'create', onAction: this.onAction })
  }
}
