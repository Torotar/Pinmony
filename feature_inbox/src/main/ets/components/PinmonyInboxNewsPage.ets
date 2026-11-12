import { PinmonyHdsTitleBar } from 'common_ui';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions, BlurStrategy, ScrollEffectType } from '@kit.UIDesignKit';
import { PinmonyI18n, PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyActionNotice, PinmonyImmersiveLight } from 'common_ui';
import { PinmonyInboxFlowSnapshot, PinmonyInboxNewsCard } from '../models/PinmonyInboxFlow';
@Component
export struct PinmonyInboxNewsPage {
  @StorageLink('systemDarkMode') private hdsDarkMode: boolean = false;
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  @StorageLink('statusBarHeightPx') private statusBarHeightPx: number = 0;
  private titleContentInset(): number { return this.getUIContext().px2vp(this.statusBarHeightPx) + 56; }
  @Prop snapshot: PinmonyInboxFlowSnapshot;
  @Prop active: boolean = true;
  onAction: (action: string, value: string) => void = () => {};
  onMenu?: (url: string) => void;
  onCoveredBack?: () => boolean;
  private readonly scroller: Scroller = new Scroller();
  private restorePending: boolean = true;
  private readonly paths: NavPathStack = new NavPathStack();
  private text(key: string): string { return PinmonyI18n.text(key,this.uiLanguage); }
  private saveScroll(): void {
    if (!this.active) return;
    try {
      const offset: number = this.scroller.currentOffset().yOffset;
      if (Number.isFinite(offset) && offset >= 0 && offset <= 1000000) this.onAction('newsScroll', offset.toString());
    } catch (_) {
      PinmonyRuntimeLog.info('InboxNewsTrace: phase=scroll-unavailable');
    }
  }
  private act(action: string, value: string = ''): void {
    PinmonyRuntimeLog.info('InboxNewsTrace: phase=ui-action action=' + action + ' active=' + this.active.toString());
    if (!this.active) return;
    this.saveScroll();
    this.onAction(action, value);
  }
  private column(left: boolean): PinmonyInboxNewsCard[] {
    const first: PinmonyInboxNewsCard[] = [], second: PinmonyInboxNewsCard[] = [];
    let a: number = 0, b: number = 0;
    for(const card of this.snapshot.newsCards || []) {
      const weight: number = card.imageHeight / card.imageWidth + (card.kind === 'search' ? 0 : 0.25);
      if(a <= b){first.push(card);a += weight;}else{second.push(card);b += weight;}
    }
    return left ? first : second;
  }
  private titleOptions(): HdsNavigationTitleBarOptions {
    return {avoidLayoutSafeArea:true,enableComponentSafeArea:false,
      style:{ blurStrategy: (this.immersiveLightMode !== 'off') ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: (this.immersiveLightMode !== 'off'), scrollEffectOpts: { enableScrollEffect: (this.immersiveLightMode !== 'off'), scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: (this.immersiveLightMode !== 'off') ? 18 : 0 }, contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },  backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: (this.immersiveLightMode !== 'off') ? 18 : 0 } } },
      content:{title:{mainTitle:this.snapshot.title},backIcon:{label:this.text('pm_back_572cf45b'),isEnabled:true,action:():void => this.act('back')},menu:{value:[]}}};
  }
  @Builder private card(card: PinmonyInboxNewsCard) {
    Column({space:6}) {
      Stack({alignContent:Alignment.Center}) {
        Image(card.image).width('100%').aspectRatio(card.imageWidth / card.imageHeight)
          .objectFit(card.kind === 'search' ? ImageFit.Cover : ImageFit.Contain).borderRadius(16)
        if(card.kind === 'search') {
          Column() { Text(card.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White).maxLines(2).textAlign(TextAlign.Center) }
            .justifyContent(FlexAlign.Center).width('100%').height('100%').backgroundColor('#55000000').borderRadius(16).padding(8)
        }
      }.id('pinmony-news-photo-' + card.id).width('100%').aspectRatio(card.imageWidth / card.imageHeight).onClick(() => this.act('newsOpen',card.id)).accessibilityText(card.title || this.text('pm_pin_image_c269651e'))
      if(card.kind === 'pin') {
        if(card.title) { Text(card.title).width('100%').fontSize(13).fontColor($r('app.color.primary_text')).maxLines(2).textOverflow({overflow:TextOverflow.Ellipsis}).onClick(() => this.act('newsOpen',card.id)) }
        Row() {
          Blank()
          Button({ type: ButtonType.Circle, stateEffect: false }) { Image($r('app.media.lucide_ellipsis')).width(20).height(20).fillColor($r('app.color.primary_text')) }
            .width(36).height(30).backgroundColor(Color.Transparent).accessibilityText(this.text('pm_more_actions_9f07d2ce'))
            .onClick(() => {if(this.active){this.saveScroll();this.onMenu?.(card.target);}})
        }.width('100%')
      }
    }.width('100%').margin({bottom:16})
  }
  build() {
    HdsNavigation(this.paths) {
      HdsNavDestination() {
        Stack({alignContent:Alignment.Center}) {
          Scroll(this.scroller) {
            Column({space:16}) {
              Row({space:8}) {
                Column() { ForEach(this.column(true),(card: PinmonyInboxNewsCard) => { this.card(card) },(card: PinmonyInboxNewsCard): string => card.id + ':' + this.uiLanguage) }.layoutWeight(1)
                Column() { ForEach(this.column(false),(card: PinmonyInboxNewsCard) => { this.card(card) },(card: PinmonyInboxNewsCard): string => card.id + ':' + this.uiLanguage) }.layoutWeight(1)
              }.width('100%').alignItems(VerticalAlign.Top)
              if(this.snapshot.error) {
                PinmonyActionNotice({active:this.active,message:PinmonyI18n.render(this.snapshot.error,this.uiLanguage),actionText:this.text('pm_retry_b8784c8d'),onAction:():void => this.act('retry')})
              } else if(this.snapshot.newsEnded && !this.snapshot.loading) {
                Column({space:20}) {
                  Text(this.text('pm_news_explore_home')).fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).textAlign(TextAlign.Center)
                  Button(this.text('pm_news_start'), {type:ButtonType.Normal}).borderRadius(16).fontColor($r('app.color.primary_text')).backgroundColor($r('app.color.surface_muted')).onClick(() => this.act('newsHome'))
                }.width('100%').padding({top:24,bottom:40,left:12,right:12})
              } else if(this.snapshot.loading && !!this.snapshot.newsCards?.length) {
                LoadingProgress().width(32).height(32).color($r('app.color.accent'))
              }
            }.width('100%').padding({left:10,right:10,top:this.titleContentInset() + 8,bottom:24})
          }.width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.TopStart)
            .edgeEffect(EdgeEffect.Spring, {alwaysEnabled:true})
            .onAreaChange(() => {if(this.restorePending){this.restorePending = false;this.scroller.scrollTo({xOffset:0,yOffset:this.snapshot.newsScrollOffset || 0});}})
            .onScrollStop(() => {this.saveScroll();if(this.active && this.scroller.isAtEnd() && this.snapshot.hasMore && !this.snapshot.loading && !this.snapshot.error)this.act('more');})
          if(this.snapshot.loading && !this.snapshot.newsCards?.length) {
            Column() { LoadingProgress().width(40).height(40).color($r('app.color.accent')) }
              .width('100%').height('100%').padding({top:this.titleContentInset()}).justifyContent(FlexAlign.Center)
          }
        }.width('100%').height('100%')
      }.titleMode(HdsNavDestinationTitleMode.MINI).hideTitleBar(false).hideBackButton(false)
        .titleBar(PinmonyHdsTitleBar.resolve(this.getUIContext(), this.titleOptions(), this.hdsDarkMode)).bindToScrollable([this.scroller])
        .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM],[LayoutSafeAreaEdge.TOP])
        .backgroundColor($r('app.color.page_background'))
        .onBackPressed(() => {if(!this.active){this.onCoveredBack?.();return true;}this.act('back');return true;})
    }.mode(NavigationMode.Stack).hideTitleBar(true).width('100%').height('100%').backgroundColor($r('app.color.page_background'))
      .hitTestBehavior(this.active ? HitTestMode.Default : HitTestMode.None)
      .accessibilityLevel(this.active ? 'auto' : 'no-hide-descendants')
  }
}
