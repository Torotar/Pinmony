import { PinmonyDraggablePublishButton, PinmonyActionNotice } from 'common_ui';
import { BlurStrategy } from '@kit.UIDesignKit';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { PinmonyLoadingOverlay } from 'common_ui';
import { PinmonyPublishFlow, PinmonyPublishDraft } from '../models/PinmonyPublishFlow';
import { PinmonyPublishPhotoEditor, PinmonyPublishPhotoViewState } from './PinmonyPublishPhotoEditor';
import { PinmonyPublishBoardPage } from './PinmonyPublishBoardPage';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';

@Component
export struct PinmonyPublishPage {
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  private get immersiveLightEnabled(): boolean { return this.immersiveLightMode !== 'off'; }
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop state: PinmonyPublishFlow;
  @State private link: string = '';
  @State private sourceAreaWidth: number = 0;
  @State private sourceAreaHeight: number = 0;
  @State private showDraftExpiryTip: boolean = false;
  private readonly photoViewState: PinmonyPublishPhotoViewState = new PinmonyPublishPhotoViewState();
  private readonly stack: NavPathStack = new NavPathStack();
  private readonly scroller: Scroller = new Scroller();
  onAction: (action: string, value: string, secret: boolean) => void = () => {};
  aboutToAppear(): void { this.stack.pushPath({ name: 'publish' }, false); }

  private act(action: string): void { this.onAction(action, action === 'scrape' ? this.link.trim() : action === 'back' ? this.state.phase : '', false); }
  private submitWebsite(): void {
    if (!this.canReadWebsite()) return;
    this.act('scrape');
  }

  private canReadWebsite(): boolean {
    return /^https?:\/\//i.test(this.link.trim()) && !this.state.loading && !this.state.busy;
  }

  private confirmDeleteDraft(draftId: string): void {
    if (this.state.busy || this.state.uncertain || this.state.draftLoading) return;
    const token: number = this.state.token;
    this.getUIContext().showAlertDialog({
      title: this.uiText('pm_pin_draft_delete_title'),
      message: this.uiText('pm_pin_draft_delete_message'),
      primaryButton: { value: this.uiText('pm_delete_2f9daa82'), action: () => {
        if (this.state.token === token && this.state.phase === 'photo' &&
          !this.state.busy && !this.state.uncertain && !this.state.draftLoading &&
          (this.state.drafts || []).some((draft: PinmonyPublishDraft): boolean => draft.id === draftId)) {
          this.onAction('deleteDraft', draftId, false);
        }
      } },
      secondaryButton: { value: this.uiText('pm_cancel_2cd0f3be'), action: (): void => {} }
    });
  }

