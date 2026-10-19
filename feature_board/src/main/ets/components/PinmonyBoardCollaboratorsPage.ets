import { PinmonyI18n } from 'common_foundation';
import { HdsNavigation, ScrollEffectType, hdsMaterial, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { PinmonyUserAvatar } from 'common_ui';
import { PinmonyBoardCollaborators, PinmonyBoardCollaborator } from '../models/PinmonyBoardCollaborators';

@Component
export struct PinmonyBoardCollaboratorsPage {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop snapshot: PinmonyBoardCollaborators;
  onAction: (action: string, value: string) => void = () => {};
  onClose: () => void = () => {};
  @State private query: string = '';
  @State private allowInvites: boolean = false;
  @State private selectedPermission: number = 0;
  private stack: NavPathStack = new NavPathStack();
  private scroller: Scroller = new Scroller();
  aboutToAppear(): void { this.stack.pushPath({ name: 'collaborators' }, false); }
  private back(): void {
    if (this.snapshot.busy) return;
    if (this.snapshot.phase === 'members' || this.snapshot.uncertain) this.onClose();
    else this.onAction('members', '');
  }
  private titleOptions(): HdsNavigationTitleBarOptions {
    return { avoidLayoutSafeArea: true, enableComponentSafeArea: true,
      style: { scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE }, scrollEffectStyle: { contentStyle: { backIconStyle: { iconColor: $r('app.color.primary_text') }, menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { iconColor: $r('app.color.primary_text') }, menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },  backgroundStyle: {
        backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0 } } },
      content: { title: { mainTitle: this.snapshot.phase === 'invite' ? this.uiText("pm_invite_collaborators_d6dc0e1e") :
        this.snapshot.phase === 'permissions' ? this.uiText("pm_collaborators_can_82551ec5") :
          this.snapshot.users.filter((user: PinmonyBoardCollaborator): boolean => user.status === 'owner' || user.status === 'accepted').length.toString() + this.uiText("pm_collaborators_7b9e7279") },
        backIcon: { isEnabled: !this.snapshot.busy, action: () => this.back() },
        menu: { value: this.snapshot.phase === 'permissions' ? [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]),
          label: this.uiText("pm_done_c0b3fbff"), isEnabled: !this.snapshot.busy && !this.snapshot.uncertain && this.snapshot.owner === true &&
            (this.allowInvites !== this.snapshot.invites || this.selectedPermission !== this.snapshot.permission),
          action: () => this.onAction('save', JSON.stringify({ permission: this.selectedPermission, invites: this.allowInvites })) } }] : [] } } };
  }
  @Builder private permissionOption(value: number, title: string, description: string) {
    Row({ space: 12 }) {
      Radio({ value: value.toString(), group: 'board-permissions' }).checked(this.selectedPermission === value)
        .enabled(this.snapshot.owner === true && !this.snapshot.busy && !this.snapshot.uncertain)
        .onChange((checked: boolean) => { if (checked) this.selectedPermission = value; })
      Column({ space: 8 }) {
        Text(title).fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
        Text(description).fontSize(15).fontColor($r('app.color.secondary_text'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').alignItems(VerticalAlign.Top)
  }
  @Builder private userRow(user: PinmonyBoardCollaborator, invite: boolean) {
    Row({ space: 12 }) {
      PinmonyUserAvatar({ image: user.avatar, name: user.name || user.username, avatarSize: 44 })
      Column({ space: 2 }) {
        Text(user.name).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text'))
        if (invite) { Text(user.username).fontSize(13).fontColor($r('app.color.secondary_text')) }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (invite && !user.status) {
        Button(this.uiText("pm_invite_1955b265")).backgroundColor($r('app.color.accent')).fontColor(Color.White)
          .enabled(!this.snapshot.busy && !this.snapshot.uncertain)
          .onClick(() => this.onAction('send', user.id))
      } else {
        Text(user.status === 'owner' ? this.uiText("pm_owner_43a7f4b4") : user.status === 'accepted' ? this.uiText("pm_collaborator_59fa99bc") : this.uiText("pm_invited_b43e8a99"))
          .fontSize(14).fontColor($r('app.color.secondary_text'))
      }
    }.width('100%').padding({ top: 10, bottom: 10 })
  }
  @Builder
  private destination(_name?: string, _param?: Object) {
      HdsNavDestination() {
        Column() {
          Scroll(this.scroller) {
            Column({ space: 16 }) {
              if (this.snapshot.loading || this.snapshot.busy) { LoadingProgress().width(28).height(28) }
              if (this.snapshot.error) {
                Text(PinmonyI18n.render(this.snapshot.error, this.uiLanguage)).fontColor($r('app.color.secondary_text'))
                if (!this.snapshot.uncertain && !this.snapshot.busy) { Button(this.uiText("pm_retry_b8784c8d")).onClick(() => this.onAction('retry', '')) }
              } else if (!this.snapshot.loading) {
                if (this.snapshot.phase === 'members') {
                  Text(this.uiText("pm_collaborators_can_82551ec5")).fontSize(13).fontColor($r('app.color.secondary_text'))
                  Row() {
                    Text(this.snapshot.permission === 0 ? this.uiText("pm_do_almost_everything_15d2faac") : this.uiText("pm_save_and_comment_90e113d5")).fontSize(19).fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.primary_text')).layoutWeight(1)
                    SymbolGlyph($r('sys.symbol.chevron_right')).fontColor([$r('app.color.primary_text')])
                  }.width('100%').enabled(this.snapshot.owner !== false).onClick(() => { this.allowInvites = this.snapshot.invites; this.selectedPermission = this.snapshot.permission; this.onAction('permissions', ''); })
                  Text(this.uiText("pm_add_move_or_delete_pins_and_sections_comment_and_react_fd71094d")).fontSize(15).fontColor($r('app.color.secondary_text'))
                  ForEach(this.snapshot.users, (user: PinmonyBoardCollaborator) => { this.userRow(user, false) }, (user: PinmonyBoardCollaborator) => user.id + ':' + user.status)
                } else if (this.snapshot.phase === 'invite') {
                  Search({ value: this.query, placeholder: this.uiText("pm_search_by_name_or_username_59fb9fda") }).onChange((value: string) => { this.query = value; })
                  ForEach(this.snapshot.suggestions.filter((user: PinmonyBoardCollaborator): boolean =>
                    (user.name + ' ' + user.username).toLowerCase().includes(this.query.trim().toLowerCase())),
                    (user: PinmonyBoardCollaborator) => { this.userRow(user, true) }, (user: PinmonyBoardCollaborator) => user.id + ':' + user.status)
                  if (!this.snapshot.suggestions.length) { Text(this.uiText("pm_no_users_available_to_invite_3e007a00")).fontColor($r('app.color.secondary_text')) }
                } else {
                  Text(this.uiText("pm_permissions_978cbca6")).fontColor($r('app.color.secondary_text'))
                  this.permissionOption(0, this.uiText("pm_do_almost_everything_15d2faac"), this.uiText("pm_add_move_or_delete_pins_and_sections_comment_and_react_fd71094d"))
                  this.permissionOption(1, this.uiText("pm_save_and_comment_90e113d5"), this.uiText("pm_save_and_organize_pins_comment_and_react_contact_the_board_owner_8f42b5cd"))
                  Row({ space: 10 }) {
                    Checkbox({ name: 'allow-invites', group: 'collaborator' }).select(this.allowInvites)
                      .enabled(!this.snapshot.busy && !this.snapshot.uncertain && this.snapshot.owner === true)
                      .onChange((value: boolean) => { this.allowInvites = value; })
                    Text(this.uiText("pm_invite_others_7610922d")).fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text'))
                  }
                  Text(this.uiText("pm_collaborators_can_invite_others_to_this_board_ccf60f85")).fontColor($r('app.color.secondary_text'))
                }
              }
            }.width('100%').alignItems(HorizontalAlign.Start).padding(20)
          }.layoutWeight(1).width('100%').align(Alignment.Top)
          if (this.snapshot.canInvite === true && this.snapshot.phase === 'members' && !this.snapshot.loading && !this.snapshot.error) {
            Button(this.uiText("pm_invite_collaborators_602179cf")).width('100%').height(56).backgroundColor($r('app.color.surface_muted'))
              .fontColor($r('app.color.primary_text')).onClick(() => { this.query = ''; this.onAction('invite', ''); })
          }
        }.width('100%').height('100%').backgroundColor($r('app.color.page_background'))
      }.titleBar(this.titleOptions()).titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.scroller])
        .onBackPressed(() => { this.back(); return true; })
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .backgroundColor($r('app.color.page_background'))
  }
  build() {
    HdsNavigation(this.stack) {}
      .width('100%').height('100%').hideTitleBar(true)
      .navDestination(this.destination).backgroundColor($r('app.color.page_background'))
  }
}
