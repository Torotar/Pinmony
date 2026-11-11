import { PinmonyUserAvatar } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';

export interface PinmonyProfileHubTitleOptions {
  profileUrl: string;
  avatarUrl: string;
  avatarColorIndex: number;
  displayName: string;
  selectedTab: string;
  indicatorPosition: number;
  interactionEnabled: boolean;
  backdropOpacity: number;
  statusInsetVp: number;
  onTabSelected: (tab: string) => void;
  onSettings: () => void;
}

@Builder
export function buildPinmonyProfileHubTitle($$: PinmonyProfileHubTitleOptions) {
  PinmonyProfileHubTitle({
    profileUrl: $$.profileUrl, avatarUrl: $$.avatarUrl, avatarColorIndex: $$.avatarColorIndex,
    displayName: $$.displayName, selectedTab: $$.selectedTab, indicatorPosition: $$.indicatorPosition,
    interactionEnabled: $$.interactionEnabled, backdropOpacity: $$.backdropOpacity,
    statusInsetVp: $$.statusInsetVp, onTabSelected: $$.onTabSelected, onSettings: $$.onSettings
  })
}

@Component
struct PinmonyProfileHubTitle {
  @Prop profileUrl: string = '';
  @Prop avatarUrl: string = '';
  @Prop avatarColorIndex: number = 0;
  @Prop displayName: string = '';
  @Prop selectedTab: string = 'boards';
  @Prop indicatorPosition: number = 1;
  @Prop interactionEnabled: boolean = false;
  @Prop backdropOpacity: number = 1;
  @Prop statusInsetVp: number = 0;
  onTabSelected: (tab: string) => void = (_tab: string): void => {};
  onSettings: () => void = (): void => {};
  @State private tabBarWidth: number = 0;
  @StorageLink('profileAvatarRight') private avatarRight: boolean = false;
  @StorageLink('pinmonyUpdateUnread') private updateUnread: boolean = false;
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }

  @Builder
  private avatar() {
    Badge({ value: '', position: BadgePosition.RightTop,
      style: { badgeSize: this.updateUnread ? 8 : 0, fontSize: 0, badgeColor: $r('app.color.detail_save_accent') } }) {
      PinmonyUserAvatar({ profileUrl: this.profileUrl, image: this.avatarUrl, name: this.displayName,
        avatarSize: 44, colorIndex: this.avatarColorIndex, websiteFallback: true })
        .accessibilityLevel('no')
    }.width(44).height(44).accessibilityGroup(true)
      .accessibilityText(this.uiText('pm_settings_df3d58c7') +
        (this.updateUnread ? ' · ' + this.uiText('pm_new_version_available_596dd46c') : ''))
      .onClick(this.onSettings)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column().width('100%').height(this.statusInsetVp + 80)
        .position({ x: 0, y: -this.statusInsetVp })
        .backgroundColor($r('app.color.page_background')).opacity(this.backdropOpacity)
        .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      Column() {
        Column({ space: 12 }) {
          Row({ space: 12 }) {
            if (!this.avatarRight) { this.avatar() } else { Row().width(44).height(44) }
            Column() {
              Stack({ alignContent: Alignment.BottomStart }) {
                Row() {
                  ForEach(['pins', 'boards', 'collages'], (tab: string) => {
                    Button({ type: ButtonType.Normal, stateEffect: false }) {
                      Column({ space: 12 }) {
                        Text(this.uiText('pm_profile_hub_' + tab)).fontSize(18).fontWeight(FontWeight.Bold)
                          .fontColor($r('app.color.primary_text'))
                        Row().height(2).width('100%').backgroundColor(Color.Transparent)
                      }.padding({ top: 12, bottom: 12 })
                    }.layoutWeight(1).height(64).backgroundColor(Color.Transparent).hoverEffect(HoverEffect.None)
                      .accessibilitySelected(this.selectedTab === tab).enabled(this.interactionEnabled)
                      .onClick(() => this.onTabSelected(tab))
                  }, (tab: string): string => tab + ':' + this.uiLanguage)
                }.width('100%').height(64)
                Row().height(2).width(24).backgroundColor($r('app.color.detail_save_accent'))
                  .translate({ x: this.indicatorPosition * this.tabBarWidth / 3 + (this.tabBarWidth / 3 - 24) / 2, y: -12 })
                  .hitTestBehavior(HitTestMode.None)
              }.width('100%').constraintSize({ maxWidth: 360 }).height(64)
                .onAreaChange((_old: Area, area: Area) => {
                  const width: number = Number(area.width);
                  if (width > 0 && Math.abs(width - this.tabBarWidth) > 0.1) this.tabBarWidth = width;
                })
            }.layoutWeight(1).height(64).alignItems(HorizontalAlign.Center)
            if (this.avatarRight) { this.avatar() } else { Row().width(44).height(44) }
          }.width('100%')
        }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 4 })
      }.width('100%').height(80)
    }.width('100%').height(56).clip(false).hitTestBehavior(HitTestMode.Transparent)
  }
}
