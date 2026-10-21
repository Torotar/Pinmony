import { PinmonyI18n } from 'common_foundation';
import { PinmonySaveBoard, PinmonySaveResult } from '../models/PinmonyComments';
import { PinmonyBoardPlaceholder } from 'common_ui';

@Component
export struct PinmonySaveSheet {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop result: PinmonySaveResult;
  @State private creating: boolean = false;
  @State private name: string = '';
  @State private secret: boolean = false;
  onRetry?: () => void;
  onSave?: (id: string) => void;
  onCreate?: (name: string, secret: boolean) => void;
  onRemove?: () => void;
  onCreatingChange?: (creating: boolean) => void;

  private beginCreate(suggestion: string = ''): void {
    this.name = suggestion;
    this.secret = false;
    this.creating = true;
    if (this.onCreatingChange) this.onCreatingChange(true);
  }

  @Builder
  private suggestedCover() {
    Row({ space: 1 }) {
      Column().width(27.5).height(56).backgroundColor($r('app.color.surface_muted'))
      Column({ space: 1 }) {
        Column().width(27.5).height(27.5).backgroundColor($r('app.color.surface_muted'))
        Column().width(27.5).height(27.5).backgroundColor($r('app.color.surface_muted'))
      }
    }.width(56).height(56).borderRadius(16).clip(true)
      .backgroundColor($r('app.color.page_background')).accessibilityLevel('no')
  }

