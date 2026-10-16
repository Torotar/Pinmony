import { InboxFlowBoard } from '../models/PinmonyInboxFlow';

@Component
export struct PinmonyInboxBoardCard {
  @Prop board: InboxFlowBoard;
  onOpen?: () => void;
  @State private failedImages: string[] = [];

  private countLabel(): string {
    const parts: string[] = [];
    if (this.board.pinCount !== undefined) parts.push(this.board.pinCount.toString() + ' 张 Pin 图');
    if (this.board.sectionCount !== undefined && this.board.sectionCount > 0) {
      parts.push(this.board.sectionCount.toString() + ' 个图板区块');
    }
    return parts.join(' · ');
  }

  @Builder
  private preview(url: string) {
    Stack() {
      if (url && !this.failedImages.includes(url)) {
        Image(url).width('100%').height('100%').objectFit(ImageFit.Cover)
          .onError(() => { this.failedImages = this.failedImages.concat(url); })
      } else {
        Image($r('app.media.comment_photo')).width(24).height(24).fillColor($r('app.color.secondary_text'))
      }
    }.width('100%').height('100%').backgroundColor($r('app.color.surface_muted'))
      .accessibilityLevel('no')
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 1 }) {
        if (this.board.images.length >= 3) {
          Column() { this.preview(this.board.images[0]) }.layoutWeight(2).height('100%')
          Column({ space: 1 }) {
            Column() { this.preview(this.board.images[1]) }.layoutWeight(1).width('100%')
            Column() { this.preview(this.board.images[2]) }.layoutWeight(1).width('100%')
          }.layoutWeight(1).height('100%')
        } else {
          this.preview(this.board.cover)
        }
      }.width('100%').height(146).borderRadius(18).clip(true)
      Text(this.board.title || '图板').fontSize(16).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.primary_text')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%').textAlign(TextAlign.Start).padding({ left: 8, right: 8 })
      if (this.countLabel()) {
        Text(this.countLabel()).fontSize(13).fontColor($r('app.color.secondary_text'))
          .width('100%').textAlign(TextAlign.Start).padding({ left: 8, right: 8 })
      }
      if (!this.board.url) {
        Text('图板链接暂不可用').fontSize(13).fontColor($r('app.color.secondary_text'))
      }
    }.width(220).constraintSize({ maxWidth: '100%' }).alignItems(HorizontalAlign.Start)
      .padding({ bottom: 12 }).borderRadius(18)
      .accessibilityGroup(true).accessibilityText((this.board.title || '图板') + '，' + this.countLabel())
      .onClick(() => { if (this.board.url && this.onOpen) this.onOpen(); })
  }
}
