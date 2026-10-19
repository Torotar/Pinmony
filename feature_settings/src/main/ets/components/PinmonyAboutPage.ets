import { PinmonyI18n } from 'common_foundation';
import { PinmonyRelease, PinmonyReleaseClient, PinmonyReleaseFailure, isNewerRelease } from '../services/PinmonyRelease';
import { bundleManager } from '@kit.AbilityKit';
import { PinmonyRuntimeLog } from 'common_foundation';
import { HdsNavigation, ScrollEffectType, hdsMaterial, HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';

@Component
struct PinmonyAboutInfoRow {
  @Prop icon: Resource = $r('sys.symbol.info_circle');
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop link: boolean = false;
  build() {
    Row({ space: 16 }) {
      Stack({ alignContent: Alignment.Center }) {
        SymbolGlyph(this.icon).fontSize(24).fontColor([$r('app.color.accent')])
          .accessibilityLevel('no')
      }.width(44).height(44).backgroundColor($r('app.color.page_background')).borderRadius(12)
        .accessibilityLevel('no')
      Column({ space: 6 }) {
        Text(this.title).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
        Text(this.description).fontSize(14).fontColor($r('app.color.secondary_text')).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (this.link) {
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16)
          .fontColor([$r('app.color.secondary_text')]).accessibilityLevel('no')
      }
    }.width('100%').padding(18)
  }

}

@Component
export struct PinmonyAboutPage {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  onBack?: () => void;
  onOpenExternalLink?: (url: string) => Promise<void>;
  @State private version: string = PinmonyI18n.message("pm_loading_86b6d0d6");
  @State private openingLink: boolean = false;
  @State private release: PinmonyRelease | undefined = undefined;
  @State private newerReleases: PinmonyRelease[] = [];
  @State private updateStatus: string = PinmonyI18n.message("pm_checking_for_updates_91834aeb");
  @State private hasUpdate: boolean = false;
  private installedVersion: string = '';
  private releaseChecking: boolean = false;
  private releaseClient: PinmonyReleaseClient = new PinmonyReleaseClient();
  private visible: boolean = false;
  private paths: NavPathStack = new NavPathStack();
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.visible = true;
    this.paths.clear();
    this.paths.pushPath({ name: 'about' }, false);
    this.readVersion();
  }
  aboutToDisappear(): void { this.visible = false; this.releaseClient.cancel(); }
  private async readVersion(): Promise<void> {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      if (this.visible) {
        this.version = info.versionName + ' (' + info.versionCode.toString() + ')';
        this.installedVersion = info.versionName;
        this.checkUpdate();
      }
    } catch (_) {
      if (this.visible) { this.version = PinmonyI18n.message("pm_version_information_unavailable_7d6fa6b1"); this.updateStatus = PinmonyI18n.message("pm_unable_to_compare_versions_check_the_releases_page_82efead4"); }
    }
  }
  private async checkUpdate(): Promise<void> {
    if (PinmonyI18n.isText(this.updateStatus, "正在检查更新…") && this.releaseChecking) return;
    this.releaseChecking = true;
    this.updateStatus = PinmonyI18n.message("pm_checking_for_updates_91834aeb");
    PinmonyRuntimeLog.info('ReleaseCheck: event=page-check');
    try {
      const release = await this.releaseClient.latest(this.installedVersion);
      if (!this.visible) return;
      this.release = release;
      this.hasUpdate = !!release && isNewerRelease(release.tag_name, this.installedVersion);
      this.newerReleases = (this.releaseClient.releases || (release ? [release] : []))
        .filter((item: PinmonyRelease) => isNewerRelease(item.tag_name, this.installedVersion));
      this.updateStatus = release ? this.hasUpdate ? PinmonyI18n.message("pm_latest_release_80413ee5") + release.tag_name : PinmonyI18n.message("pm_you_are_up_to_date_6e865701") : PinmonyI18n.message("pm_no_stable_releases_yet_b8a12ee2");
    } catch (error) {
      if (this.visible) this.updateStatus = error instanceof PinmonyReleaseFailure ? error.feedback : PinmonyI18n.message("pm_update_check_failed_tap_to_retry_7cc33419");
    } finally { this.releaseChecking = false; }
  }
  private async openLink(url: string): Promise<void> {
    if (this.openingLink) return;
    this.openingLink = true;
    try {
      if (!this.onOpenExternalLink) throw new Error(this.uiText("pm_opening_links_unavailable_2fcda15e"));
      await this.onOpenExternalLink(url);
    } catch (_) {
      if (this.visible) {
        try { this.getUIContext().getPromptAction().showToast({ message: this.uiText("pm_unable_to_open_link_please_retry_99322633"), duration: 3000 }); }
        catch (_) { PinmonyRuntimeLog.warn('About: link failure feedback unavailable'); }
      }
    } finally { this.openingLink = false; }
  }

  @Builder
  private destination() {
    HdsNavDestination() {
      Column() {
      List({ space: 16, scroller: this.scroller }) {
        ListItem() {
          Column({ space: 12 }) {
            Row() {
              Image($r('app.media.pinmony_logo')).width(96).height(96).borderRadius(24)
                .objectFit(ImageFit.Contain).objectRepeat(ImageRepeat.NoRepeat)
                .accessibilityText(this.uiText("pm_pinmony_app_icon_66c94919"))
            }.width('100%').height(96).justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
            Text('Pinmony').fontSize(30).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
            Text(this.uiText("pm_find_inspiration_save_what_you_love_2499cd29")).fontSize(16).fontColor($r('app.color.secondary_text'))
          }.width('100%').alignItems(HorizontalAlign.Center).padding({ top: 28, bottom: 20 })
        }
        ListItem() {
        Column({ space: 16 }) {
          Column() {
            PinmonyAboutInfoRow({ icon: $r('sys.symbol.info_circle'), title: this.uiText("pm_current_version_837bc957"), description: this.version })
          }.width('100%').backgroundColor($r('app.color.input_surface')).borderRadius(20).clip(true)
          Column() {
            Button({ type: ButtonType.Normal }) {
              PinmonyAboutInfoRow({ icon: $r('sys.symbol.arrow_down_circle'), title: this.hasUpdate && this.release ? this.uiText("pm_new_version_available_596dd46c") + this.release.tag_name : this.uiText("pm_app_updates_42e40f43"), description: PinmonyI18n.render(this.updateStatus, this.uiLanguage), link: this.hasUpdate })
            }.width('100%').backgroundColor(Color.Transparent).enabled(!this.openingLink && !PinmonyI18n.isText(this.updateStatus, "正在检查更新…"))
              .onClick(() => {
                if (PinmonyI18n.includesText(this.updateStatus, '检查更新失败')) this.checkUpdate();
                else if (this.hasUpdate && this.release) this.openLink(this.release.html_url);
                else this.checkUpdate();
              })
            if (this.hasUpdate && this.release) {
              Divider().color($r('app.color.surface_muted')).margin({ left: 78, right: 18 })
              Button({ type: ButtonType.Normal }) {
                PinmonyAboutInfoRow({ icon: $r('sys.symbol.arrow_down'), title: this.uiText("pm_download_55c561dc"), description: this.uiText("pm_open_releases_in_browser_5cb655da"), link: true })
              }.width('100%').backgroundColor(Color.Transparent).enabled(!this.openingLink)
                .onClick(() => { if (this.release) this.openLink(this.release.html_url); })
            }
          }.width('100%').backgroundColor($r('app.color.input_surface')).borderRadius(20).clip(true)
          ForEach(this.newerReleases, (item: PinmonyRelease) => {
            Column({ space: 12 }) {
              Text(item.tag_name + this.uiText("pm_release_notes_e0b4bf83")).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
              Text(item.body || this.uiText("pm_no_release_notes_provided_for_this_version_631cfa84")).fontSize(15).fontColor($r('app.color.secondary_text')).width('100%')
            }.width('100%').alignItems(HorizontalAlign.Start).padding(18)
              .backgroundColor($r('app.color.input_surface')).borderRadius(20)
          }, (item: PinmonyRelease) => item.tag_name)
          Column() {
            PinmonyAboutInfoRow({ icon: $r('sys.symbol.info_circle'), title: this.uiText("pm_about_the_project_224e0b60"), description:
              this.uiText("pm_an_unofficial_pinterest_client_for_harmonyos_with_a_native_arkui_5990368f") })
            Divider().color($r('app.color.surface_muted')).margin({ left: 78, right: 18 })
            Button({ type: ButtonType.Normal }) {
              PinmonyAboutInfoRow({ icon: $r('sys.symbol.link'), title: this.uiText("pm_source_code_606a4e58"), description: 'github.com/Torotar/Pinmony', link: true })
            }.width('100%').backgroundColor(Color.Transparent).enabled(!this.openingLink)
              .onClick(() => { this.openLink('https://github.com/Torotar/Pinmony'); })
              .accessibilityText(this.uiText("pm_source_code_open_the_pinmony_github_repository_491e45d7"))
            Divider().color($r('app.color.surface_muted')).margin({ left: 78, right: 18 })
            Button({ type: ButtonType.Normal }) {
              PinmonyAboutInfoRow({ icon: $r('sys.symbol.exclamationmark_circle'), title: this.uiText("pm_feedback_55a2ce13"), description: this.uiText("pm_submit_on_github_issues_e4865aa9"), link: true })
            }.width('100%').backgroundColor(Color.Transparent).enabled(!this.openingLink)
              .onClick(() => { this.openLink('https://github.com/Torotar/Pinmony/issues'); })
              .accessibilityText(this.uiText("pm_feedback_open_github_issues_3c152b53"))
            Divider().color($r('app.color.surface_muted')).margin({ left: 78, right: 18 })
            PinmonyAboutInfoRow({ icon: $r('sys.symbol.doc_text'), title: this.uiText("pm_open_source_license_038ad816"), description: 'Apache License 2.0' })
          }.width('100%').backgroundColor($r('app.color.input_surface')).borderRadius(20).clip(true)
        }.width('100%').padding({ left: 20, right: 20, bottom: 28 })
        }
      }.width('100%').layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      }.width('100%').height('100%').backgroundColor($r('app.color.page_background'))
    }.titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: true,
      style: { scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE },
        scrollEffectStyle: { contentStyle: { backIconStyle: { iconColor: $r('app.color.primary_text') }, menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { iconColor: $r('app.color.primary_text') }, menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },  backgroundStyle: {
        backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0 } } },
      content: { title: { mainTitle: this.uiText("pm_about_52d25a9e") }, backIcon: { isEnabled: true, action: () => { if (this.onBack) this.onBack(); } } } })
      .titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.scroller])
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .onBackPressed(() => { if (this.onBack) this.onBack(); return true; })
      .backgroundColor($r('app.color.page_background'))
  }
  build() {
    HdsNavigation(this.paths) {
      Column().width('100%').height('100%').backgroundColor($r('app.color.page_background'))
    }.width('100%').height('100%').hideTitleBar(true).navDestination(this.destination)
      .mode(NavigationMode.Stack)
      .backgroundColor($r('app.color.page_background'))
  }
}
