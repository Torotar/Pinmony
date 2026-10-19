import { PinmonyI18n } from 'common_foundation';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { window } from '@kit.ArkUI';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, HdsSnackBar, SnackBarOperationType, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
import { PinmonySettingsStore } from '../stores/PinmonySettingsStore';
import { PinmonyRuntimeLog } from 'common_foundation';
@Component
export struct PinmonyDisplaySettingsPage {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @ObjectLink @Watch('syncErrorSnack') store: PinmonySettingsStore;
  onRequest?: (action: string, value: string) => Promise<void>;
  onBack?: () => void;
  @StorageLink('bottomBarScrollCollapseEnabled') private collapseEnabled: boolean = true;
  @StorageLink('themePreference') private themePreference: string = 'system';
  @StorageLink('pinmonyLanguagePreference') private languagePreference: string = 'system';
  @StorageLink('screenOrientationPreference') private orientationPreference: string = 'system';
  @State private orientationBusy: boolean = false;
  private readonly isTablet: boolean = deviceInfo.deviceType === 'tablet';
  private paths: NavPathStack = new NavPathStack();
  private scroller: Scroller = new Scroller();
  private errorSnack: HdsSnackBar | undefined = undefined;
  private errorSnackKey: string = '';
  private pageVisible: boolean = false;
  aboutToAppear(): void { this.pageVisible = true; this.paths.pushPath({ name: 'display' }, false); this.syncErrorSnack(); }
  aboutToDisappear(): void { this.pageVisible = false; this.dismissErrorSnack(); }
  private dismissErrorSnack(): void { this.errorSnack?.dismiss(); this.errorSnackKey = ''; }
  private syncErrorSnack(): void {
    if (!this.pageVisible || !this.store.error || this.store.loading || this.store.busy || this.store.confirmOpen) {
      this.dismissErrorSnack(); return;
    }
    const key: string = this.store.screen + ':' + this.store.recommendationTab + ':' + this.store.token.toString() + ':' + this.store.error;
    if (key === this.errorSnackKey) return;
    this.dismissErrorSnack(); this.errorSnackKey = key;
    if (!this.errorSnack) this.errorSnack = new HdsSnackBar(this.getUIContext());
    this.errorSnack.show({}, { title: PinmonyI18n.render(this.store.error, this.uiLanguage) }, {
      operationType: SnackBarOperationType.TEXT_ONLY,
      content: PinmonyI18n.isUnconfirmed(this.store.error) ? this.uiText("pm_reload_df7392cc") : this.uiText("pm_retry_b8784c8d"),
      contentAccessibilityText: this.uiText("pm_reload_current_settings_d2b82d8a"),
      onContentClick: () => {
        if (!this.pageVisible || key !== this.errorSnackKey || this.store.busy || this.store.loading) return;
        this.dismissErrorSnack();
        this.request(this.store.screen === 'recommend' ? this.store.recommendationTab === 'ai' ? 'aiRead' : 'activityRead' : 'read');
      }
    }, { duration: 0, pressBackCallback: () => { this.dismissErrorSnack(); if (this.onBack) this.onBack(); return true; } });
  }
  private title(): string { return this.store.screen === 'theme' ? this.uiText("pm_theme_788db1cf") : this.uiText("pm_display_settings_32e62ed0"); }
  private themeLabel(): string { return this.themePreference === 'dark' ? this.uiText("pm_dark_a6b75d06") : this.themePreference === 'light' ? this.uiText("pm_light_aa0819df") : this.uiText("pm_follow_system_217cfe7d"); }
  private available(): boolean { return !!this.store.data?.ready && !this.store.loading && !this.store.busy && !this.store.error; }
  private async request(action: string, value: string = ''): Promise<void> { if (!this.store.busy && !this.store.loading && this.onRequest) await this.onRequest(action, value); }
  private selectTheme(value: string): void {
    if (!['system', 'light', 'dark'].includes(value) || this.themePreference === value) return;
    const previous: string = this.themePreference;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.themePreference = value;
      context.getApplicationContext().setColorMode(value === 'dark' ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK : value === 'light' ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (_) {
      this.themePreference = previous;
      try { this.getUIContext().getPromptAction().showToast({ message: this.uiText("pm_unable_to_change_theme_please_retry_e0cd6314"), duration: 3000 }); }
      catch (_) { PinmonyRuntimeLog.warn('Settings: theme failure feedback unavailable'); }
    }
  }
  private async selectOrientation(index: number): Promise<void> {
    if (!this.isTablet || this.orientationBusy || index < 0 || index > 3) return;
    const values: string[] = ['system', 'auto', 'portrait', 'landscape'];
    const value: string = values[index];
    if (value === this.orientationPreference) return;
    this.orientationBusy = true;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const mainWindow: window.Window = await window.getLastWindow(context);
      const orientations: window.Orientation[] = [window.Orientation.AUTO_ROTATION_RESTRICTED,
        window.Orientation.AUTO_ROTATION, window.Orientation.PORTRAIT, window.Orientation.LANDSCAPE];
      await mainWindow.setPreferredOrientation(orientations[index]);
      this.orientationPreference = value;
    } catch (_) {
      this.getUIContext().getPromptAction().showToast({ message: this.uiText("pm_unable_to_change_orientation_please_retry_c7c24220"), duration: 3000 });
    } finally { this.orientationBusy = false; }
  }
  private options(): HdsNavigationTitleBarOptions {
    return { avoidLayoutSafeArea: true, enableComponentSafeArea: true,
      style: {
        scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE },
        originalStyle: {
          backgroundStyle: { backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0 },
          contentStyle: {
            backIconStyle: { iconColor: $r('app.color.primary_text') },
            menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') },
            titleStyle: { mainTitleColor: $r('app.color.primary_text') }
          }
        },
        scrollEffectStyle: {
          contentStyle: {
            backIconStyle: { iconColor: $r('app.color.primary_text') },
            menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') },
            titleStyle: { mainTitleColor: $r('app.color.primary_text') }
          }
        }
      },
      content: { title: { mainTitle: this.title() }, backIcon: { isEnabled: !this.store.busy, action: () => { if (this.onBack) this.onBack(); } },
        menu: { value: [] } } };
  }
  @Builder
  private display() {
    Row({ space: 12 }) {
      Text(this.uiText("pm_language_9f6fee1a")).fontSize(18).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.primary_text')).layoutWeight(1)
      Select([{ value: this.uiText("pm_follow_system_217cfe7d") }, { value: '中文' }, { value: 'English' }])
        .selected(Math.max(0, ['system', 'zh', 'en'].indexOf(this.languagePreference)))
        .value(this.languagePreference === 'zh' ? '中文' : this.languagePreference === 'en' ? 'English' : this.uiText("pm_follow_system_217cfe7d"))
        .font({ size: 15 }).fontColor($r('app.color.primary_text'))
        .backgroundColor($r('app.color.surface_muted'))
        .selectedOptionBgColor($r('app.color.surface_muted'))
        .selectedOptionFontColor($r('app.color.primary_text'))
        .optionFontColor($r('app.color.primary_text'))
        .accessibilityText(this.uiText("pm_language_9f6fee1a"))
        .onSelect((index: number) => {
          if (index >= 0 && index < 3) {
            const value: string = ['system', 'zh', 'en'][index];
            try { PinmonyI18n.select(value); PinmonyRuntimeLog.info('LanguagePreference: saved=' + value); }
            catch (_) {
              PinmonyRuntimeLog.warn('LanguagePreference: save failed');
              this.getUIContext().getPromptAction().showToast({ message: this.uiText("pm_unable_to_change_language_please_retry_f77e9a24") });
            }
          }
        })
    }.width('100%').padding({ top: 16, bottom: 16 })
    Row({ space: 12 }) {
      Text(this.uiText("pm_theme_788db1cf")).fontSize(18).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.primary_text')).layoutWeight(1)
      Select([{ value: this.uiText("pm_follow_system_217cfe7d") }, { value: this.uiText("pm_light_aa0819df") }, { value: this.uiText("pm_dark_a6b75d06") }])
        .selected(this.themePreference === 'light' ? 1 : this.themePreference === 'dark' ? 2 : 0)
        .value(this.themeLabel())
        .font({ size: 15 }).fontColor($r('app.color.primary_text'))
        .backgroundColor($r('app.color.surface_muted'))
        .selectedOptionBgColor($r('app.color.surface_muted'))
        .selectedOptionFontColor($r('app.color.primary_text'))
        .optionFontColor($r('app.color.primary_text'))
        .accessibilityText(this.uiText("pm_theme_0fa0bfe4") + this.themeLabel())
        .onSelect((index: number) => {
          if (index >= 0 && index < 3) this.selectTheme(['system', 'light', 'dark'][index]);
        })
    }.width('100%').padding({ top: 16, bottom: 16 })
    if (this.isTablet) {
      Row({ space: 12 }) {
        Text(this.uiText("pm_screen_orientation_60cc99cc")).fontSize(17).fontColor($r('app.color.primary_text')).layoutWeight(1)
        Select([{ value: this.uiText("pm_follow_system_217cfe7d") }, { value: this.uiText("pm_always_rotate_automatically_d3a0ff23") }, { value: this.uiText("pm_portrait_c35bd83b") }, { value: this.uiText("pm_landscape_055a6b3a") }])
          .selected(Math.max(0, ['system', 'auto', 'portrait', 'landscape'].indexOf(this.orientationPreference)))
          .value(this.orientationPreference === 'auto' ? this.uiText("pm_always_rotate_automatically_d3a0ff23") : this.orientationPreference === 'portrait' ? this.uiText("pm_portrait_c35bd83b") : this.orientationPreference === 'landscape' ? this.uiText("pm_landscape_055a6b3a") : this.uiText("pm_follow_system_217cfe7d"))
          .font({ size: 15 }).fontColor($r('app.color.primary_text'))
          .backgroundColor($r('app.color.surface_muted')).enabled(!this.orientationBusy)
          .accessibilityText(this.uiText("pm_screen_orientation_60cc99cc"))
          .onSelect((index: number) => { this.selectOrientation(index); })
      }.width('100%').padding({ top: 16, bottom: 16 })
    }
    Row({ space: 16 }) {
      Column({ space: 6 }) {
        Text(this.uiText("pm_bottom_bar_collapse_animation_4b0bb564")).fontSize(17).fontColor($r('app.color.primary_text'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: this.collapseEnabled }).onChange((value: boolean) => { this.collapseEnabled = value; })
        .accessibilityText(this.uiText("pm_bottom_bar_collapse_animation_4b0bb564"))
    }.width('100%').padding({ top: 16, bottom: 16 })
  }
  @Builder
  private theme() {
    ForEach(['system', 'light', 'dark'], (value: string) => {
      Row() {
        Text(value === 'system' ? this.uiText("pm_follow_system_217cfe7d") : value === 'light' ? this.uiText("pm_light_aa0819df") : this.uiText("pm_dark_a6b75d06")).fontSize(18).fontColor($r('app.color.primary_text')).layoutWeight(1)
        Radio({ group: 'pinweb-theme', value }).checked(this.themePreference === value)
          .onChange((selected: boolean) => { if (selected) this.selectTheme(value); })
          .accessibilityText(value === 'system' ? this.uiText("pm_follow_system_217cfe7d") : value === 'light' ? this.uiText("pm_light_aa0819df") : this.uiText("pm_dark_a6b75d06"))
      }.width('100%').constraintSize({ minHeight: 56 })
    }, (value: string) => value)
  }
  @Builder
  private destination(_name?: string, _param?: Object) {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Center }) {
      Scroll(this.scroller) {
        Column({ space: 8 }) {
          if (this.store.screen === 'theme') { this.theme() } else { this.display() }
        }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 32 }).alignItems(HorizontalAlign.Start)
      }.width('100%').height('100%').align(Alignment.TopStart)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      if (this.store.loading || this.store.busy) {
        LoadingProgress().width(40).height(40).color($r('app.color.primary_text')).hitTestBehavior(HitTestMode.None)
      }
      }.width('100%').height('100%')
    }.titleBar(this.options()).titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
      .bindToScrollable([this.scroller]).onBackPressed(() => { if (this.onBack) this.onBack(); return true; })
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP]).backgroundColor($r('app.color.page_background'))
  }
  build() {
    HdsNavigation(this.paths) { Column().width('100%').height('100%') }
      .width('100%').height('100%').hideTitleBar(true).navDestination(this.destination).backgroundColor($r('app.color.page_background'))
  }
}
