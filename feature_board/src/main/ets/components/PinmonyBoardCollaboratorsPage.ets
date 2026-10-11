import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { PinmonyBoardCollaborators, PinmonyBoardCollaborator } from '../models/PinmonyBoardCollaborators';

@Component
export struct PinmonyBoardCollaboratorsPage {
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
      style: { scrollEffectOpts: { enableScrollEffect: false }, originalStyle: { backgroundStyle: {
        backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0 } } },
      content: { title: { mainTitle: this.snapshot.phase === 'invite' ? '邀请合作用户' :
        this.snapshot.phase === 'permissions' ? '合作用户可以…' :
          this.snapshot.users.filter((user: PinmonyBoardCollaborator): boolean => user.status === 'owner' || user.status === 'accepted').length.toString() + ' 位合作用户' },
        backIcon: { isEnabled: !this.snapshot.busy, action: () => this.back() },
        menu: { value: this.snapshot.phase === 'permissions' ? [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]),
          label: '完成', isEnabled: !this.snapshot.busy && !this.snapshot.uncertain && this.snapshot.owner === true &&
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
      if (user.avatar) { Image(user.avatar).width(44).height(44).borderRadius(22) }
      else { Image($r('app.media.lucide_user_round')).width(44).height(44).padding(10).borderRadius(22).backgroundColor($r('app.color.surface_muted')) }
      Column({ space: 2 }) {
        Text(user.name).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text'))
        if (invite) { Text(user.username).fontSize(13).fontColor($r('app.color.secondary_text')) }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (invite && !user.status) {
        Button('邀请').backgroundColor($r('app.color.accent')).fontColor(Color.White)
          .enabled(!this.snapshot.busy && !this.snapshot.uncertain)
          .onClick(() => this.onAction('send', user.id))
      } else {
        Text(user.status === 'owner' ? '所有者' : user.status === 'accepted' ? '合作用户' : '已邀请')
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
                Text(this.snapshot.error).fontColor($r('app.color.secondary_text'))
                if (!this.snapshot.uncertain && !this.snapshot.busy) { Button('重试').onClick(() => this.onAction('retry', '')) }
              } else if (!this.snapshot.loading) {
                if (this.snapshot.phase === 'members') {
                  Text('合作用户可以…').fontSize(13).fontColor($r('app.color.secondary_text'))
                  Row() {
                    Text(this.snapshot.permission === 0 ? '做（几乎）所有事情' : '收藏并进行评论').fontSize(19).fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.primary_text')).layoutWeight(1)
                    SymbolGlyph($r('sys.symbol.chevron_right')).fontColor([$r('app.color.primary_text')])
                  }.width('100%').enabled(this.snapshot.owner !== false).onClick(() => { this.allowInvites = this.snapshot.invites; this.selectedPermission = this.snapshot.permission; this.onAction('permissions', ''); })
                  Text('添加、移动或删除 Pin 图和图板区块，进行评论并作出回应').fontSize(15).fontColor($r('app.color.secondary_text'))
                  ForEach(this.snapshot.users, (user: PinmonyBoardCollaborator) => { this.userRow(user, false) }, (user: PinmonyBoardCollaborator) => user.id)
                } else if (this.snapshot.phase === 'invite') {
                  Search({ value: this.query, placeholder: '按姓名或用户名搜索' }).onChange((value: string) => { this.query = value; })
                  ForEach(this.snapshot.suggestions.filter((user: PinmonyBoardCollaborator): boolean =>
                    (user.name + ' ' + user.username).toLowerCase().includes(this.query.trim().toLowerCase())),
                    (user: PinmonyBoardCollaborator) => { this.userRow(user, true) }, (user: PinmonyBoardCollaborator) => user.id)
                  if (!this.snapshot.suggestions.length) { Text('暂无可邀请的用户').fontColor($r('app.color.secondary_text')) }
                } else {
                  Text('权限').fontColor($r('app.color.secondary_text'))
                  this.permissionOption(0, '做（几乎）所有事情', '添加、移动或删除 Pin 图和图板区块，进行评论并作出回应')
                  this.permissionOption(1, '收藏并进行评论', '收藏和整理 Pin 图，发表评论以及作出回应。如需获取更多权限，请联系图板所有者！')
                  Row({ space: 10 }) {
                    Checkbox({ name: 'allow-invites', group: 'collaborator' }).select(this.allowInvites)
                      .enabled(!this.snapshot.busy && !this.snapshot.uncertain && this.snapshot.owner === true)
                      .onChange((value: boolean) => { this.allowInvites = value; })
                    Text('邀请其他用户').fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text'))
                  }
                  Text('合作用户可以邀请他人加入此图板').fontColor($r('app.color.secondary_text'))
                }
              }
            }.width('100%').alignItems(HorizontalAlign.Start).padding(20)
          }.layoutWeight(1).width('100%').align(Alignment.Top)
          if (this.snapshot.canInvite === true && this.snapshot.phase === 'members' && !this.snapshot.loading && !this.snapshot.error) {
            Button('＋ 邀请合作用户').width('100%').height(56).backgroundColor($r('app.color.surface_muted'))
              .fontColor($r('app.color.primary_text')).onClick(() => { this.query = ''; this.onAction('invite', ''); })
          }
        }.width('100%').height('100%')
      }.titleBar(this.titleOptions()).titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.scroller])
        .onBackPressed(() => { this.back(); return true; })
        .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
  }
  build() {
    HdsNavigation(this.stack) {}
      .width('100%').height('100%').hideTitleBar(true)
      .navDestination(this.destination).backgroundColor($r('app.color.page_background'))
  }
}
