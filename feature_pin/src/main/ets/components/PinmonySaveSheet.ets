import { PinmonyI18n } from 'common_foundation';
import { PinmonySaveBoard, PinmonySaveResult } from '../models/PinmonyComments';
import { PinmonyBoardPlaceholder, PinmonyBoardPickerRow, PinmonyBoardPickerFooter } from 'common_ui';

@Component
export struct PinmonySaveSheet {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop result: PinmonySaveResult;
  @State private creating: boolean = false;
  @State private name: string = '';
  @State private secret: boolean = false;
  onRetry?: () => void;
  onSave?: (id: string, section?: string) => void;
  onOpenBoard?: (id: string) => void;
  onBack?: () => void;
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
    PinmonyBoardPickerRow({title:board.name,imageUrl:board.imageUrl,secret:board.secret,hasSections:board.hasSections === true,quickSave:board.id === 'profile-quick-saves',
      actionEnabled:board.enabled && !this.result.busy && !this.result.loading,
      onSelect:() => {if(this.onOpenBoard && board.id !== 'profile-quick-saves')this.onOpenBoard(board.id);else this.onSave?.(board.id);}})
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
            if(this.result.targetBoardId) {
              ForEach(this.result.items.concat(this.result.shortlist).filter((board: PinmonySaveBoard,index: number,all: PinmonySaveBoard[]): boolean => board.id === this.result.targetBoardId && all.findIndex((b: PinmonySaveBoard): boolean => b.id === board.id) === index), (board: PinmonySaveBoard) => {
                PinmonyBoardPickerRow({title:board.name,imageUrl:board.imageUrl,secret:board.secret,
                  actionEnabled:board.enabled && !this.result.busy && !this.result.loading && !this.result.error,
                  onSelect:() => this.onSave?.(board.id)})
              }, (board: PinmonySaveBoard) => JSON.stringify(board) + ':' + this.uiLanguage)
              ForEach(this.result.targetSections || [], (section: PinmonySaveBoard) => {
                PinmonyBoardPickerRow({title:section.name,imageUrl:section.imageUrl,secret:section.secret,indented:true,
                  actionEnabled:section.enabled && !this.result.busy && !this.result.loading && !this.result.error,
                  onSelect:() => this.onSave?.(this.result.targetBoardId || '',section.id)})
              }, (section: PinmonySaveBoard) => JSON.stringify(section) + ':' + this.uiLanguage)
              if(!this.result.loading && !this.result.error && !this.result.targetSections?.length) {
                Text(this.uiText('pm_this_board_has_no_sections_yet_2eb7dc0a')).fontColor($r('app.color.secondary_text'))
              }
            } else {
            if (!this.result.loading && this.result.shortlist.length) {
              Text(this.uiText("pm_featured_15b26cda")).fontColor($r('app.color.secondary_text')).width('100%')
              ForEach(this.result.shortlist, (board: PinmonySaveBoard) => { this.boardRow(board) }, (board: PinmonySaveBoard) => JSON.stringify(board) + ':' + this.uiLanguage)
            }
            if (!this.result.loading) {
              Text(this.uiText("pm_all_boards_f1847589")).fontColor($r('app.color.secondary_text')).width('100%')
            }
            if (!this.result.loading) {
              ForEach(this.result.items, (board: PinmonySaveBoard) => { this.boardRow(board) }, (board: PinmonySaveBoard) => JSON.stringify(board) + ':' + this.uiLanguage)
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
            }
          }.width('100%')
        }.layoutWeight(1).width('100%').align(Alignment.TopStart).scrollBar(BarState.Off)
        if(this.result.targetBoardId) {
          Divider().color($r('app.color.secondary_text')).opacity(0.15)
          PinmonyBoardPickerFooter({inset:0,back:true,labelKey:'pm_back_to_boards_dcf21f0d',
            actionEnabled:!this.result.busy && !this.result.loading && !this.result.uncertain,onSelect:() => this.onBack?.()})
        } else {
        if (!this.result.loading && !this.result.targetBoardId) {
        Divider().color($r('app.color.secondary_text')).opacity(0.15)
        PinmonyBoardPickerFooter({inset:0,actionEnabled:!this.result.busy && !this.result.loading && !this.result.error,
          onSelect:() => this.beginCreate()})
        } else {
          Blank().height(68)
        }
        }
        if (this.result.savedId) {
          Button(this.uiText("pm_undo_save_8245d6cd") + this.result.savedBoard).enabled(!this.result.busy)
            .onClick(() => { if (this.onRemove) this.onRemove(); })
        }
        if (this.result.error) {
          Button(this.uiText("pm_reload_boards_c3e7cfa5")).enabled(!this.result.busy).onClick(() => { if (this.onRetry) this.onRetry(); })
        }
      }
    }.width('100%').height('100%').padding({left:16,right:16,top:16,bottom:0}).backgroundColor($r('app.color.page_background'))
    }
  }
}
