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
  onBack?: () => void;
  onOpenExternalLink?: (url: string) => Promise<void>;
  @State private version: string = '正在读取…';
  @State private openingLink: boolean = false;
  @State private release: PinmonyRelease | undefined = undefined;
  @State private newerReleases: PinmonyRelease[] = [];
  @State private updateStatus: string = '正在检查更新…';
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
      if (this.visible) { this.version = '版本信息暂不可用'; this.updateStatus = '无法比较版本，请前往发布页查看'; }
    }
  }
  private async checkUpdate(): Promise<void> {
    if (this.updateStatus === '正在检查更新…' && this.releaseChecking) return;
    this.releaseChecking = true;
    this.updateStatus = '正在检查更新…';
    PinmonyRuntimeLog.info('ReleaseCheck: event=page-check');
    try {
      const release = await this.releaseClient.latest(this.installedVersion);
      if (!this.visible) return;
      this.release = release;
      this.hasUpdate = !!release && isNewerRelease(release.tag_name, this.installedVersion);
      this.newerReleases = (this.releaseClient.releases || (release ? [release] : []))
        .filter((item: PinmonyRelease) => isNewerRelease(item.tag_name, this.installedVersion));
      this.updateStatus = release ? this.hasUpdate ? '最新发布：' + release.tag_name : '当前已是最新版本' : '暂无正式发布版本';
    } catch (error) {
      if (this.visible) this.updateStatus = error instanceof PinmonyReleaseFailure ? error.feedback : '检查更新失败，点击重试';
    } finally { this.releaseChecking = false; }
  }
  private async openLink(url: string): Promise<void> {
    if (this.openingLink) return;
    this.openingLink = true;
    try {
      if (!this.onOpenExternalLink) throw new Error('链接打开不可用');
      await this.onOpenExternalLink(url);
    } catch (_) {
      if (this.visible) {
        try { this.getUIContext().getPromptAction().showToast({ message: '无法打开链接，请重试', duration: 3000 }); }
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
                .accessibilityText('Pinmony 应用图标')
            }.width('100%').height(96).justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
            Text('Pinmony').fontSize(30).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
            Text('发现灵感，收藏喜欢。').fontSize(16).fontColor($r('app.color.secondary_text'))
          }.width('100%').alignItems(HorizontalAlign.Center).padding({ top: 28, bottom: 20 })
        }
        ListItem() {
        Column({ space: 16 }) {
          Column() {
            PinmonyAboutInfoRow({ icon: $r('sys.symbol.info_circle'), title: '当前版本', description: this.version })
          }.width('100%').backgroundColor($r('app.color.input_surface')).borderRadius(20).clip(true)
          Column() {
            Button({ type: ButtonType.Normal }) {
              PinmonyAboutInfoRow({ icon: $r('sys.symbol.arrow_down_circle'), title: this.hasUpdate && this.release ? '发现新版本 ' + this.release.tag_name : '版本更新', description: this.updateStatus, link: this.hasUpdate })
            }.width('100%').backgroundColor(Color.Transparent).enabled(!this.openingLink && this.updateStatus !== '正在检查更新…')
              .onClick(() => {
                if (this.updateStatus.startsWith('检查更新失败')) this.checkUpdate();
                else if (this.hasUpdate && this.release) this.openLink(this.release.html_url);
                else this.checkUpdate();
              })
            if (this.hasUpdate && this.release) {
              Divider().color($r('app.color.surface_muted')).margin({ left: 78, right: 18 })
              Button({ type: ButtonType.Normal }) {
                PinmonyAboutInfoRow({ icon: $r('sys.symbol.arrow_down'), title: '前往下载', description: '在浏览器中打开发布页', link: true })
              }.width('100%').backgroundColor(Color.Transparent).enabled(!this.openingLink)
                .onClick(() => { if (this.release) this.openLink(this.release.html_url); })
            }
          }.width('100%').backgroundColor($r('app.color.input_surface')).borderRadius(20).clip(true)
          ForEach(this.newerReleases, (item: PinmonyRelease) => {
            Column({ space: 12 }) {
              Text(item.tag_name + ' 更新说明').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
              Text(item.body || '此版本未提供更新说明。').fontSize(15).fontColor($r('app.color.secondary_text')).width('100%')
            }.width('100%').alignItems(HorizontalAlign.Start).padding(18)
              .backgroundColor($r('app.color.input_surface')).borderRadius(20)
          }, (item: PinmonyRelease) => item.tag_name)
          Column() {
            PinmonyAboutInfoRow({ icon: $r('sys.symbol.info_circle'), title: '项目介绍', description:
              '为 HarmonyOS 打造的 Pinterest 非官方客户端，使用 ArkUI 呈现原生界面。个人兴趣开发，用于学习、技术研究与体验探索。' })
            Divider().color($r('app.color.surface_muted')).margin({ left: 78, right: 18 })
            Button({ type: ButtonType.Normal }) {
              PinmonyAboutInfoRow({ icon: $r('sys.symbol.link'), title: '源代码', description: 'github.com/Torotar/Pinmony', link: true })
            }.width('100%').backgroundColor(Color.Transparent).enabled(!this.openingLink)
              .onClick(() => { this.openLink('https://github.com/Torotar/Pinmony'); })
              .accessibilityText('源代码，打开 Pinmony GitHub 仓库')
            Divider().color($r('app.color.surface_muted')).margin({ left: 78, right: 18 })
            Button({ type: ButtonType.Normal }) {
              PinmonyAboutInfoRow({ icon: $r('sys.symbol.exclamationmark_circle'), title: '问题反馈', description: '前往 GitHub Issues 提交', link: true })
            }.width('100%').backgroundColor(Color.Transparent).enabled(!this.openingLink)
              .onClick(() => { this.openLink('https://github.com/Torotar/Pinmony/issues'); })
              .accessibilityText('问题反馈，打开 GitHub Issues')
            Divider().color($r('app.color.surface_muted')).margin({ left: 78, right: 18 })
            PinmonyAboutInfoRow({ icon: $r('sys.symbol.doc_text'), title: '开源许可', description: 'Apache License 2.0' })
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
      content: { title: { mainTitle: '关于' }, backIcon: { isEnabled: true, action: () => { if (this.onBack) this.onBack(); } } } })
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
