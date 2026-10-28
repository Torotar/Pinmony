import { HdsSnackBar } from '@kit.UIDesignKit';
import { BlurStrategy } from '@kit.UIDesignKit';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyI18n, PinmonyProfileLayoutPreference } from 'common_foundation';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { window } from '@kit.ArkUI';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, SnackBarIconType, SnackBarOperationType, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
import { PinmonySettingsStore } from '../stores/PinmonySettingsStore';
import { PinmonyRuntimeLog } from 'common_foundation';
@Component
export struct PinmonyDisplaySettingsPage {
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  private get immersiveLightEnabled(): boolean { return this.immersiveLightMode !== 'off'; }
  @StorageLink('pinmonyLanguage') @Watch('syncErrorSnack') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @ObjectLink @Watch('syncErrorSnack') store: PinmonySettingsStore;
  onRequest?: (action: string, value: string) => Promise<void>;
  onBack?: () => void;
  @StorageLink('bottomBarScrollCollapseEnabled') private collapseEnabled: boolean = true;
  @StorageLink('profileLegacyLayout') private legacyProfile: boolean = false;
  @StorageLink('profileAvatarRight') private avatarRight: boolean = false;
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
  aboutToAppear(): void { this.pageVisible = true; this.paths.pushPath({ name: 'display' }, false); this.syncErrorSnack(); this.logMaterialMode(); }
  aboutToDisappear(): void { this.pageVisible = false; this.dismissErrorSnack(); }
  private dismissErrorSnack(): void { this.errorSnack?.dismiss(); this.errorSnackKey = ''; }
  private syncErrorSnack(): void {
    if (!this.pageVisible || !this.store.error || this.store.loading || this.store.busy || this.store.confirmOpen) {
      this.dismissErrorSnack(); return;
    }
    const key: string = this.store.screen + ':' + this.store.recommendationTab + ':' + this.store.token.toString() + ':' + this.store.error + ':' + this.uiLanguage;
    if (key === this.errorSnackKey) return;
    this.dismissErrorSnack(); this.errorSnackKey = key;
    if (!this.errorSnack) this.errorSnack = new HdsSnackBar(this.getUIContext());
    this.errorSnack.show({ icon: $r('sys.symbol.exclamationmark_circle'), iconType: SnackBarIconType.NORMAL }, { title: PinmonyI18n.render(this.store.error, this.uiLanguage) }, {
      operationType: SnackBarOperationType.TEXT_ONLY,
      content: PinmonyI18n.isUnconfirmed(this.store.error) ? this.uiText("pm_reload_df7392cc") : this.uiText("pm_retry_b8784c8d"),
      contentAccessibilityText: this.uiText("pm_reload_current_settings_d2b82d8a"),
      onContentClick: () => {
        if (!this.pageVisible || key !== this.errorSnackKey || this.store.busy || this.store.loading) return;
        this.dismissErrorSnack();
        this.request(this.store.screen === 'recommend' ? this.store.recommendationTab === 'ai' ? 'aiRead' : 'activityRead' : 'read');
      }
    }, { duration: 4000, pressBackCallback: () => { this.dismissErrorSnack(); if (this.onBack) this.onBack(); return true; } });
  }
  private title(): string { return this.store.screen === 'theme' ? this.uiText("pm_theme_788db1cf") : this.uiText("pm_display_settings_32e62ed0"); }
  private themeLabel(): string { return this.themePreference === 'dark' ? this.uiText("pm_dark_a6b75d06") : this.themePreference === 'light' ? this.uiText("pm_light_aa0819df") : this.uiText("pm_follow_system_217cfe7d"); }
  private available(): boolean { return !!this.store.data?.ready && !this.store.loading && !this.store.busy && !this.store.error; }
  @Builder
  private autoplayOption(action: string, label: string, value: boolean | undefined) {
    Row({ space: 16 }) {
      Text(this.uiText(label)).fontSize(17).fontColor($r('app.color.primary_text')).layoutWeight(1)
      Checkbox().select(value === true).shape(CheckBoxShape.CIRCLE)
          .selectedColor($r('app.color.accent')).unselectedColor($r('app.color.secondary_text'))
          .mark({ strokeColor: Color.White }).width(24).height(24).margin(12)
        .enabled(this.available() && !this.store.writeUncertain && typeof value === 'boolean')
        .accessibilityText(this.uiText(label))
        .onChange((next: boolean) => { if (this.available() && !this.store.writeUncertain && typeof value === 'boolean' && next !== value) this.request(action, String(next)); })
    }.width('100%').constraintSize({ minHeight: 64 }).padding({ left: 16, right: 16, top: 8, bottom: 8 })

  }
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
      try {
        this.getUIContext().getPromptAction().showToast({ message: this.uiText("pm_unable_to_change_orientation_please_retry_c7c24220"), duration: 3000 });
      } catch (_) { PinmonyRuntimeLog.warn('OrientationPreference: failure feedback unavailable'); }
    } finally { this.orientationBusy = false; }
  }
  private logMaterialMode(): void {
    try {
      const types: hdsMaterial.MaterialType[] = hdsMaterial.getSystemMaterialTypes();
      PinmonyRuntimeLog.info('ImmersiveLight: mode=' + this.immersiveLightMode +
        ' supportedTypes=' + types.join(',') + ' immersiveSupported=' + types.includes(hdsMaterial.MaterialType.IMMERSIVE));
    } catch (_) { PinmonyRuntimeLog.warn('ImmersiveLight: capability query unavailable mode=' + this.immersiveLightMode); }
  }
  private options(): HdsNavigationTitleBarOptions {
    return { avoidLayoutSafeArea: true, enableComponentSafeArea: true,
      style: { blurStrategy: this.immersiveLightEnabled ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: this.immersiveLightEnabled,
        scrollEffectOpts: { enableScrollEffect: this.immersiveLightEnabled, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        originalStyle: {
          backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 },
          contentStyle: {
            backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') },
            menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') },
            titleStyle: { mainTitleColor: $r('app.color.primary_text') }
          }
        },
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 },
          contentStyle: {
            backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') },
            menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') },
            titleStyle: { mainTitleColor: $r('app.color.primary_text') }
          }
        }
      },
      content: { title: { mainTitle: this.title() }, backIcon: { isEnabled: !this.store.busy, action: () => { if (this.onBack) this.onBack(); } },
        menu: { value: [] } } };
  }
  @Builder
  private display() {
    Column() {
    Row({ space: 12 }) {
      Text(this.uiText("pm_language_9f6fee1a")).fontSize(17)
        .fontColor($r('app.color.primary_text')).layoutWeight(1)
      ForEach([this.uiLanguage], (language: string) => {
        Select([{ value: this.uiText("pm_follow_system_217cfe7d") }, { value: '中文' }, { value: '繁體中文' }, { value: 'English' }, { value: 'English (UK)' }, { value: '日本語' }, { value: '한국어' }])
        .selected(Math.max(0, ['system', 'zh', 'zh_TW', 'en', 'en_GB', 'ja', 'ko'].indexOf(this.languagePreference)))
        .value(this.languagePreference === 'zh' ? '中文' : this.languagePreference === 'zh_TW' ? '繁體中文' : this.languagePreference === 'en' ? 'English' : this.languagePreference === 'en_GB' ? 'English (UK)' : this.languagePreference === 'ja' ? '日本語' : this.languagePreference === 'ko' ? '한국어' : this.uiText("pm_follow_system_217cfe7d"))
        .font({ size: 15 }).fontColor($r('app.color.primary_text'))
        .backgroundColor($r('app.color.display_settings_control')).borderRadius(16)
        .selectedOptionBgColor($r('app.color.display_settings_control'))
        .selectedOptionFontColor($r('app.color.primary_text'))
        .optionFontColor($r('app.color.primary_text'))
        .accessibilityText(this.uiText("pm_language_9f6fee1a"))
        .onSelect((index: number) => {
          if (index >= 0 && index < 7) {
            const value: string = ['system', 'zh', 'zh_TW', 'en', 'en_GB', 'ja', 'ko'][index];
            try { PinmonyI18n.select(value); PinmonyRuntimeLog.info('LanguagePreference: saved=' + value); }
            catch (_) {
              PinmonyRuntimeLog.warn('LanguagePreference: save failed');
              this.getUIContext().getPromptAction().showToast({ message: this.uiText("pm_unable_to_change_language_please_retry_f77e9a24") });
            }
          }
        })
      }, (language: string): string => language)
    }.width('100%').constraintSize({ minHeight: 64 }).padding({ left: 16, right: 16, top: 8, bottom: 8 })

    Row({ space: 12 }) {
      Text(this.uiText("pm_theme_788db1cf")).fontSize(17)
        .fontColor($r('app.color.primary_text')).layoutWeight(1)
      ForEach([this.uiLanguage], (language: string) => {
        Select([{ value: this.uiText("pm_follow_system_217cfe7d") }, { value: this.uiText("pm_light_aa0819df") }, { value: this.uiText("pm_dark_a6b75d06") }])
        .selected(this.themePreference === 'light' ? 1 : this.themePreference === 'dark' ? 2 : 0)
        .value(this.themeLabel())
        .font({ size: 15 }).fontColor($r('app.color.primary_text'))
        .backgroundColor($r('app.color.display_settings_control')).borderRadius(16)
        .selectedOptionBgColor($r('app.color.display_settings_control'))
        .selectedOptionFontColor($r('app.color.primary_text'))
        .optionFontColor($r('app.color.primary_text'))
        .accessibilityText(this.uiText("pm_theme_0fa0bfe4") + this.themeLabel())
        .onSelect((index: number) => {
          if (index >= 0 && index < 3) this.selectTheme(['system', 'light', 'dark'][index]);
        })
      }, (language: string): string => language)
    }.width('100%').constraintSize({ minHeight: 64 }).padding({ left: 16, right: 16, top: 8, bottom: 8 })

    if (this.isTablet) {
      Row({ space: 12 }) {
        Text(this.uiText("pm_screen_orientation_60cc99cc")).fontSize(17).fontColor($r('app.color.primary_text')).layoutWeight(1)
        ForEach([this.uiLanguage], (language: string) => {
        Select([{ value: this.uiText("pm_follow_system_217cfe7d") }, { value: this.uiText("pm_always_rotate_automatically_d3a0ff23") }, { value: this.uiText("pm_portrait_c35bd83b") }, { value: this.uiText("pm_landscape_055a6b3a") }])
          .selected(Math.max(0, ['system', 'auto', 'portrait', 'landscape'].indexOf(this.orientationPreference)))
          .value(this.orientationPreference === 'auto' ? this.uiText("pm_always_rotate_automatically_d3a0ff23") : this.orientationPreference === 'portrait' ? this.uiText("pm_portrait_c35bd83b") : this.orientationPreference === 'landscape' ? this.uiText("pm_landscape_055a6b3a") : this.uiText("pm_follow_system_217cfe7d"))
          .font({ size: 15 }).fontColor($r('app.color.primary_text'))
          .backgroundColor($r('app.color.display_settings_control')).borderRadius(16).enabled(!this.orientationBusy)
          .accessibilityText(this.uiText("pm_screen_orientation_60cc99cc"))
          .onSelect((index: number) => { this.selectOrientation(index); })
      }, (language: string): string => language)
      }.width('100%').constraintSize({ minHeight: 64 }).padding({ left: 16, right: 16, top: 8, bottom: 8 })

    }
    }.width('100%')
    Column() {
    Row({ space: 16 }) {
      Column({ space: 6 }) {
        Text(this.uiText("pm_bottom_bar_collapse_animation_4b0bb564")).fontSize(17).fontColor($r('app.color.primary_text'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Checkbox().select(this.collapseEnabled).shape(CheckBoxShape.CIRCLE)
          .selectedColor($r('app.color.accent')).unselectedColor($r('app.color.secondary_text'))
          .mark({ strokeColor: Color.White }).width(24).height(24).margin(12).onChange((value: boolean) => { this.collapseEnabled = value; })
        .accessibilityText(this.uiText("pm_bottom_bar_collapse_animation_4b0bb564"))
    }.width('100%').constraintSize({ minHeight: 64 }).padding({ left: 16, right: 16, top: 8, bottom: 8 })

    Row({ space: 16 }) {
      Text(this.uiText('pm_immersive_light')).fontSize(17)
        .fontColor($r('app.color.primary_text')).layoutWeight(1)
      ForEach([this.uiLanguage], (language: string) => {
        Select([{ value: this.uiText('pm_light_off') }, { value: this.uiText('pm_light_gentle') },
        { value: this.uiText('pm_light_immersive') }, { value: this.uiText('pm_light_exquisite') }])
        .selected(Math.max(0, ['off', 'gentle', 'immersive', 'exquisite'].indexOf(this.immersiveLightMode)))
        .value(this.uiText(this.immersiveLightMode === 'off' ? 'pm_light_off' : this.immersiveLightMode === 'gentle' ?
          'pm_light_gentle' : this.immersiveLightMode === 'exquisite' ? 'pm_light_exquisite' : 'pm_light_immersive'))
        .font({ size: 15 }).fontColor($r('app.color.primary_text'))
        .backgroundColor($r('app.color.display_settings_control')).borderRadius(16)
        .selectedOptionBgColor($r('app.color.display_settings_control'))
        .selectedOptionFontColor($r('app.color.primary_text')).optionFontColor($r('app.color.primary_text'))
        .accessibilityText(this.uiText('pm_immersive_light'))
        .onSelect((index: number) => {
          if (index >= 0 && index < 4) {
            this.immersiveLightMode = ['off', 'gentle', 'immersive', 'exquisite'][index];
            this.logMaterialMode();
          }
        })
      }, (language: string): string => language)
    }.width('100%').constraintSize({ minHeight: 64 }).padding({ left: 16, right: 16, top: 8, bottom: 8 })

    }.width('100%')
    Column() {
    Row({ space: 16 }) {
      Text(this.uiText('pm_profile_legacy_layout')).fontSize(17).fontColor($r('app.color.primary_text')).layoutWeight(1)
      Checkbox().select(this.legacyProfile).shape(CheckBoxShape.CIRCLE)
          .selectedColor($r('app.color.accent')).unselectedColor($r('app.color.secondary_text'))
          .mark({ strokeColor: Color.White }).width(24).height(24).margin(12).onChange((value: boolean) => { PinmonyProfileLayoutPreference.saveLegacyLayout(value); })
        .accessibilityText(this.uiText('pm_profile_legacy_layout'))
    }.width('100%').constraintSize({ minHeight: 64 }).padding({left:16,right:16,top:8,bottom:8})
    if (!this.legacyProfile) {
      Row({ space: 16 }) {
        Text(this.uiText('pm_profile_avatar_right')).fontSize(17).fontColor($r('app.color.primary_text')).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.avatarRight })
          .selectedColor($r('app.color.accent')).margin({left:12,right:12,top:8,bottom:8})
          .onChange((value: boolean) => { PinmonyProfileLayoutPreference.saveAvatarRight(value); })
          .accessibilityText(this.uiText('pm_profile_avatar_right'))
      }.width('100%').constraintSize({ minHeight: 64 }).padding({left:16,right:16,top:8,bottom:8})
    }
    }.width('100%')
    Column() {
    Text(this.uiText('pm_autoplay_video_title')).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).margin({ top: 16, bottom: 8 })
    ForEach(['autoplayCellular','autoplayWifi'], (action: string) => {
      this.autoplayOption(action, action === 'autoplayWifi' ? 'pm_autoplay_video_wifi' : 'pm_autoplay_video_cellular', action === 'autoplayWifi' ? this.store.data?.autoplayWifi : this.store.data?.autoplayCellular)
    }, (action: string): string => action + ':' + (action === 'autoplayWifi' ? this.store.data?.autoplayWifi : this.store.data?.autoplayCellular) + ':' + this.store.token + ':' + this.store.busy + ':' + this.store.loading + ':' + this.store.writeUncertain)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  private theme() {
    ForEach(['system', 'light', 'dark'], (value: string) => {
      Row() {
        Text(value === 'system' ? this.uiText("pm_follow_system_217cfe7d") : value === 'light' ? this.uiText("pm_light_aa0819df") : this.uiText("pm_dark_a6b75d06")).fontSize(18).fontColor($r('app.color.primary_text')).layoutWeight(1)
        Radio({ group: 'pinweb-theme', value }).checked(this.themePreference === value)
        .radioStyle({ checkedBackgroundColor: $r('app.color.accent'), indicatorColor: Color.White })
          .onChange((selected: boolean) => { if (selected) this.selectTheme(value); })
          .accessibilityText(value === 'system' ? this.uiText("pm_follow_system_217cfe7d") : value === 'light' ? this.uiText("pm_light_aa0819df") : this.uiText("pm_dark_a6b75d06"))
      }.width('100%').constraintSize({ minHeight: 56 })
    }, (value: string) => (value) + ':' + this.uiLanguage)
  }
  @Builder
  private destination(_name?: string, _param?: Object) {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Center }) {
      Scroll(this.scroller) {
        Column() {
          if (this.store.screen === 'theme') { this.theme() } else { this.display() }
        }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 32 }).alignItems(HorizontalAlign.Start)
      }.width('100%').height('100%').align(Alignment.TopStart)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      if (this.store.loading || this.store.busy) {
        LoadingProgress().width(40).height(40).color($r('app.color.accent')).hitTestBehavior(HitTestMode.None)
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
