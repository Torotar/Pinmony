import { PinmonyI18n } from 'common_foundation';
import { PinmonyUserAvatar } from 'common_ui';
import { PinmonyInboxItem } from '../models/PinmonyInbox';

@Component
export struct PinmonyInboxActivityRow {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  @Prop item: PinmonyInboxItem;
  @Prop interactionReady: boolean = false;
  onAction: (id: string) => void = () => {};
  onUser: (url: string) => void = () => {};
  private text(key: string): string { return PinmonyI18n.text(key,this.uiLanguage); }
  private timeLabel(): string {
    const age: number = Math.max(0,Date.now() - Date.parse(this.item.updatedAt || ''));
    if(!Number.isFinite(age))return '';
    const minutes: number = Math.floor(age / 60000);
    if(minutes < 1)return this.text('pm_activity_now');
    if(minutes < 60)return this.text('pm_activity_minutes').replace('{0}',minutes.toString());
    if(minutes < 1440)return this.text('pm_activity_hours').replace('{0}',Math.floor(minutes / 60).toString());
    return this.text('pm_activity_days').replace('{0}',Math.floor(minutes / 1440).toString());
  }
  private followLabel(): string {
    return this.text(this.item.activityUncertain ? 'pm_activity_check_status' : this.item.activityFollowed ? 'pm_activity_say_hello' : 'pm_activity_follow_back');
  }
  private openProfile(): void {
    if(this.interactionReady && this.item.enabled && this.item.profileUrl)this.onUser(this.item.profileUrl);
  }
  private openChat(): void {
    if(this.interactionReady && this.item.enabled)this.onAction('activity-chat:' + this.item.activityUserId);
  }
  private performAction(): void {
    if(!this.interactionReady || !this.item.enabled || this.item.activityBusy)return;
    if(this.item.activityUncertain)this.onAction('activity-retry');
    else if(this.item.activityFollowed)this.openChat();
    else this.onAction('activity-follow:' + this.item.activityUserId);
  }
  build() {
    Row({space:12}) {
      Button({type:ButtonType.Normal}) {
        PinmonyUserAvatar({profileUrl:this.item.profileUrl || '',image:this.item.imageUrl,colorIndex:this.item.avatarColorIndex || 0,name:this.item.title,avatarSize:48})
      }.padding(0).borderRadius(24).backgroundColor(Color.Transparent)
        .enabled(!!this.item.profileUrl).accessibilityText(this.item.title).onClick(() => this.openProfile())
      Button({type:ButtonType.Normal}) {
        Column({space:4}) {
          Text(this.item.title).fontSize(15).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary_text')).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis})
          Text(this.text('pm_activity_followed_you')).fontSize(15)
            .fontColor($r('app.color.primary_text')).maxLines(2).textOverflow({overflow:TextOverflow.Ellipsis})
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).padding(0).backgroundColor(Color.Transparent)
        .accessibilityText(this.item.title + ' ' + this.text('pm_activity_followed_you')).onClick(() => this.openChat())
      Button({type:ButtonType.Normal}) {
        if(this.item.activityBusy) {
          LoadingProgress().width(20).height(20).color($r('app.color.primary_text'))
        } else {
          Text(this.followLabel()).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text')).maxLines(2)
        }
      }.padding({left:16,right:16,top:12,bottom:12}).constraintSize({minWidth:72,maxWidth:128})
        .borderRadius(16).backgroundColor($r('app.color.surface_muted')).flexShrink(0)
        .enabled(this.interactionReady && !this.item.activityBusy)
        .accessibilityText(this.followLabel()).onClick(() => this.performAction())
      Text(this.timeLabel()).fontSize(12).fontColor($r('app.color.secondary_text')).flexShrink(0).alignSelf(ItemAlign.Center)
    }.width('100%').padding({left:20,right:20,top:12,bottom:12}).alignItems(VerticalAlign.Center)
      .enabled(this.interactionReady && this.item.enabled)
  }
}
