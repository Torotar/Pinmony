import { ComponentContent } from '@kit.ArkUI';
import { PinmonyDraftExpiryTipOptions, buildPinmonyDraftExpiryTip } from './PinmonyDraftExpiryTip';
import { PinmonyHdsTitleBar } from 'common_ui';
import { LengthMetrics } from '@kit.ArkUI';
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

interface PinmonyPublishDestinationState {
  phase: string;
  websiteChild: boolean;
}

@Component
export struct PinmonyPublishPage {
  @StorageLink('systemDarkMode') private hdsDarkMode: boolean = false;
  @StorageLink('statusBarHeightPx') private statusBarHeightPx: number = 0;
  private titleContentInset(): number { return this.getUIContext().px2vp(this.statusBarHeightPx) + 56; }
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop @Watch('syncDraftCards') state: PinmonyPublishFlow;
  @State private draftCards: PinmonyPublishDraft[] = [];
  @State private draftLayoutRevision: number = 0;
  private draftCardsToken: number = -1;
  @State private link: string = '';
  @State private sourceAreaWidth: number = 0;
  @State private sourceAreaHeight: number = 0;
  private showDraftExpiryTip: boolean = false;
  private draftExpiryOpening: boolean = false;
  private draftExpiryContent: ComponentContent<PinmonyDraftExpiryTipOptions> | undefined = undefined;
  private readonly photoViewState: PinmonyPublishPhotoViewState = new PinmonyPublishPhotoViewState();
  private readonly stack: NavPathStack = new NavPathStack();
  private readonly scroller: Scroller = new Scroller();
  private readonly websiteScroller: Scroller = new Scroller();
  private draftRoot: boolean = false;
  private mounted: boolean = false;
  @State private websiteRouteOpen: boolean = false;
  @State private websiteClosing: boolean = false;
  @State private websiteMotionOffset: string = '100%';
  onAction: (action: string, value: string, secret: boolean) => void = () => {};
  aboutToAppear(): void {
    this.mounted = true;
    this.draftRoot = this.state.kind === 'photo' || !!this.state.fromDraftBox;
    this.stack.pushPath({ name: 'publish' }, false);
    this.syncDraftCards();
  }
  aboutToDisappear(): void { this.mounted = false; this.dismissDraftExpiryTip(); }

  private async toggleDraftExpiryTip(): Promise<void> {
    if (!this.mounted || this.state.phase !== 'photo' || this.websiteRouteOpen) return;
    if (this.showDraftExpiryTip) { await this.dismissDraftExpiryTip(); return; }
    if (this.draftExpiryOpening) return;
    this.showDraftExpiryTip = true; this.draftExpiryOpening = true;
    try {
      if (!this.draftExpiryContent) this.draftExpiryContent = new ComponentContent<PinmonyDraftExpiryTipOptions>(this.getUIContext(),
        wrapBuilder(buildPinmonyDraftExpiryTip), { source: 'pm_pin_drafts_expiry' });
      await this.getUIContext().getPromptAction().openPopup(this.draftExpiryContent,
        { id: 'pinmony-draft-expiry-info' }, {
          placement: Placement.BottomRight, enableArrow: true, autoCancel: true,
          popupColor: $r('app.color.page_background'),
          onStateChange: (event: PopupStateChangeParam): void => {
            if (!event.isVisible) this.showDraftExpiryTip = false;
          }
        });
    } catch (_) { this.showDraftExpiryTip = false; }
    finally { this.draftExpiryOpening = false; }
    if (!this.mounted || !this.showDraftExpiryTip || this.state.phase !== 'photo' || this.websiteRouteOpen) {
      await this.dismissDraftExpiryTip();
    }
  }

  private async dismissDraftExpiryTip(): Promise<void> {
    this.showDraftExpiryTip = false;
    const content: ComponentContent<PinmonyDraftExpiryTipOptions> | undefined = this.draftExpiryContent;
    if (!content || this.draftExpiryOpening) return;
    try { await this.getUIContext().getPromptAction().closePopup(content); }
    catch (_) { /* The system may already have dismissed the popup. */ }
    if (!this.mounted && this.draftExpiryContent === content) {
      content.dispose(); this.draftExpiryContent = undefined;
    }
  }