  private titleBar(): HdsNavigationTitleBarOptions {
    const draftTitle: string = this.uiText("pm_publish_draft_box") + ' · ' + PinmonyI18n.format('pm_pin_drafts_count', [(this.state.drafts || []).length], this.uiLanguage);
    return { avoidLayoutSafeArea: true, enableComponentSafeArea: true,
      style: { blurStrategy: this.immersiveLightEnabled ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: this.immersiveLightEnabled,
        scrollEffectOpts: { enableScrollEffect: this.immersiveLightEnabled, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        originalStyle: {
          backgroundStyle: { backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0 },
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
      content: { title: { mainTitle: this.state.phase === 'empty' ? this.uiText("pm_choose_image_9ad12a1a") : this.state.kind === 'photo' ? draftTitle : this.uiText("pm_website_fb8d739d") },
        backIcon: { label: this.uiText("pm_back_572cf45b"), isEnabled: !this.state.busy, action: () => this.act(this.state.phase === 'empty' || this.state.fromDraftBox ? 'back' : 'close') },
        menu: { value: this.state.phase === 'photo' ? [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.info_circle')).fontSize(22).fontColor([$r('app.color.primary_text')]),
          label: this.uiText('pm_pin_drafts_expiry'), isEnabled: true,
          action: () => { this.showDraftExpiryTip = !this.showDraftExpiryTip; }
        } }] : this.state.phase === 'website' ? [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.arrow_right')).fontColor([$r('app.color.primary_text')]),
          label: this.uiText("pm_choose_image_9ad12a1a"), isEnabled: this.canReadWebsite(),
          action: () => { if (this.canReadWebsite()) this.submitWebsite(); }
        } }] : [] } } };
  }

  @Builder
  private websiteSheet() {
    Column() {
      TextInput({ text: this.link, placeholder: this.uiText("pm_enter_a_link_to_create_a_pin_https_89a0cd78") })
        .maxLength(4096).enabled(!this.state.loading)
        .onChange((v: string) => { this.link = v; })
    }.width('100%').backgroundColor($r('app.color.page_background'))
  }
  private photoSources(): MenuElement[] {
    return [
      {value:this.uiText('pm_publish_source_files'),action:() => this.act('pickPhoto')},
      {value:this.uiText('pm_publish_source_website'),action:() => this.act('websiteFromPhoto')}
    ];
  }
  @Builder
  private draftFlow() {
    WaterFlow({scroller:this.scroller}) {
      ForEach(this.state.drafts || [], (draft: PinmonyPublishDraft) => {
        FlowItem() {
          Column({space:6}) {
            Stack({alignContent:Alignment.BottomEnd}) {
              Image(draft.imageUrl).width('100%').aspectRatio(draft.imageWidth > 0 && draft.imageHeight > 0 ? draft.imageWidth / draft.imageHeight : 0.65).objectFit(ImageFit.Cover).borderRadius(16).onClick(() => this.onAction('openDraft',draft.id,false))
              Button() { SymbolGlyph($r('sys.symbol.trash')).fontSize(22).fontColor([$r('app.color.primary_text')]) }.type(ButtonType.Normal).width(40).height(40).borderRadius(16).backgroundColor($r('app.color.page_background')).margin(8).accessibilityText(this.uiText('pm_delete_2f9daa82')).enabled(!this.state.busy && !this.state.uncertain && !this.state.draftLoading).onClick(() => this.confirmDeleteDraft(draft.id))
            }.width('100%')
            if (draft.expiresAt) { Text(PinmonyI18n.format('pm_pin_drafts_days',[Math.max(0,Math.ceil((draft.expiresAt - Date.now()) / 86400000))],this.uiLanguage)).fontSize(16).fontColor($r('app.color.primary_text')).width('100%') }
          }.width('100%')
        }.width('100%')
      }, (draft: PinmonyPublishDraft) => draft.id + ':' + this.uiLanguage)
      if (this.state.error) { FlowItem() { PinmonyActionNotice({message:PinmonyI18n.render(this.state.error,this.uiLanguage)}) } }
    }.columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(16)
      .width('100%').height('100%').padding(16).scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring,{alwaysEnabled:true})
  }
  @Builder
  private destination(_name?: string, _param?: Object) {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
      Stack({alignContent:Alignment.Center}) {
      if (this.state.phase === 'photo' && !this.state.loading && !this.state.draftLoading && !this.state.draftError && (this.state.drafts || []).length > 0) {
        this.draftFlow()
      } else {
      Scroll(this.scroller) {
        Column({ space: 20 }) {
          if (this.state.phase === 'website') {
            this.websiteSheet()
          } else if (this.state.phase === 'empty') {
            PinmonyActionNotice({ message: this.uiText("pm_no_images_available_to_create_a_pin_b7fe6e0c"), actionText: this.uiText("pm_go_back_and_retry_fa25b166"), onAction: () => this.act('back') })
          } else if (this.state.phase === 'photo' && !this.state.loading) {
            if (this.state.draftLoading) { Column() }
            else if (this.state.draftError) {
              PinmonyActionNotice({ message: PinmonyI18n.render(this.state.draftError,this.uiLanguage) })
            } else if (!(this.state.drafts || []).length) {
              Column()
            } else {
              Column()
            }
          }
          if (this.state.error) { PinmonyActionNotice({ message: PinmonyI18n.render(this.state.error,this.uiLanguage) }) }
        }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
      }.width('100%').height('100%').align(Alignment.TopStart).scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring,{alwaysEnabled:true})
      }
      if (this.state.phase === 'photo' && !this.state.loading && !this.state.draftLoading && !this.state.draftError && !(this.state.drafts || []).length) {
        Text(this.uiText('pm_pin_drafts_empty')).fontSize(16).textAlign(TextAlign.Center).fontColor($r('app.color.secondary_text'))
      }
      }.width('100%').layoutWeight(1)
      }.width('100%').height('100%').onAreaChange((_old: Area,area: Area) => {this.sourceAreaWidth = Number(area.width);this.sourceAreaHeight = Number(area.height);})
      if (this.state.phase === 'photo') { PinmonyDraggablePublishButton({areaWidth:this.sourceAreaWidth,areaHeight:this.sourceAreaHeight,actionEnabled:!this.state.loading && !this.state.busy && !this.state.draftLoading,menuEnabled:true,menuItems:this.photoSources()}) }
      if (this.state.phase === 'photo' && this.showDraftExpiryTip) {
        Text(this.uiText('pm_pin_drafts_expiry')).fontSize(14).fontColor($r('app.color.primary_text'))
          .backgroundColor($r('app.color.surface_muted')).padding({left:14,right:14,top:10,bottom:10})
          .borderRadius(10).margin({top:8,right:12}).shadow({radius:8,color:'#26000000',offsetX:0,offsetY:3})
          .onClick(() => { this.showDraftExpiryTip = false; })
      }
      }
    }.titleBar(this.titleBar()).titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.scroller])
      .onBackPressed(() => { this.act(this.state.phase === 'empty' ? 'back' : 'close'); return true; })
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .backgroundColor($r('app.color.page_background'))
  }
  build() {
    if (this.state.kind === 'photo' && ['select','topics','products','productImages','productSearch','productConfirm','advanced'].includes(this.state.phase)) {
      PinmonyPublishPhotoEditor({state:this.state,viewState:this.photoViewState,onAction:this.onAction})
    } else if (['select','boards','sections','create'].includes(this.state.phase)) {
      PinmonyPublishBoardPage({state:this.state,pins:this.state.pins,pinsLoading:this.state.loading,onAction:this.onAction})
    } else {
      Stack({alignContent:Alignment.Center}) {
        HdsNavigation(this.stack) { Column().width('100%').height('100%') }.width('100%').height('100%').hideTitleBar(true).navDestination(this.destination).backgroundColor($r('app.color.page_background'))
        if (this.state.kind === 'photo' && (this.state.loading || this.state.draftLoading)) { LoadingProgress().color($r('app.color.accent')).width(28).height(28).hitTestBehavior(HitTestMode.None) }
        else if (this.state.loading || this.state.busy) { PinmonyLoadingOverlay({message:this.uiText('pm_loading_photos_35b3ef9b')}) }
      }.width('100%').height('100%')
    }
  }
}
