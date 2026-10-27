import { PinmonyActionNotice } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { PinmonySearchQuiz, PinmonySearchQuizTopic, PinmonySearchQuizCard } from '../models/PinmonySearch';

@Component
export struct PinmonySearchQuizPanel {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop quiz: PinmonySearchQuiz;
  @StorageProp('gestureBarHeightPx') private gestureBarHeightPx: number = 0;
  @State private contentWidth: number = 328;
  // Keep the sheet's content inset aligned with the search result WaterFlow (16vp).
  private readonly contentInset: number = 16;
  private readonly cardScroller: Scroller = new Scroller();
  onAction: (kind: string, id: string) => void = () => {};
  onPin: (url: string) => void = () => {};

  private contentColumns(): number {
    return Math.max(2, Math.floor((this.contentWidth - 0 + 8) / 188));
  }

  private columnSlots(): number[] {
    const slots: number[] = [];
    for (let i: number = 0; i < this.contentColumns(); i++) slots.push(i);
    return slots;
  }

  private contentColumnsTemplate(): string {
    return this.columnSlots().map((): string => '1fr').join(' ');
  }

  private cardWidth(): number {
    return Math.max(1, (this.contentWidth - (this.contentColumns() - 1) * 8) / this.contentColumns());
  }

  private cardHeight(item: PinmonySearchQuizCard): number {
    const ratio: number = item.imageWidth && item.imageHeight ? item.imageHeight / item.imageWidth : 1.3;
    return this.cardWidth() * (Number.isFinite(ratio) && ratio > 0 ? ratio : 1.3);
  }

  @Builder
  private requestState() {
    if (this.quiz.busy) { LoadingProgress().width(28).height(28).alignSelf(ItemAlign.Center) }
    if (this.quiz.error) {
      PinmonyActionNotice({ message: PinmonyI18n.render(this.quiz.error, this.uiLanguage), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => this.onAction('retry', '') })
    }
  }

  @Builder
  private entryContent() {
    Column({ space: 8 }) {
      Row() {
        Text(this.quiz.eyebrow).fontSize(13).fontColor($r('app.color.secondary_text')).layoutWeight(1)
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.xmark')).fontSize(18).fontColor([$r('app.color.primary_text')])
        }.width(32).height(32).padding(0).backgroundColor(Color.Transparent)
          .accessibilityText(this.uiText("pm_close_idea_recommendations_86934aff")).onClick(() => this.onAction('dismiss', ''))
      }.width('100%')
      Text(PinmonyI18n.render(this.quiz.title, this.uiLanguage)).fontSize(22).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.primary_text')).width('100%')
      this.requestState()
      Grid() {
        ForEach(this.quiz.topics.slice(0, 4), (item: PinmonySearchQuizTopic) => {
          GridItem() {
            Image(item.imageUrl).width('100%').height('100%').objectFit(ImageFit.Cover).borderRadius(12)
              .onClick(() => this.onAction('topic', item.id)).accessibilityText(item.query)
          }
        }, (item: PinmonySearchQuizTopic) => item.id)
      }.columnsTemplate(this.contentColumnsTemplate()).columnsGap(8).rowsGap(8)
        .enableScrollInteraction(false).scrollBar(BarState.Off)
        .height(Math.ceil(Math.min(4, this.quiz.topics.length) / this.contentColumns()) * (this.cardWidth() + 8))
    }.width('100%').padding(12).borderRadius(16).backgroundColor($r('app.color.surface_muted'))
      .onAreaChange((_old: Area, area: Area) => {
        const width: number = Number(area.width) - 24;
        if (width > 0 && Math.abs(width - this.contentWidth) > 1) this.contentWidth = width;
      })
  }

  @Builder
  private paginationFooter() {
    if (this.quiz.busy && this.quiz.cards.length > 0) {
      Row() {
        LoadingProgress().width(28).height(28)
      }.width('100%').height(48).justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  private selectionContent() {
    Column({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.quiz.cards.length > 0) {
          WaterFlow({ scroller: this.cardScroller, footer: this.paginationFooter }) {
            ForEach(this.quiz.cards, (item: PinmonySearchQuizCard) => {
              FlowItem() {
                Image(item.imageUrl).width(this.cardWidth()).height(this.cardHeight(item)).objectFit(ImageFit.Contain)
                  .borderRadius(14).clip(true)
                  .border({ width: item.selected ? 3 : 0, color: $r('app.color.detail_accent') })
                  .onClick(() => {
                    if (this.quiz.busy) return;
                    if (this.quiz.mode === 'picker') this.onAction('select', item.id);
                    else if (item.targetUrl) this.onPin(item.targetUrl);
                  }).accessibilityText(item.title + (item.selected ? this.uiText("pm_selected_657a8c2d") : ''))
                  .accessibilitySelected(item.selected)
              }.width(this.cardWidth()).height(this.cardHeight(item))
            }, (item: PinmonySearchQuizCard) => (item.id) + ':' + this.uiLanguage)
          }.columnsTemplate(this.contentColumnsTemplate()).columnsGap(8).rowsGap(8).width('100%').height('100%')
            .clip(true).scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
            .onReachEnd(() => {
              if (this.quiz.mode === 'picker' && this.quiz.canMore && !this.quiz.busy && !this.quiz.error) this.onAction('more', '');
            })
        }
        if (this.quiz.busy && this.quiz.cards.length === 0) {
          LoadingProgress().width(32).height(32).hitTestBehavior(HitTestMode.None)
        } else if (this.quiz.cards.length === 0) {
          if (this.quiz.error) { Column({ space: 8 }) { this.requestState() }.width('100%') }
          else { Text(this.uiText("pm_no_recommendations_yet_841e1d2f")).fontColor($r('app.color.secondary_text')) }
        }
      }.width('100%').layoutWeight(1)
        .onAreaChange((_old: Area, area: Area) => {
          const width: number = Number(area.width);
          if (width > 0 && Math.abs(width - this.contentWidth) > 1) this.contentWidth = width;
        })
      if (this.quiz.cards.length > 0 && this.quiz.error) { this.requestState() }
      if (this.quiz.mode === 'picker') {
        Button(this.uiText("pm_view_results_d06bc6ef")).width('100%').height(48).borderRadius(16)
          .fontColor($r('app.color.primary_text')).backgroundColor($r('app.color.surface_muted'))
          .enabled(this.quiz.count > 0 && !this.quiz.busy)
          .accessibilityDescription(this.uiText("pm_selected_3f4ebc4a") + this.quiz.count.toString() + this.uiText("pm_images_up_to_10_b15e8d17"))
          .onClick(() => this.onAction('submit', ''))
      }
    }.width('100%').height('100%')
      .padding({ left: this.contentInset, right: this.contentInset, top: 8, bottom: 12 + this.getUIContext().px2vp(this.gestureBarHeightPx) })
      .backgroundColor($r('app.color.page_background'))
  }

  build() {
    if (this.quiz.mode === 'entry') { this.entryContent() }
    else { this.selectionContent() }
  }
}
