import { PinmonySettingsStore } from '../stores/PinmonySettingsStore';
import { PinmonyDisplaySettingsPage } from './PinmonyDisplaySettingsPage';
import { PinmonyRecommendationSettingsPage } from './PinmonyRecommendationSettingsPage';
import { PinmonyVisibilitySettingsPage } from './PinmonyVisibilitySettingsPage';

// Compatibility entry point; each page owns its UI and presentation lifecycle.
@Component
export struct PinmonyPreferencesPage {
  @ObjectLink store: PinmonySettingsStore;
  onRequest?: (action: string, value: string) => Promise<void>;
  onBack?: () => void;
  build() {
    if (this.store.screen === 'recommend') {
      PinmonyRecommendationSettingsPage({ store: this.store, onRequest: this.onRequest, onBack: this.onBack })
    } else if (this.store.screen === 'visibility') {
      PinmonyVisibilitySettingsPage({ store: this.store, onRequest: this.onRequest, onBack: this.onBack })
    } else {
      PinmonyDisplaySettingsPage({ store: this.store, onRequest: this.onRequest, onBack: this.onBack })
    }
  }
}
