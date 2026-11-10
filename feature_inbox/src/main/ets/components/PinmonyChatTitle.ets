import { PinmonyUserAvatar } from 'common_ui';

export interface PinmonyChatTitleOptions {
  visible: boolean;
  title: string;
  userId: string;
  profileUrl: string;
  avatar: string;
  colorIndex: number;
  name: string;
  hasPeer: boolean;
  onAvatar: () => void;
  onUser: () => void;
}

@Builder
export function buildPinmonyChatTitle(options: PinmonyChatTitleOptions) {
  if (options.visible) {
    Row({ space: 10 }) {
      if (options.hasPeer) {
        PinmonyUserAvatar({ profileUrl: options.profileUrl, userId: options.userId,
          image: options.avatar, colorIndex: options.colorIndex, name: options.name, avatarSize: 32 })
          .onClick(options.onAvatar)
      }
      Text(options.title).fontSize(20).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.primary_text'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        .onClick(options.onUser)
    }.width('100%').padding({ left: 80, right: 72 }).alignItems(VerticalAlign.Center)
      .hitTestBehavior(HitTestMode.Transparent)
  }
}