  @Builder
  private boardRow(board: PinmonySaveBoard) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        if (board.imageUrl) {
          Image(board.imageUrl).width(44).height(44).borderRadius(10).objectFit(ImageFit.Cover)
        } else if (board.id === 'profile-quick-saves') {
          Stack({ alignContent: Alignment.Center }) {
            Image($r('app.media.profile_quick_save')).width(26).height(26)
              .fillColor($r('app.color.primary_text'))
          }.width(44).height(44).backgroundColor($r('app.color.surface_muted')).borderRadius(10)
        } else {
          PinmonyBoardPlaceholder({ coverSize: 44 })
        }
        Text(board.name + (board.secret ? this.uiText("pm_secret_03a32629") : '')).fontSize(16).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.primary_text')).layoutWeight(1)
      }.width('100%')
    }.width('100%').height(60).padding(0).borderRadius(0).backgroundColor(Color.Transparent)
      .enabled(board.enabled && !this.result.busy && !this.result.loading)
      .onClick(() => { if (this.onSave) this.onSave(board.id); })
  }

  build() {
    if (this.result.error && !this.result.items.length && !this.result.shortlist.length && !this.creating) {
      Column({ space: 16 }) {
        Text(PinmonyI18n.render(this.result.error, this.uiLanguage)).fontSize(14).fontColor($r('app.color.secondary_text')).width('100%')
        Button(this.uiText("pm_reload_boards_c3e7cfa5")).enabled(!this.result.busy && !this.result.loading)
          .onClick(() => { if (this.onRetry) this.onRetry(); })
      }.width('100%').padding(20).backgroundColor($r('app.color.page_background'))
    } else {
    Column({ space: 12 }) {
      if (this.result.error) {
        Text(PinmonyI18n.render(this.result.error, this.uiLanguage)).fontColor($r('app.color.secondary_text'))
      }
      if (this.result.feedback) {
        Text(PinmonyI18n.render(this.result.feedback, this.uiLanguage)).fontColor($r('app.color.primary_text'))
      }
      if (this.result.busy || this.result.loading) {
        LoadingProgress().width(28).height(28)
      }
      if (this.creating) {
        Text(this.uiText("pm_board_name_dd9a7122")).fontSize(14).fontColor($r('app.color.secondary_text')).width('100%')
        TextInput({ placeholder: this.uiText("pm_board_name_dd9a7122"), text: this.name }).maxLength(100)
          .height(48).borderRadius(12).backgroundColor($r('app.color.input_surface'))
          .enabled(!this.result.busy).onChange((value: string) => this.name = value)
        Divider().color($r('app.color.secondary_text')).opacity(0.15)
        Row() {
          Text(this.uiText("pm_keep_board_secret_2264c319")).fontColor($r('app.color.primary_text')).layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.secret }).enabled(!this.result.busy)
            .onChange((value: boolean) => this.secret = value)
        }.width('100%')
        Row({ space: 12 }) {
          Button(this.uiText("pm_back_to_boards_dcf21f0d")).layoutWeight(1).height(44).fontSize(14)
            .backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text'))
            .enabled(!this.result.busy).onClick(() => {
              this.creating = false;
              if (this.onCreatingChange) this.onCreatingChange(false);
            })
          Button(this.uiText("pm_create_cde2cd07")).layoutWeight(1).height(44).fontSize(14)
            .backgroundColor($r('app.color.detail_accent')).fontColor($r('app.color.detail_on_accent'))
            .enabled(!!this.name.trim() && !this.result.busy && !this.result.loading)
            .onClick(() => { if (this.onCreate) this.onCreate(this.name.trim(), this.secret); })
        }.width('100%').margin({ top: 16 })
      } else {
        Scroll() {
          Column({ space: 8 }) {
            if (!this.result.loading && this.result.shortlist.length) {
              Text(this.uiText("pm_featured_15b26cda")).fontColor($r('app.color.secondary_text')).width('100%')
              ForEach(this.result.shortlist, (board: PinmonySaveBoard) => { this.boardRow(board) }, (board: PinmonySaveBoard) => board.id)
            }
            if (!this.result.loading) {
              Text(this.uiText("pm_all_boards_f1847589")).fontColor($r('app.color.secondary_text')).width('100%')
            }
            if (!this.result.loading) {
              ForEach(this.result.items, (board: PinmonySaveBoard) => { this.boardRow(board) }, (board: PinmonySaveBoard) => board.id)
            }
            if (!this.result.loading && !this.result.error && !this.result.items.length) {
              Text(this.uiText("pm_no_boards_yet_43790af9")).fontColor($r('app.color.secondary_text'))
            }
            if (!this.result.loading && (this.result.suggestions || []).length) {
              Divider().color($r('app.color.secondary_text')).opacity(0.15).margin({ top: 12, bottom: 8 })
              Text(this.uiText("pm_or_tap_to_create_a_new_board_4c13492c")).fontSize(13)
                .fontColor($r('app.color.secondary_text')).width('100%')
              ForEach(this.result.suggestions || [], (suggestion: string) => {
                Button({ type: ButtonType.Normal }) {
                  Row({ space: 12 }) {
                    this.suggestedCover()
                    Text(PinmonyI18n.render(suggestion, this.uiLanguage)).fontSize(16).fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.primary_text')).layoutWeight(1)
                  }.width('100%')
                }.width('100%').height(72).padding(0).borderRadius(0).backgroundColor(Color.Transparent)
                  .enabled(!this.result.busy && !this.result.loading && !this.result.error)
                  .onClick(() => this.beginCreate(suggestion))
              }, (suggestion: string) => (suggestion) + ':' + this.uiLanguage)
            }
          }.width('100%')
        }.layoutWeight(1).width('100%')
        if (!this.result.loading) {
        Divider().color($r('app.color.secondary_text')).opacity(0.15)
        Button({ type: ButtonType.Normal }) {
          Row({ space: 12 }) {
            Text('+').fontSize(26).width(44).height(44).textAlign(TextAlign.Center)
              .backgroundColor($r('app.color.surface_muted')).borderRadius(10)
              .fontColor($r('app.color.primary_text'))
            Text(this.uiText("pm_create_board_513babc9")).fontSize(16).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_text')).layoutWeight(1)
          }.width('100%')
        }.width('100%').height(56).padding(0).borderRadius(0).backgroundColor(Color.Transparent)
          .enabled(!this.result.busy && !this.result.loading && !this.result.error)
          .onClick(() => this.beginCreate())
        } else {
          Blank().height(68)
        }
        if (this.result.savedId) {
          Button(this.uiText("pm_undo_save_8245d6cd") + this.result.savedBoard).enabled(!this.result.busy)
            .onClick(() => { if (this.onRemove) this.onRemove(); })
        }
        if (this.result.error) {
          Button(this.uiText("pm_reload_boards_c3e7cfa5")).enabled(!this.result.busy).onClick(() => { if (this.onRetry) this.onRetry(); })
        }
      }
    }.width('100%').height('100%').padding(20).backgroundColor($r('app.color.page_background'))
    }
  }
}
