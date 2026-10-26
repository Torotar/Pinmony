import { PinmonyI18n } from 'common_foundation';
import { PinmonyEditPinResult } from '../models/PinmonyEditPin';
import { PinmonySaveSheet } from './PinmonySaveSheet';

@Component
export struct PinmonyEditPinSheet {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop @Watch('syncDraft') result: PinmonyEditPinResult;
  @State private draftTitle: string = '';
  @State private draftDescription: string = '';
  private draftPin: string = '';
  onAction?: (method: string, args: string) => void;
  onRetry?: () => void;
  onClose?: () => void;

  aboutToAppear(): void {
    this.syncDraft();
  }

  private syncDraft(): void {
    if (this.result.loading) {
      this.draftPin = '';
    } else if (!this.result.error && this.draftPin !== this.result.pin) {
      this.draftPin = this.result.pin;
      this.draftTitle = this.result.title;
      this.draftDescription = this.result.description;
    }
  }

  private act(method: string, args: string): void {
    if (this.onAction) this.onAction(method, args);
  }

  onCreatingChange?: (creating: boolean) => void;

  build() {
    if (this.result.phase === 'boards') {
      PinmonySaveSheet({ result: this.result.picker,
        onRetry: () => this.act('editPhase', ',"boards"'),
        onSave: (id: string) => this.act('editSelect', ',' + JSON.stringify(id)),
        onCreate: (name: string, secret: boolean) => this.act('boardsCreate', ',' + JSON.stringify(name) + ',' + secret.toString()),
        onCreatingChange: (creating: boolean) => { if (this.onCreatingChange) this.onCreatingChange(creating); } })
    } else {
      Stack({ alignContent: Alignment.Bottom }) {
        Column({ space: 16 }) {
          List() {
            ListItem() {
            Column({ space: 20 }) {
              if (this.result.loading || this.result.busy) { LoadingProgress().width(28).height(28) }
              if (this.result.error) {
                Text(PinmonyI18n.render(this.result.error, this.uiLanguage)).fontColor($r('app.color.secondary_text'))
                Button(this.uiText("pm_reload_df7392cc")).enabled(!this.result.busy).onClick(() => { if (this.onRetry) this.onRetry(); })
              }
              if (!this.result.loading && !this.result.error) {
          Image(this.result.imageUrl).width(110).height(110).objectFit(ImageFit.Cover)
            .borderRadius(14).alignSelf(ItemAlign.Start).accessibilityText(this.uiText("pm_currently_saved_pin_cff5382b"))
          if (this.result.editableContent) Column({ space: 8 }) {
            Text(this.uiText("pm_pin_title_06aa0cfe")).fontSize(14).fontColor($r('app.color.primary_text')).width('100%')
            TextInput({ text: this.draftTitle }).width('100%').height(52).fontSize(16)
              .fontColor($r('app.color.primary_text')).backgroundColor($r('app.color.page_background'))
              .border({ width: 1, color: $r('app.color.secondary_text'), radius: 16 })
              .maxLength(10000).accessibilityText(this.uiText("pm_pin_title_06aa0cfe"))
              .enabled(!this.result.busy && !this.result.uncertain && this.result.phase === 'edit')
              .onChange((value: string) => {
                this.draftTitle = value;
                this.act('editText', ',"title",' + JSON.stringify(value));
              })
          }.width('100%')
          if (this.result.editableContent) Column({ space: 8 }) {
            Text(this.uiText("pm_description_dc2ba467")).fontSize(14).fontColor($r('app.color.primary_text')).width('100%')
            TextArea({ text: this.draftDescription }).width('100%').height(76).fontSize(16)
              .fontColor($r('app.color.primary_text')).backgroundColor($r('app.color.page_background'))
              .border({ width: 1, color: $r('app.color.secondary_text'), radius: 16 })
              .maxLength(10000).accessibilityText(this.uiText("pm_pin_description_d61717a6"))
              .enabled(!this.result.busy && !this.result.uncertain && this.result.phase === 'edit')
              .onChange((value: string) => {
                this.draftDescription = value;
                this.act('editText', ',"description",' + JSON.stringify(value));
              })
          }.width('100%')
          Text(this.uiText("pm_board_bd3f17ee")).fontSize(14).fontColor($r('app.color.secondary_text')).width('100%')
          Button({ type: ButtonType.Normal }) {
            Row({ space: 12 }) {
              if (this.result.board.imageUrl) {
                Image(this.result.board.imageUrl).width(44).height(44).objectFit(ImageFit.Cover).borderRadius(10)
              }
              Text(this.result.board.name).fontSize(18).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.primary_text')).layoutWeight(1)
              Text('›').fontSize(24).fontColor($r('app.color.primary_text'))
            }.width('100%')
          }.width('100%').padding(0).backgroundColor(Color.Transparent)
            .enabled(!this.result.busy && this.result.phase === 'edit').onClick(() => this.act('editPhase', ',"boards"'))
          Row({ space: 12 }) {
            Toggle({ type: ToggleType.Switch, isOn: this.result.ai }).enabled(!this.result.busy && this.result.phase === 'edit')
              .onChange((value: boolean) => { if (value !== this.result.ai) this.act('editAi', ',' + value.toString()); })
            Column({ space: 8 }) {
              Text(this.uiText("pm_label_as_ai_modified_ebf5fa46")).fontSize(17).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.primary_text')).width('100%')
              Text(this.uiText("pm_content_made_entirely_or_partly_with_ai_3beb552d")).fontSize(14)
                .fontColor($r('app.color.secondary_text')).width('100%')
            }.layoutWeight(1)
          }.width('100%')
          Text(this.uiText("pm_actions_ed31fbb4")).fontSize(14).fontColor($r('app.color.secondary_text')).width('100%')
          Button({ type: ButtonType.Normal }) {
            Column({ space: 8 }) {
              Text(this.uiText("pm_delete_pin_e216e3fe")).fontSize(18).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.primary_text')).width('100%')
              Text(this.uiText("pm_remove_this_pin_from_your_board_0b19fa7e")).fontSize(14)
                .fontColor($r('app.color.secondary_text')).width('100%')
            }.width('100%')
          }.padding(0).backgroundColor(Color.Transparent).enabled(!this.result.busy && this.result.phase === 'edit')
            .onClick(() => this.act('editPhase', ',"confirm"'))

              }
            }.width('100%').padding({ right: 28 })
            }
          }.width('100%').layoutWeight(1).clip(true)
            .listDirection(Axis.Vertical).scrollBar(BarState.Auto)
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            .nestedScroll({ scrollForward: NestedScrollMode.SELF_ONLY,
              scrollBackward: NestedScrollMode.SELF_ONLY })
          Button(this.uiText("pm_done_c0b3fbff")).width('100%').height(48)
            .backgroundColor($r('app.color.detail_accent')).fontColor($r('app.color.detail_on_accent'))
            .enabled(this.result.phase === 'edit' && !this.result.loading && !this.result.busy &&
              !this.result.error && !this.result.uncertain && !this.result.picker.busy)
            .onClick(() => this.act('editCommit', ',false,' + JSON.stringify(this.draftTitle) + ',' +
              JSON.stringify(this.draftDescription)))
        }.padding(20).width('100%').height('100%').backgroundColor($r('app.color.page_background'))
        if (this.result.phase === 'confirm' && !this.result.error) {
          Rect().width('100%').height('100%').fill('#66000000')
            .onClick(() => { if (!this.result.busy) this.act('editPhase', ',"edit"'); })
        }
          if (this.result.phase === 'confirm' && !this.result.error) {
            Column({ space: 16 }) {
              Text(this.uiText("pm_delete_this_pin_bd01697d")).fontSize(20).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.primary_text')).width('100%')
              Text(this.uiText("pm_this_cannot_be_undone_55d5e34b")).fontSize(15).fontColor($r('app.color.secondary_text')).width('100%')
              Button(this.uiText("pm_delete_2f9daa82")).width('100%').backgroundColor($r('app.color.surface_muted'))
                .fontColor($r('app.color.primary_text')).enabled(!this.result.busy)
                .onClick(() => this.act('editCommit', ',true'))
              Button(this.uiText("pm_cancel_2cd0f3be")).width('100%').backgroundColor($r('app.color.detail_accent'))
                .fontColor($r('app.color.detail_on_accent')).enabled(!this.result.busy)
                .onClick(() => this.act('editPhase', ',"edit"'))
            }.padding(20).borderRadius(24).backgroundColor($r('app.color.input_surface'))
          }

      }.width('100%').height('100%')
    }
  }
}
