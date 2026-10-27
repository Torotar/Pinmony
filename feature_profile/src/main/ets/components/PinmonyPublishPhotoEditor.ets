import { PinmonyActionNotice } from 'common_ui';
import { PinmonyLoadingOverlay } from 'common_ui';
import { Chip, ChipSize, SymbolGlyphModifier } from '@kit.ArkUI';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyCreatedPin, PinmonyOrganizeBoard } from '../models/PinmonyProfile';
import { PinmonyPublishFlow, PinmonyPublishTopic } from '../models/PinmonyPublishFlow';

// Retained by the publish page while individual destinations are recreated.
export class PinmonyPublishPhotoViewState {
  token: number = -1;
  editorOffset: number = 0;
  topicOffset: number = 0;
  advancedOffset: number = 0;
  productQuery: string = '';
  productLink: string = '';
  productTab: number = 0;
  prepare(token: number): void {
    if (this.token === token) return;
    this.token = token;
    this.editorOffset = 0; this.topicOffset = 0; this.advancedOffset = 0;
    this.productQuery = ''; this.productLink = '';this.productTab = 0;
  }
}

@Component
export struct PinmonyPublishPhotoEditor {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  @Prop @Watch('syncPhase') state: PinmonyPublishFlow;
  @State private title: string = '';
  @State private description: string = '';
  @State private link: string = '';
  @State private query: string = '';
  @State private productLink: string = '';
  @State private productTab: number = 0;
  @State private topicQuery: string = '';
  viewState: PinmonyPublishPhotoViewState = new PinmonyPublishPhotoViewState();
  private topicTimer: number = -1;
  private productTimer: number = -1;
  private lastPhase: string = '';
  private productsStarted: boolean = false;
  private draftExitDialogOpen: boolean = false;
  private readonly paths: NavPathStack = new NavPathStack();
  private readonly topicScroller: Scroller = new Scroller();
  private readonly advancedScroller: Scroller = new Scroller();
  private readonly productScroller: Scroller = new Scroller();
  private readonly productImageScroller: Scroller = new Scroller();
  private readonly productLinkScroller: Scroller = new Scroller();
  private readonly productConfirmScroller: Scroller = new Scroller();
  private readonly scroller: Scroller = new Scroller();
  onAction: (action: string, value: string, secret: boolean) => void = () => {};
  private text(key: string): string { return PinmonyI18n.text(key, this.uiLanguage); }
  private get subpage(): boolean { return ['topics','products','advanced'].includes(this.state.phase); }
  private get tagging(): boolean { return ['topics', 'products'].includes(this.state.phase); }
  aboutToAppear(): void {
    this.viewState.prepare(this.state.token);
    this.title = this.state.photoTitle || ''; this.description = this.state.photoDescription || ''; this.link = this.state.photoLink || '';
    this.topicQuery = this.state.topicQuery || '';
    this.query = this.viewState.productQuery; this.productLink = this.viewState.productLink;this.productTab = this.viewState.productTab;
    this.lastPhase = this.state.phase;
    this.paths.pushPath({ name: this.state.phase }, false);
  }
  aboutToDisappear(): void { if(this.topicTimer >= 0)clearTimeout(this.topicTimer);if(this.productTimer >= 0)clearTimeout(this.productTimer); }
  private searchProducts(value: string): void {
    this.query = value;this.viewState.productQuery = value;
    if(this.productTimer >= 0)clearTimeout(this.productTimer);
    this.onAction('productQuery','',false);
    this.productTimer = setTimeout((): void => {
      if(['products','productSearch'].includes(this.state.phase))this.onAction(this.state.phase === 'productSearch' ? 'suggestProducts' : 'searchProducts',this.query,false);
    },350);
  }
  private clearProductSearch(): void {
    if(this.productTimer >= 0)clearTimeout(this.productTimer);
    this.productTimer = -1;
    this.query = '';
    this.viewState.productQuery = '';
    this.onAction('productQuery','',false);
  }
  private syncPhase(): void {
    if (this.state.draftExitRequested && this.state.phase === 'select' && !this.draftExitDialogOpen) this.confirmDraftExit();
    if(this.lastPhase !== this.state.phase) {
      if(this.topicTimer >= 0)clearTimeout(this.topicTimer);
      if(this.state.phase === 'topics')this.topicQuery = this.state.topicQuery || '';
      this.lastPhase = this.state.phase;
      if(this.productTimer >= 0)clearTimeout(this.productTimer);
      this.productsStarted = false;this.productTab = this.viewState.productTab;
      if(this.paths.size() > 0)this.paths.replacePath({name:this.state.phase},false);
    }
  }
  private searchTopics(query: string): void {
    this.topicQuery = query;this.onAction('topicQuery',query,false);if(this.topicTimer >= 0)clearTimeout(this.topicTimer);
    this.topicTimer = setTimeout((): void => {
      if(this.state.phase === 'topics')this.onAction('searchTopics',JSON.stringify({query:this.topicQuery,language:this.uiLanguage.startsWith('en') ? 'en' : 'zh-cn'}),false);
    },300);
  }
  private confirmDraftExit(): void {
    this.draftExitDialogOpen = true;
    const token: number = this.state.token;
    this.getUIContext().showAlertDialog({
      title:this.text('pm_publish_draft_exit_title'),message:this.text('pm_publish_draft_exit_message'),autoCancel:false,
      primaryButton:{value:this.text('pm_publish_save_draft'),action:(): void => {
        this.draftExitDialogOpen = false;
        if (this.state.token === token && this.state.phase === 'select') this.onAction('saveDraftExit','',false);
      }},
      secondaryButton:{value:this.text('pm_cancel_2cd0f3be'),action:(): void => {
        this.draftExitDialogOpen = false;
        if (this.state.token === token) this.onAction('cancelDraftExit','',false);
      }}
    });
  }
  private topicsChanged(): boolean {
    return (this.state.topicDraft || []).map((topic: PinmonyPublishTopic): string => topic.id).sort().join(',') !== (this.state.selectedTopics || []).map((topic: PinmonyPublishTopic): string => topic.id).sort().join(',');
  }
  private advancedField(key: string, checked: boolean, text: string = ''): void {
    this.onAction('advancedFields',JSON.stringify({allowComments:key === 'comments' ? checked : this.state.allowComments !== false,allowShopping:key === 'shopping' ? checked : this.state.allowShopping !== false,aiModified:key === 'ai' ? checked : !!this.state.aiModified,aiGeneratedPerson:key === 'person' ? checked : !!this.state.aiGeneratedPerson,altText:key === 'alt' ? text : this.state.altText || ''}),false);
  }
  private fields(): void {
    this.onAction('photoFields', JSON.stringify({ photoTitle: this.title, photoDescription: this.description, photoLink: this.link }), false);
  }
  private back(phase: string): void { if (!this.state.busy) this.onAction('back', phase, false); }
  private openChild(action: string): void {
    if(this.state.phase === 'select' && !this.state.busy && !this.state.loading && !this.state.uncertain)this.onAction(action,'select',false);
  }
  private startProducts(phase: string): void {
    if(phase !== 'products' || this.state.phase !== phase || this.productTab !== 0 || this.productsStarted)return;
    this.productsStarted = true;
    this.onAction('searchProducts',this.query,false);
  }
  private canPublish(): boolean {
    return !!this.state.selectedBoardId && !!this.state.selectedIds.length && !this.state.busy && !this.state.loading && !this.state.uncertain &&
      (!this.link || /^https?:\/\/[^\s/@?#]+(?:[/?#][^\s]*)?$/.test(this.link));
  }
  private titleBar(phase: string): HdsNavigationTitleBarOptions {
    return { avoidLayoutSafeArea: true, enableComponentSafeArea: true,
      style: { scrollEffectOpts: { enableScrollEffect: false },
        originalStyle: { backgroundStyle: { backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0 },
          contentStyle: { titleStyle: { mainTitleColor: $r('app.color.primary_text') }, backIconStyle: { iconColor: $r('app.color.primary_text') }, menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') } } },
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0 },
          contentStyle: { titleStyle: { mainTitleColor: $r('app.color.primary_text') }, backIconStyle: { iconColor: $r('app.color.primary_text') }, menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') } } } },
      content: { title: { mainTitle: this.text(phase === 'advanced' ? 'pm_publish_advanced' : ['topics','products','productImages','productSearch','productConfirm'].includes(phase) ? phase === 'topics' ? 'pm_publish_topics' : 'pm_publish_products' : 'pm_publish_create_pin') },
        backIcon: { label: this.text('pm_back_572cf45b'), isEnabled: !this.state.busy, action: () => this.back(phase) },
        menu: { value: phase === 'select' ? [{content:{icon:new SymbolGlyphModifier($r('sys.symbol.save')).fontSize(28).fontColor([$r('app.color.primary_text')]),label:this.text('pm_publish_save_draft'),isEnabled:!this.state.busy && !this.state.loading && !this.state.uncertain && !this.state.draftSaved,action:(): void => this.onAction('saveDraft','',false)}}] : phase === 'topics' ? [{content:{icon:new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]),label:this.text('pm_done_c0b3fbff'),isEnabled:this.topicsChanged(),action:(): void => {if(this.topicsChanged())this.onAction('doneTopics','',false);}}}] : phase === 'productImages' ? [{content:{icon:new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]),label:this.text('pm_done_c0b3fbff'),isEnabled:!!this.state.productImageId && !this.state.busy && !this.state.uncertain,action:(): void => this.onAction('confirmProductImage','',false)}}] : ['products','productSearch','productConfirm'].includes(phase) ? [{content:{icon:new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]),label:this.text(phase === 'productConfirm' ? 'pm_done_c0b3fbff' : 'pm_next_acfc4e74'),isEnabled:!this.state.busy && (phase === 'productConfirm' || !!this.state.selectedProducts?.length),action:(): void => this.onAction('doneProducts','',false)}}] : [] } } };
  }
  private rowLabel(action: string): string {
    return action === 'next' ? 'pm_publish_choose_board' : action === 'topics' ? 'pm_publish_topics' :
      action === 'products' ? 'pm_publish_products' : 'pm_publish_advanced';
  }
  private rowValue(action: string): string {
    const section: string = this.state.sections?.find((item: PinmonyOrganizeBoard): boolean => item.id === this.state.selectedSectionId)?.title || '';
    return action === 'next' ? (this.state.boards.find((board: PinmonyOrganizeBoard): boolean => board.id === this.state.selectedBoardId)?.title || '') + (section ? ' / ' + section : '') :
      action === 'topics' && this.state.selectedTopics?.length ? PinmonyI18n.format('pm_publish_topic_count',[this.state.selectedTopics.length.toString()],this.uiLanguage) : action === 'products' && this.state.selectedProducts?.length ? PinmonyI18n.format('pm_publish_product_count',[this.state.selectedProducts.length.toString()],this.uiLanguage) : '';
  }
  @Builder
  private row(action: string) {
    Row({ space: 12 }) {
      Text(this.text(this.rowLabel(action))).fontSize(17).fontColor($r('app.color.primary_text')).layoutWeight(1)
      if(action === 'next' && this.state.boards.some((board: PinmonyOrganizeBoard): boolean => board.id === this.state.selectedBoardId && board.secret)) {
        SymbolGlyph($r('sys.symbol.lock')).fontSize(16).fontColor([$r('app.color.secondary_text')]).accessibilityLevel('no')
      }
      if (this.rowValue(action)) { Text(this.rowValue(action)).fontSize(16).fontColor($r('app.color.secondary_text')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }) }
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([$r('app.color.primary_text')]).accessibilityLevel('no')
    }.width('100%').constraintSize({ minHeight: 56 }).padding({ top: 12, bottom: 12 })
      .accessibilityText(this.text(this.rowLabel(action)))
  }
  @Builder
  private editor() {
    Column({ space: 20 }) {
      Scroll() {
        Row({ space: 12 }) {
          ForEach(this.state.pins, (pin: PinmonyCreatedPin) => {
            Image(pin.imageUrl).width(110).height(190).objectFit(ImageFit.Contain).borderRadius(16)
          }, (pin: PinmonyCreatedPin): string => pin.id)
        }.justifyContent(FlexAlign.Center).padding({ top: 12, bottom: 4 })
      }.scrollable(ScrollDirection.Horizontal).width('100%').scrollBar(BarState.Off)
      Column({ space: 6 }) {
        Column({ space: 4 }) {
          Text(this.text('pm_publish_title')).fontSize(13).fontColor($r('app.color.primary_text')).width('100%')
          TextArea({ text: this.title, placeholder: this.text('pm_publish_title_hint') }).maxLength(100).width('100%').height(72).padding({ left: 6, right: 6, top: 4, bottom: 4 }).borderRadius(0).fontSize(17)
            .placeholderColor($r('app.color.secondary_text'))
            .backgroundColor(Color.Transparent).fontColor($r('app.color.primary_text')).enabled(!this.state.busy && !this.state.uncertain)
            .onChange((value: string) => { this.title = value; this.fields(); })
        }.padding(16).border({ width: 1, color: $r('app.color.secondary_text') }).borderRadius(18)
        Row() {
          Text(this.text('pm_publish_title_limit')).layoutWeight(1).fontSize(13).fontColor($r('app.color.secondary_text'))
          Text(this.title.length.toString() + '/100').fontSize(13).fontColor($r('app.color.secondary_text'))
        }.width('100%').padding({ left: 16, right: 12 })
      }
      Column({ space: 6 }) {
        Column({ space: 4 }) {
          Text(this.text('pm_description_dc2ba467')).fontSize(13).fontColor($r('app.color.primary_text')).width('100%')
          TextArea({ text: this.description, placeholder: this.text('pm_publish_description_hint') }).maxLength(800).width('100%').height(80).padding({ left: 6, right: 6, top: 4, bottom: 4 }).borderRadius(0).fontSize(17)
            .placeholderColor($r('app.color.secondary_text'))
            .backgroundColor(Color.Transparent).fontColor($r('app.color.primary_text')).enabled(!this.state.busy && !this.state.uncertain)
            .onChange((value: string) => { this.description = value; this.fields(); })
        }.padding(16).border({ width: 1, color: $r('app.color.secondary_text') }).borderRadius(18)
        Text(this.description.length.toString() + '/800').width('100%').textAlign(TextAlign.End).fontSize(13).fontColor($r('app.color.secondary_text')).padding({ right: 12 })
      }
      Column({ space: 4 }) {
        Text(this.text('pm_publish_link')).fontSize(13).fontColor($r('app.color.primary_text')).width('100%')
        TextInput({ text: this.link, placeholder: this.text('pm_publish_link_hint') }).maxLength(4096).width('100%').height(40).padding({ left: 6, right: 6, top: 4, bottom: 4 }).borderRadius(0).fontSize(17)
          .placeholderColor($r('app.color.secondary_text'))
          .type(InputType.URL).backgroundColor(Color.Transparent).fontColor($r('app.color.primary_text')).enabled(!this.state.busy && !this.state.uncertain)
          .onChange((value: string) => { this.link = value; this.fields(); })
      }.padding(16).border({ width: 1, color: $r('app.color.secondary_text') }).borderRadius(18)
      Column() {
        Row() { this.row('next') }.width('100%').onClick(() => this.openChild('next'))
        Row() { this.row('topics') }.width('100%').onClick(() => this.openChild('topics'))
        Row() { this.row('products') }.width('100%').onClick(() => this.openChild('products'))
        Row() { this.row('advanced') }.width('100%').onClick(() => this.openChild('advanced'))
      }.width('100%')
      if (this.state.error) { PinmonyActionNotice({ message: PinmonyI18n.render(this.state.error, this.uiLanguage) }) }
      Row() {
        Button(this.text('pm_create_cde2cd07')).width('100%').height(48).padding({ left: 24, right: 24 }).backgroundColor($r('app.color.accent'))
          .fontColor($r('app.color.detail_on_accent')).enabled(this.canPublish()).onClick(() => { if (this.canPublish()) this.onAction('publish', '', false); })
      }.width('100%')
    }.width('100%').padding({ left: 20, right: 20, bottom: 28 })
  }
  @Builder
  private topicsPage() {
    Column({space:20}) {
      TextInput({text:this.topicQuery,placeholder:this.text('pm_publish_topic_search')}).width('100%').height(48).maxLength(200)
        .fontSize(17).fontColor($r('app.color.primary_text')).placeholderColor($r('app.color.secondary_text'))
        .backgroundColor(Color.Transparent).padding({left:16,right:16,top:4,bottom:4}).border({width:1,color:$r('app.color.secondary_text')}).borderRadius(18)
        .onChange((query: string): void => this.searchTopics(query))
      if(!this.topicQuery && !(this.state.topicDraft || []).length) {
        Text(this.text('pm_publish_topic_help')).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).width('100%')
      }
      if((this.state.topicDraft || []).length) {
        Text(this.text('pm_publish_selected_topics')).fontSize(16).fontColor($r('app.color.secondary_text'))
        Flex({wrap:FlexWrap.Wrap}) {
          ForEach(this.state.topicDraft || [], (topic: PinmonyPublishTopic) => {
            Row() {
              Chip({label:{text:topic.text,fontSize:16,fontColor:$r('app.color.primary_text'),activatedFontColor:$r('app.color.page_background')},size:ChipSize.NORMAL,borderRadius:16,
                activated:true,allowClose:false,backgroundColor:$r('app.color.surface_muted'),activatedBackgroundColor:$r('app.color.primary_text'),
                onClicked:(): void => this.onAction('toggleTopic',topic.id,false)})
            }.margin({right:6,bottom:8})
          },(topic: PinmonyPublishTopic): string => topic.id + ':' + this.uiLanguage)
        }.width('100%')
      }
      if(this.state.topicLoading) { Column() }
      else if(this.state.topicError) {
        PinmonyActionNotice({ message: PinmonyI18n.render(this.state.topicError,this.uiLanguage), actionText: this.text('pm_retry_b8784c8d'), onAction: () => this.searchTopics(this.topicQuery) })
      } else if(this.state.topicQuery && !(this.state.topicResults || []).length) {
        Text(this.text('pm_publish_topic_empty')).fontColor($r('app.color.secondary_text'))
      }
      Flex({wrap:FlexWrap.Wrap}) {
        ForEach((this.state.topicResults || []).filter((topic: PinmonyPublishTopic): boolean => !(this.state.topicDraft || []).some((selected: PinmonyPublishTopic): boolean => selected.id === topic.id)),(topic: PinmonyPublishTopic) => {
          Row() {
            Chip({label:{text:topic.text,fontSize:16,fontColor:$r('app.color.primary_text')},size:ChipSize.NORMAL,borderRadius:16,
              activated:false,allowClose:false,backgroundColor:$r('app.color.surface_muted'),enabled:(this.state.topicDraft || []).length < 10,
              onClicked:(): void => this.onAction('toggleTopic',topic.id,false)})
          }.margin({right:6,bottom:8})
        },(topic: PinmonyPublishTopic): string => topic.id + ':' + this.uiLanguage)
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start).padding({left:20,right:20,top:12,bottom:28})
  }
  @Builder
  private settingToggle(label: string, help: string, checked: boolean, key: string, enabled: boolean = true) {
    Column({space:8}) {
      Row({space:16}) {
        Text(this.text(label)).fontSize(20).fontColor($r('app.color.primary_text')).layoutWeight(1)
        Toggle({type:ToggleType.Switch,isOn:checked}).enabled(enabled && !this.state.busy && !this.state.uncertain).onChange((next: boolean): void => this.advancedField(key,next))
          .accessibilityText(this.text(label))
      }.width('100%')
      if(help) { Text(this.text(help)).fontSize(16).fontColor($r('app.color.secondary_text')).width('100%') }
    }.width('100%')
  }
  @Builder
  private advancedPage() {
    Column({space:28}) {
      Text(this.text('pm_publish_engagement')).fontSize(16).fontColor($r('app.color.primary_text'))
      this.settingToggle('pm_publish_allow_comments','',this.state.allowComments !== false,this.state.accountCommentsEnabled === false ? 'comments_disabled' : 'comments',this.state.accountCommentsEnabled !== false)
      Column({space:8}) {
        Column({space:6}) {
          Text(this.text('pm_publish_alt_text')).fontSize(14).fontColor($r('app.color.primary_text')).width('100%')
          TextArea({text:this.state.altText || '',placeholder:this.text('pm_publish_alt_hint')}).width('100%').height(80).maxLength(500)
            .padding({left:6,right:6,top:4,bottom:4}).borderRadius(0).fontSize(17).fontColor($r('app.color.primary_text'))
            .placeholderColor($r('app.color.secondary_text')).backgroundColor(Color.Transparent)
            .onChange((text: string): void => this.advancedField('alt',false,text))
        }.width('100%').padding(16).border({width:1,color:$r('app.color.secondary_text')}).borderRadius(18)
        Row({space:12}) {
          Text(this.text('pm_publish_alt_help')).layoutWeight(1).fontSize(13).fontColor($r('app.color.secondary_text'))
          Text((this.state.altText || '').length.toString() + '/500').fontSize(13).fontColor($r('app.color.secondary_text'))
        }.width('100%').alignItems(VerticalAlign.Top).padding({left:12,right:12})
      }.width('100%')
      Text(this.text('pm_publish_shopping')).fontSize(16).fontColor($r('app.color.primary_text')).margin({top:12})
      this.settingToggle('pm_publish_similar_products','pm_publish_similar_help',this.state.allowShopping !== false,this.state.accountShoppingRecommendationsEnabled === false ? 'shopping_disabled' : 'shopping',this.state.accountShoppingRecommendationsEnabled !== false)
      Text(this.text('pm_publish_shopping_help')).fontSize(16).fontColor($r('app.color.secondary_text'))
      Text(this.text('pm_publish_ai_disclosure')).fontSize(16).fontColor($r('app.color.primary_text')).margin({top:12})
      this.settingToggle('pm_publish_ai_modified','pm_publish_ai_modified_help',!!this.state.aiModified,'ai')
      this.settingToggle('pm_publish_ai_person','pm_publish_ai_person_help',!!this.state.aiGeneratedPerson,'person')
    }.width('100%').alignItems(HorizontalAlign.Start).padding({left:20,right:20,top:16,bottom:32})
  }
  @Builder
  private productResults(link: boolean) {
    Scroll(link ? this.productLinkScroller : this.productScroller) {
      Column({space:16}) {
        if(this.state.productLoading) { LoadingProgress().width(28).height(28) }
        else if(this.state.productError) {
          PinmonyActionNotice({ message: PinmonyI18n.render(this.state.productError,this.uiLanguage), actionText: this.text('pm_retry_b8784c8d'), onAction: () => this.onAction(this.state.productMode === 'link' ? 'findProduct' : 'searchProducts',this.state.productQuery || '',false) })
        } else if(this.state.productMode && !(this.state.productResults || []).length) {
          Text(this.text('pm_publish_product_empty')).fontColor($r('app.color.secondary_text'))
        }
        if((this.state.productResults || []).length) {
          Text(this.text('pm_publish_product_select_help')).fontSize(16).fontColor($r('app.color.secondary_text')).width('100%')
          Row({space:12}) {
            ForEach([0,1], (column: number) => {
              Column({space:16}) {
                ForEach((this.state.productResults || []).filter((_pin: PinmonyCreatedPin,index: number): boolean => index % 2 === column),(pin: PinmonyCreatedPin) => {
                  Column({space:6}) {
                    Stack({alignContent:Alignment.BottomEnd}) {
                      Image(pin.imageUrl).width('100%').aspectRatio(pin.imageWidth > 0 && pin.imageHeight > 0 ? pin.imageWidth / pin.imageHeight : 1).objectFit(ImageFit.Contain).borderRadius(16)
                      if((this.state.selectedProducts || []).some((p: PinmonyCreatedPin): boolean => p.id === pin.id)) {
                        SymbolGlyph($r('sys.symbol.checkmark')).fontSize(20).fontColor([Color.White]).padding(8).backgroundColor(Color.Black).borderRadius(16).margin(8)
                      }
                    }.width('100%')
                    if(pin.title) { Text(pin.title).fontSize(16).fontColor($r('app.color.primary_text')).maxLines(3).textOverflow({overflow:TextOverflow.Ellipsis}).width('100%') }
                  }.width('100%').alignItems(HorizontalAlign.Start).enabled(!this.state.busy)
                    .onClick(() => this.onAction('toggleProduct',pin.id,false))
                },(pin: PinmonyCreatedPin): string => pin.id + ':' + this.uiLanguage + ':' + (this.state.selectedProducts || []).some((p: PinmonyCreatedPin): boolean => p.id === pin.id).toString() + ':' + (!!this.state.busy).toString())
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            },(column: number): string => column.toString())
          }.width('100%').alignItems(VerticalAlign.Top)
        }
      }.width('100%').padding({bottom:28})
    }.width('100%').layoutWeight(1).edgeEffect(EdgeEffect.Spring,{alwaysEnabled:true}).scrollBar(BarState.Off)
  }
  @Builder
  private productImagePage() {
    Scroll(this.productImageScroller) {
      Column({space:20}) {
        Text(this.text('pm_publish_affiliate_section')).fontSize(16).fontColor($r('app.color.primary_text')).width('100%')
        Row({space:16}) {
          Text(this.text('pm_publish_affiliate_label')).fontSize(20).fontColor($r('app.color.primary_text')).layoutWeight(1)
          Toggle({type:ToggleType.Switch,isOn:false}).enabled(false).accessibilityText(this.text('pm_publish_affiliate_label'))
        }.width('100%')
        Text(this.text('pm_publish_affiliate_help')).fontSize(16).fontColor($r('app.color.secondary_text')).width('100%')
        Text(this.text('pm_choose_image_9ad12a1a')).fontSize(17).fontColor($r('app.color.primary_text')).width('100%')
        Row({space:12}) {
          ForEach([0,1],(column: number) => {
            Column({space:12}) {
              ForEach((this.state.productResults || []).filter((_pin: PinmonyCreatedPin,index: number): boolean => index % 2 === column),(pin: PinmonyCreatedPin) => {
                Stack({alignContent:Alignment.BottomEnd}) {
                  Image(pin.imageUrl).width('100%').aspectRatio(1).objectFit(ImageFit.Contain).borderRadius(16)
                  if(this.state.productImageId === pin.id) {
                    SymbolGlyph($r('sys.symbol.checkmark')).fontSize(20).fontColor([Color.White]).padding(8).backgroundColor(Color.Black).borderRadius(16).margin(8)
                  }
                }.width('100%').enabled(!this.state.busy && !this.state.uncertain)
                  .onClick(() => this.onAction('chooseProductImage',pin.id,false))
              },(pin: PinmonyCreatedPin): string => pin.id + ':' + (this.state.productImageId === pin.id).toString())
            }.layoutWeight(1)
          },(column: number): string => column.toString())
        }.width('100%').alignItems(VerticalAlign.Top)
        if(this.state.productError) { PinmonyActionNotice({ message: PinmonyI18n.render(this.state.productError,this.uiLanguage) }) }
      }.width('100%').padding({left:16,right:16,top:16,bottom:28})
    }.width('100%').height('100%').align(Alignment.TopStart).edgeEffect(EdgeEffect.Spring,{alwaysEnabled:true})
  }
  @Builder
  private tagTabs() {
    Tabs({index:this.productTab}) {
      TabContent() {
        Column({ space: 20 }) {
          Row() { Text(this.query || this.text('pm_publish_product_search')).fontSize(17).fontColor($r('app.color.secondary_text')) }.width('100%').height(48).padding(12).borderRadius(16).backgroundColor($r('app.color.surface_muted')).onClick(() => this.onAction('openProductSearch','',false))
          if(!this.query.trim()) { Text(this.text('pm_publish_product_recommendations')).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).width('100%') }
          this.productResults(false)
        }.width('100%').height('100%').padding(16).alignItems(HorizontalAlign.Start)
      }.tabBar(SubTabBarStyle.of(this.text('pm_publish_search_pins')).indicator({ color: $r('app.color.primary_text'), height: 2, borderRadius: 0 })
        .labelStyle({ selectedColor: $r('app.color.primary_text'), unselectedColor: $r('app.color.primary_text'), font: { size: 17, weight: FontWeight.Bold } }))
      TabContent() {
        Column({ space: 16 }) {
          TextInput({ text: this.productLink, placeholder: this.text('pm_publish_product_link') }).type(InputType.URL).maxLength(4096)
            .onChange((value: string) => { this.productLink = value; this.viewState.productLink = value;this.onAction('productQuery','',false); })
          Text(this.text('pm_publish_product_lookup_help')).fontSize(17).fontColor($r('app.color.primary_text')).textAlign(TextAlign.Center)
          Button(this.text('pm_publish_product_lookup')).width('100%').height(48).borderRadius(16)
            .enabled(/^https?:\/\/[^\s/@?#]+(?:[/?#][^\s]*)?$/.test(this.productLink.trim()) && !this.state.productLoading)
            .onClick(() => this.onAction('findProduct',this.productLink,false))
          if(this.state.productLoading) { LoadingProgress().width(28).height(28) }
          if(this.state.productError) { PinmonyActionNotice({ message: PinmonyI18n.render(this.state.productError,this.uiLanguage) }) }
          if(this.state.productMode === 'link' && !this.state.productLoading && !(this.state.productResults || []).length) { Text(this.text('pm_publish_product_empty')).fontColor($r('app.color.secondary_text')) }
        }.width('100%').height('100%').padding(16)
      }.tabBar(SubTabBarStyle.of(this.text('pm_publish_use_link')).indicator({ color: $r('app.color.primary_text'), height: 2, borderRadius: 0 })
        .labelStyle({ selectedColor: $r('app.color.primary_text'), unselectedColor: $r('app.color.primary_text'), font: { size: 17, weight: FontWeight.Bold } }))
    }.barMode(BarMode.Fixed).barHeight(56).width('100%').height('100%').animationDuration(0)
      .onChange((index: number): void => {
        if(index === this.productTab)return;
        this.productTab = index;this.viewState.productTab = index;
        if(this.productTimer >= 0)clearTimeout(this.productTimer);
        this.onAction('productQuery','',false);
        if(index === 0)this.onAction('searchProducts',this.query,false);
      })
  }
  @Builder
  private productSearchPage() {
    Column({space:16}) {
      Row({space:12}) {
        TextInput({text:this.query, placeholder:this.text('pm_publish_product_search')}).layoutWeight(1).height(48).maxLength(200).fontSize(17).borderRadius(16).onChange((value: string): void => this.searchProducts(value)).onSubmit(() => { if(this.productTimer >= 0)clearTimeout(this.productTimer); this.onAction('searchProducts',this.query,false); })
        if(this.query.length > 0) {
          Button() { SymbolGlyph($r('sys.symbol.xmark')).fontSize(20).fontColor([$r('app.color.secondary_text')]) }
            .type(ButtonType.Normal).width(40).height(40).backgroundColor(Color.Transparent)
            .accessibilityText(this.text('pm_clear_bce23772')).onClick(() => this.clearProductSearch())
        }
        Button(this.text('pm_cancel_2cd0f3be')).borderRadius(16).onClick(() => this.back('productSearch'))
      }.width('100%')
      if (this.state.productSuggesting) {
        Column() {
          ForEach(this.state.productSuggestions || [], (term: string) => {
            Row({space:20}) { SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(22).fontColor([$r('app.color.primary_text')]); Text(term).fontSize(18).fontColor($r('app.color.primary_text')).layoutWeight(1) }.width('100%').padding({top:16,bottom:16}).onClick(() => { if(this.productTimer >= 0)clearTimeout(this.productTimer); this.query = term; this.viewState.productQuery = term; this.onAction('searchProducts',term,false); })
          }, (term: string) => term)
          if (this.state.productLoading) { LoadingProgress().width(28).height(28) }
          if (this.state.productError) { PinmonyActionNotice({ message: PinmonyI18n.render(this.state.productError,this.uiLanguage) }) }
        }.width('100%')
      } else { this.productResults(false) }
    }.width('100%').height('100%').padding(16)
  }
  @Builder
  private productConfirmPage() {
    Stack({alignContent:Alignment.Bottom}) {
      Column() {
        Scroll(this.productConfirmScroller) {
          Column({space:16}) {
            if ((this.state.pins || []).length > 0) {
              Image(this.state.pins[0].imageUrl)
                .width('52%')
                .aspectRatio(9 / 16)
                .objectFit(ImageFit.Contain)
                .backgroundColor(Color.Black)
                .borderRadius(16)
                .clip(true)
                .margin({bottom:16})
            }
            ForEach(this.state.selectedProducts || [], (pin: PinmonyCreatedPin) => {
              Row({space:12}) {
                Image(pin.imageUrl).width(72).height(104).objectFit(ImageFit.Cover).borderRadius(12)
                Text(pin.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text')).maxLines(2).textOverflow({overflow:TextOverflow.Ellipsis}).layoutWeight(1)
                Button() { SymbolGlyph($r('sys.symbol.xmark')).fontSize(20).fontColor([$r('app.color.secondary_text')]) }
                  .type(ButtonType.Normal).width(40).height(40).backgroundColor(Color.Transparent).onClick(() => this.onAction('removeProduct',pin.id,false))
              }.width('100%')
            }, (pin: PinmonyCreatedPin): string => pin.id)
          }.width('100%').alignItems(HorizontalAlign.Center).padding({left:20,right:20,top:16,bottom:112})
        }.width('100%').layoutWeight(1).align(Alignment.TopStart).edgeEffect(EdgeEffect.Spring,{alwaysEnabled:true})
      }.width('100%').height('100%')
      Button('+', {type:ButtonType.Normal}).width(56).height(56).fontSize(32)
        .backgroundColor(Color.Transparent)
        .backgroundEffect({radius:20,saturation:1,brightness:1,color:$r('app.color.publish_button_glass')})
        .borderRadius(16).clip(true).fontColor($r('app.color.primary_text')).margin({bottom:28})
        .shadow({radius:6,color:'#26000000',offsetX:0,offsetY:3})
        .accessibilityText(this.text('pm_publish_products')).onClick(() => this.onAction('addProduct','',false))
    }.width('100%').height('100%')
  }
  @Builder
  private destination(phase: string) {
    HdsNavDestination() {
      if (phase === 'topics') { Stack({alignContent:Alignment.Center}) {
        Scroll(this.topicScroller) { this.topicsPage() }.width('100%').height('100%').align(Alignment.TopStart)
        .initialOffset({yOffset:this.viewState.topicOffset}).edgeEffect(EdgeEffect.Spring,{alwaysEnabled:true})
        .onDidScroll((): void => { this.viewState.topicOffset = Math.max(0,this.topicScroller.currentOffset().yOffset); })
        if (this.state.topicLoading) { LoadingProgress().width(28).height(28).hitTestBehavior(HitTestMode.None) }
        }.width('100%').height('100%') }
      else if(phase === 'advanced') { Scroll(this.advancedScroller) { this.advancedPage() }.width('100%').height('100%').align(Alignment.TopStart)
        .initialOffset({yOffset:this.viewState.advancedOffset}).edgeEffect(EdgeEffect.Spring,{alwaysEnabled:true})
        .onDidScroll((): void => { this.viewState.advancedOffset = Math.max(0,this.advancedScroller.currentOffset().yOffset); }) }
      else if (phase === 'products') { this.tagTabs() }
      else if(phase === 'productImages') { this.productImagePage() }
      else if(phase === 'productSearch') { this.productSearchPage() }
      else if(phase === 'productConfirm') { this.productConfirmPage() }
      else { Scroll(this.scroller) { this.editor() }.width('100%').height('100%').align(Alignment.TopStart).scrollBar(BarState.Off)
        .initialOffset({yOffset:this.viewState.editorOffset}).edgeEffect(EdgeEffect.Spring,{alwaysEnabled:true})
        .onDidScroll((): void => { this.viewState.editorOffset = Math.max(0,this.scroller.currentOffset().yOffset); }) }
    }.titleBar(this.titleBar(phase)).titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable(phase === 'productImages' ? [this.productImageScroller] : phase === 'productConfirm' ? [this.productConfirmScroller] : phase === 'products' ? [this.productScroller,this.productLinkScroller] : [phase === 'topics' ? this.topicScroller : phase === 'advanced' ? this.advancedScroller : this.scroller])
      .onBackPressed(() => { this.back(phase); return true; })
      .onShown((): void => this.startProducts(phase))
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP]).backgroundColor($r('app.color.page_background'))
  }
  build() {
    Stack({alignContent:Alignment.Center}) {
      HdsNavigation(this.paths) { Column().width('100%').height('100%') }
        .width('100%').height('100%').hideTitleBar(true).navDestination(this.destination).backgroundColor($r('app.color.page_background'))
      if(this.state.busy) { PinmonyLoadingOverlay({message:this.text('pm_loading_please_wait_b6aaac70')}) }
    }.width('100%').height('100%')
  }
}