  private syncWebsiteRoute(): void {
    const open: boolean = !!this.state.fromDraftBox && this.state.kind === 'website';
    if (open && !this.websiteRouteOpen) {
      this.websiteRouteOpen = true;
      this.websiteClosing = false;
      this.stack.pushPath({ name: 'draft-website' }, true);
    } else if (!open && this.websiteRouteOpen && !this.websiteClosing && this.state.phase === 'photo') {
      this.websiteClosing = true;
      this.stack.pop(true);
    }
  }

  private websiteTransition(from: NavContentInfo, to: NavContentInfo,
    operation: NavigationOperation): NavigationAnimatedTransition | undefined {
    if (from.name !== 'draft-website' && to.name !== 'draft-website') return undefined;
    const closing: boolean = operation === NavigationOperation.POP;
    return {
      timeout: 400,
      transition: (proxy: NavigationTransitionProxy): void => {
        this.websiteMotionOffset = closing ? '0%' : '100%';
        this.getUIContext().postFrameCallback({ onFrame: (): void => {}, onIdle: (): void => {
          if (!this.mounted) { proxy.finishTransition(); return; }
          this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut,
            onFinish: (): void => { proxy.finishTransition(); } }, (): void => {
            this.websiteMotionOffset = closing ? '100%' : '0%';
          });
        } });
      },
      onTransitionEnd: (_success: boolean): void => {
        if (closing) { this.websiteRouteOpen = false; this.websiteClosing = false; }
      }
    };
  }

  private destinationPhase(name: string): string {
    if (name === 'draft-website') return this.state.phase === 'empty' ? 'empty' : 'website';
    return this.draftRoot ? 'photo' : this.state.phase;
  }

  private pageBack(phase: string): void {
    this.dismissDraftExpiryTip();
    if (this.websiteClosing || phase !== this.state.phase || this.state.busy) return;
    this.act(phase === 'empty' || this.state.fromDraftBox ? 'back' : 'close');
  }

  private syncDraftCards(): void {
    if (this.state.phase !== 'photo' || this.state.kind !== 'photo') this.dismissDraftExpiryTip();
    this.syncWebsiteRoute();
    const next: PinmonyPublishDraft[] = (this.state.drafts || []).slice();
    const removed: boolean = this.draftCardsToken === this.state.token && this.state.phase === 'photo' &&
      !this.state.draftLoading && next.length < this.draftCards.length &&
      next.every((draft: PinmonyPublishDraft): boolean => this.draftCards.some((previous: PinmonyPublishDraft): boolean => previous.id === draft.id));
    this.draftCardsToken = this.state.token;
    if (removed) {
      this.getUIContext().animateTo({ duration: 280, curve: Curve.EaseOut }, () => {
        this.draftCards = next;
        this.draftLayoutRevision++;
      });
    } else {
      this.draftCards = next;
    }
  }

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

  private readonly retainedDraftSections: WaterFlowSections = new WaterFlowSections();
  private draftSectionCount: number = -1;
  private draftSectionInset: number = -1;
  private draftSections(): WaterFlowSections {
    const count: number = this.draftCards.length + (this.state.error ? 1 : 0);
    const inset: number = this.titleContentInset() + 16;
    if (count !== this.draftSectionCount || inset !== this.draftSectionInset) {
      this.retainedDraftSections.splice(0,this.retainedDraftSections.length(),[{itemsCount:count,crossCount:2,columnsGap:12,rowsGap:16,margin:{left:16,right:16,top:inset,bottom:16}}]);
      this.draftSectionCount = count;this.draftSectionInset = inset;
    }
    return this.retainedDraftSections;
  }
  private titleBar(phase: string): HdsNavigationTitleBarOptions {
    const draftTitle: string = this.uiText("pm_publish_draft_box") + ' · ' + PinmonyI18n.format('pm_pin_drafts_count', [(this.state.drafts || []).length], this.uiLanguage);
    return { avoidLayoutSafeArea: true, enableComponentSafeArea: false,
      style: { blurStrategy: (this.immersiveLightMode !== 'off') ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: (this.immersiveLightMode !== 'off'),
        scrollEffectOpts: { enableScrollEffect: (this.immersiveLightMode !== 'off'), scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        originalStyle: {
          backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0 },
          contentStyle: {
            backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') },
            menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') },
            titleStyle: { mainTitleColor: $r('app.color.primary_text') }
          }
        },
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: (this.immersiveLightMode !== 'off') ? 18 : 0 },
          contentStyle: {
            backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') },
            menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') },
            titleStyle: { mainTitleColor: $r('app.color.primary_text') }
          }
        }
      },
      content: { title: { mainTitle: phase === 'empty' ? this.uiText("pm_choose_image_9ad12a1a") : phase === 'photo' ? draftTitle : this.uiText("pm_website_fb8d739d") },
        backIcon: { label: this.uiText("pm_back_572cf45b"), isEnabled: !this.state.busy, action: () => this.pageBack(phase) },
        menu: { value: phase === 'photo' ? [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.info_circle')).fontSize(22).fontColor([$r('app.color.primary_text')]),
          label: this.uiText('pm_pin_drafts_expiry'), isEnabled: true,
          componentId: 'pinmony-draft-expiry-info',
          action: () => { this.toggleDraftExpiryTip(); }
        } }] : phase === 'website' ? [{ content: {
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
    WaterFlow({scroller:this.scroller,sections:this.draftSections()}) {
      ForEach(this.draftCards, (draft: PinmonyPublishDraft) => {
        FlowItem() {
          Column({space:6}) {
            Stack({alignContent:Alignment.BottomEnd}) {
              Image(draft.imageUrl).width('100%').aspectRatio(draft.imageWidth > 0 && draft.imageHeight > 0 ? draft.imageWidth / draft.imageHeight : 0.65).objectFit(ImageFit.Cover).borderRadius(16).onClick(() => this.onAction('openDraft',draft.id,false))
              Button() { SymbolGlyph($r('sys.symbol.trash')).fontSize(22).fontColor([$r('app.color.primary_text')]) }.type(ButtonType.Normal).width(40).height(40).borderRadius(16).backgroundColor($r('app.color.page_background')).margin(8).accessibilityText(this.uiText('pm_delete_2f9daa82')).enabled(!this.state.busy && !this.state.uncertain && !this.state.draftLoading).onClick(() => this.confirmDeleteDraft(draft.id))
            }.width('100%')
            if (draft.expiresAt) { Text(PinmonyI18n.format('pm_pin_drafts_days',[Math.max(0,Math.ceil((draft.expiresAt - Date.now()) / 86400000))],this.uiLanguage)).fontSize(16).fontColor($r('app.color.primary_text')).width('100%') }
          }.width('100%')
            .geometryTransition('pinmony-draft-layout-' + this.state.token.toString() + '-' + draft.id, { follow: true })
        }.width('100%')
      }, (draft: PinmonyPublishDraft) => draft.id + ':' + this.uiLanguage + ':' + this.draftLayoutRevision.toString())
      if (this.state.error) { FlowItem() { PinmonyActionNotice({message:PinmonyI18n.render(this.state.error,this.uiLanguage)}) } }
    }.columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(16)
      .width('100%').height('100%').scrollBar(BarState.Off).scrollBarMargin({start:LengthMetrics.vp(this.titleContentInset())}).edgeEffect(EdgeEffect.Spring,{alwaysEnabled:true})
  }
  @Builder
  private destination(name: string, _param?: Object) {
    this.pageDestination({ phase: this.destinationPhase(name), websiteChild: name === 'draft-website' })
  }
  @Builder
  private pageDestination($$: PinmonyPublishDestinationState) {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
      Stack({alignContent:Alignment.Center}) {
      if ($$.phase === 'photo' && (!this.state.loading || this.websiteRouteOpen) && !this.state.draftLoading && !this.state.draftError && (this.state.drafts || []).length > 0) {
        this.draftFlow()
      } else {
      Scroll($$.websiteChild ? this.websiteScroller : this.scroller) {
        Column({ space: 20 }) {
          if ($$.phase === 'website') {
            this.websiteSheet()
          } else if ($$.phase === 'empty') {
            PinmonyActionNotice({ message: this.uiText("pm_no_images_available_to_create_a_pin_b7fe6e0c"), actionText: this.uiText("pm_go_back_and_retry_fa25b166"), onAction: () => this.act('back') })
          } else if ($$.phase === 'photo' && (!this.state.loading || this.websiteRouteOpen)) {
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
        }.width('100%').alignItems(HorizontalAlign.Start).padding({left:16,right:16,top:this.titleContentInset() + 16,bottom:16})
      }.width('100%').height('100%').align(Alignment.TopStart).scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring,{alwaysEnabled:true})
      }
      if ($$.phase === 'photo' && (!this.state.loading || this.websiteRouteOpen) && !this.state.draftLoading && !this.state.draftError && !(this.state.drafts || []).length) {
        Text(this.uiText('pm_pin_drafts_empty')).fontSize(16).textAlign(TextAlign.Center).fontColor($r('app.color.secondary_text'))
      }
      }.width('100%').layoutWeight(1)
      }.width('100%').height('100%').onAreaChange((_old: Area,area: Area) => {this.sourceAreaWidth = Number(area.width);this.sourceAreaHeight = Number(area.height);})
      if ($$.phase === 'photo') { PinmonyDraggablePublishButton({areaWidth:this.sourceAreaWidth,areaHeight:this.sourceAreaHeight,actionEnabled:!this.websiteRouteOpen && !this.websiteClosing && !this.state.loading && !this.state.busy && !this.state.draftLoading,menuEnabled:!this.websiteRouteOpen && !this.websiteClosing,menuItems:this.photoSources()}) }

      }
    }.titleBar(PinmonyHdsTitleBar.resolve(this.getUIContext(), this.titleBar($$.phase), this.hdsDarkMode)).titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([$$.websiteChild ? this.websiteScroller : this.scroller])
      .translate({ x: $$.websiteChild ? this.websiteMotionOffset : '0%' })
      .hitTestBehavior(!$$.websiteChild && this.websiteRouteOpen ? HitTestMode.None : HitTestMode.Default)
      .accessibilityLevel(!$$.websiteChild && this.websiteRouteOpen ? 'no-hide-descendants' : 'auto')
      .onBackPressed(() => { this.pageBack(this.state.phase); return true; })
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .backgroundColor($r('app.color.page_background'))
  }
  build() {
    if (this.state.kind === 'photo' && ['select','topics','products','productImages','productSearch','productConfirm','advanced'].includes(this.state.phase)) {
      PinmonyPublishPhotoEditor({state:this.state,viewState:this.photoViewState,onAction:this.onAction})
        .zIndex(1)
        .transition(TransitionEffect.asymmetric(
          TransitionEffect.translate({ x: '100%' }).animation({ duration: 180, curve: Curve.EaseOut }),
          TransitionEffect.translate({ x: '100%' }).animation({ duration: 150, curve: Curve.EaseIn })))
    } else if (['select','boards','sections','create'].includes(this.state.phase)) {
      PinmonyPublishBoardPage({state:this.state,pins:this.state.pins,pinsLoading:this.state.loading,onAction:this.onAction})
    } else {
      Stack({alignContent:Alignment.Center}) {
        HdsNavigation(this.stack) { Column().width('100%').height('100%') }.mode(NavigationMode.Stack).customNavContentTransition((from: NavContentInfo, to: NavContentInfo, operation: NavigationOperation) => this.websiteTransition(from, to, operation)).width('100%').height('100%').hideTitleBar(true).navDestination(this.destination).backgroundColor($r('app.color.page_background'))
        if (this.state.kind === 'photo' && (this.state.loading || this.state.draftLoading)) { LoadingProgress().color($r('app.color.accent')).width(28).height(28).hitTestBehavior(HitTestMode.None) }
        else if (this.state.loading || this.state.busy) { PinmonyLoadingOverlay({message:this.uiText('pm_loading_photos_35b3ef9b')}) }
      }.width('100%').height('100%')
        .zIndex(0)
        .transition(TransitionEffect.asymmetric(
          TransitionEffect.IDENTITY,
          TransitionEffect.IDENTITY))
    }
  }
}
