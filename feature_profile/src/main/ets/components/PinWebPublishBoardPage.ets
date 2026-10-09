import { PinWebCreatedPin, PinWebOrganizeSnapshot } from '../models/PinWebProfile';
import { PinWebOrganizePage } from './PinWebOrganizePage';

// Publish owns this entry point so its board flow can evolve independently
// from the profile's ordinary "整理到图板" flow.
@Component
export struct PinWebPublishBoardPage {
  @Prop state: PinWebOrganizeSnapshot = {} as PinWebOrganizeSnapshot;
  @Prop pins: PinWebCreatedPin[] = [];
  @Prop pinsLoading: boolean = false;
  onAction: (action: string, value: string, secret: boolean) => void = () => {};

  build() {
    PinWebOrganizePage({ state: this.state, pins: this.pins, pinsLoading: this.pinsLoading,
      publishing: true, standaloneBoard: this.state.phase === 'create', onAction: this.onAction })
  }
}
