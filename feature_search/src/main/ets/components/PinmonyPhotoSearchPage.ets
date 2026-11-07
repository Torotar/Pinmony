import { PinmonyHdsTitleBar } from 'common_ui';
import { HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, BlurStrategy } from '@kit.UIDesignKit';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyImageSearchView, PinmonyImageSearchResult, PinmonyImageCrop, PinmonyImageSearchOrigin } from 'common_ui';
import { PinmonyPhotoHistoryOrigin } from '../models/PinmonyPhotoHistory';

@Component
export struct PinmonyPhotoSearchPage {
  @StorageLink('systemDarkMode') private hdsDarkMode: boolean = false;
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  @StorageProp('systemDarkMode') private systemDarkMode: boolean = false;
  @Prop imageUrl: string = '';
  @Prop active: boolean = true;
  @Prop closing: boolean = false;
  @Prop origin: PinmonyPhotoHistoryOrigin | undefined = undefined;
  @Prop result: PinmonyImageSearchResult;
  onTransitionReady?: () => void;
  onTransitionClosed?: () => void;
  onSearch?: (crop: PinmonyImageCrop) => void;
  onResult?: (id: string, origin?: PinmonyImageSearchOrigin) => void;
  onClose?: () => void;
  onBack?: () => boolean;

  private uiText(key: string): string { return PinmonyI18n.text(key, this.uiLanguage); }

  private photoSearchTitleBarOptions(): HdsNavigationTitleBarOptions {
    return {
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      style: {
        blurStrategy: BlurStrategy.DISABLE, thermoCtrl: false,
        scrollEffectOpts: { enableScrollEffect: false },
        originalStyle: {
          backgroundStyle: { backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0, blurRadius: 0 },
          contentStyle: {
            backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') },
            titleStyle: { mainTitleColor: $r('app.color.primary_text') }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: { backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0, blurRadius: 0 },
          contentStyle: {
            backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') },
            titleStyle: { mainTitleColor: $r('app.color.primary_text') }
          }
        }
      },
      content: {
        title: { mainTitle: this.uiText('pm_detail_photo_search') },
        backIcon: { label: this.uiText('pm_back_572cf45b'), isEnabled: true, action: () => { this.onClose?.(); } },
        menu: { value: [] }
      }
    };
  }

  build() {
    HdsNavDestination() {
      PinmonyImageSearchView({ imageUrl: this.imageUrl, uploadedPhoto: true, presentationActive: this.active, result: this.result,
        animatePhoto: !!this.origin, closing: this.closing, sourceSelectionBorder: !!this.origin,
        imageWidth: this.origin?.imageWidth || 1, imageHeight: this.origin?.imageHeight || 1,
        originX: this.origin?.x || 0, originY: this.origin?.y || 0,
        originWidth: this.origin?.width || 0, originHeight: this.origin?.height || 0,
        onTransitionReady: this.onTransitionReady,
        onTransitionClosed: this.onTransitionClosed,
        onSearch: (crop: PinmonyImageCrop) => { this.onSearch?.(crop); },
        onClose: this.onClose,
        onRelated: (id: string, origin?: PinmonyImageSearchOrigin) => { this.onResult?.(id, origin); }
      })
    }
    .mode(NavDestinationMode.STANDARD)
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideTitleBar(false)
    .titleBar(PinmonyHdsTitleBar.resolve(this.getUIContext(), this.photoSearchTitleBarOptions(), this.hdsDarkMode))
    .bindToScrollable([])
    .systemBarStyle({ statusBarContentColor: this.systemDarkMode ? '#F7F8FA' : '#1B1E25' },
      { statusBarContentColor: this.systemDarkMode ? '#F7F8FA' : '#1B1E25' })
    .onBackPressed(() => this.onBack ? this.onBack() : true)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.page_background'))
  }
}
