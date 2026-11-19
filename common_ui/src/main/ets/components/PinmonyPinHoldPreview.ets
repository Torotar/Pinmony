import { UIContext } from '@kit.ArkUI';
import { PinmonyI18n } from 'common_foundation';

export class PinmonyPinHoldFrame {
  originX: number = 0;
  originY: number = 0;
  hostWidth: number = 0;
  hostHeight: number = 0;
  left: number = 0;
  top: number = 0;
  right: number = 0;
  bottom: number = 0;
  anchorX: number = 0;
  anchorY: number = 0;
  board: boolean = false;
  profileBoard: boolean = false;
  private buttonsX: number[] = [];
  private buttonsY: number[] = [];

  optionCount(): number { return this.board ? 5 : 3; }

  static measure(ui: UIContext, hostId: string, photoId: string, x: number, y: number,
    board: boolean, profileBoard: boolean = false, chromeBottom: number = 0): PinmonyPinHoldFrame | undefined {
    try {
      const utils = ui.getComponentUtils();
      const host = utils.getRectangleById(hostId);
      const photo = utils.getRectangleById(photoId);
      if (!host || !photo || host.size.width <= 0 || host.size.height <= 0 || photo.size.width <= 0 || photo.size.height <= 0) return undefined;
      const frame = new PinmonyPinHoldFrame();
      frame.board = board;
      frame.profileBoard = profileBoard;
      frame.originX = ui.px2vp(host.windowOffset.x);
      frame.originY = ui.px2vp(host.windowOffset.y);
      frame.hostWidth = ui.px2vp(host.size.width);
      frame.hostHeight = ui.px2vp(host.size.height);
      const px = ui.px2vp(photo.windowOffset.x) - frame.originX;
      const py = ui.px2vp(photo.windowOffset.y) - frame.originY;
      frame.left = Math.max(0, px);
      frame.top = Math.max(0, py);
      frame.right = Math.min(frame.hostWidth, px + ui.px2vp(photo.size.width));
      frame.bottom = Math.min(frame.hostHeight, py + ui.px2vp(photo.size.height));
      frame.anchorX = x - frame.originX;
      frame.anchorY = y - frame.originY;
      if (!(frame.anchorX >= frame.left && frame.anchorX <= frame.right &&
        frame.anchorY >= frame.top && frame.anchorY <= frame.bottom)) return undefined;
      return frame.placeButtons(chromeBottom) ? frame : undefined;
    } catch (_) { return undefined; }
  }

  private placeButtons(chromeBottom: number): boolean {
    // Open toward the available interior. Only translate the fan if its buttons would cross a safe edge.
    const inset = 34;
    const top = Math.max(44, chromeBottom + inset);
    const bottom = this.hostHeight - 58;
    const dx = this.hostWidth / 2 - this.anchorX;
    const dy = (top + bottom) / 2 - this.anchorY;
    const preferred = dx * dx + dy * dy < 18 * 18 ? -Math.PI / 2 : Math.atan2(dy, dx);
    let bestScore = Number.POSITIVE_INFINITY;
    // Try other directions when needed, preserving spacing rather than squeezing buttons together.
    for (let step = 0; step < 16; step++) {
      const direction = preferred + step * Math.PI / 8;
      let minX = inset;
      let maxX = this.hostWidth - inset;
      let minY = top;
      let maxY = bottom;
      const offsetsX: number[] = [];
      const offsetsY: number[] = [];
      for (let i = 0; i < this.optionCount(); i++) {
        const slot = this.board ? [0, 2, 3, 1, 4][i] : i;
        const angle = direction + (slot - (this.optionCount() - 1) / 2) * 42 * Math.PI / 180;
        const x = Math.cos(angle) * 94;
        const y = Math.sin(angle) * 94;
        offsetsX.push(x);
        offsetsY.push(y);
        minX = Math.max(minX, inset - x);
        maxX = Math.min(maxX, this.hostWidth - inset - x);
        minY = Math.max(minY, top - y);
        maxY = Math.min(maxY, bottom - y);
      }
      if (minX > maxX || minY > maxY) continue;
      const x = Math.max(minX, Math.min(maxX, this.anchorX));
      const y = Math.max(minY, Math.min(maxY, this.anchorY));
      const positionsX = offsetsX.map((offset: number): number => x + offset);
      const positionsY = offsetsY.map((offset: number): number => y + offset);
      // Never place a selectable button under the finger at the moment the menu opens.
      if (positionsX.some((cx: number, index: number): boolean =>
        Math.hypot(cx - this.anchorX, positionsY[index] - this.anchorY) < 40)) continue;
      const score = Math.hypot(x - this.anchorX, y - this.anchorY) + Math.min(step, 16 - step) * 12;
      if (score >= bestScore) continue;
      bestScore = score;
      this.buttonsX = positionsX;
      this.buttonsY = positionsY;
      if (score === 0) break;
    }
    return this.buttonsX.length === this.optionCount();
  }

  buttonX(index: number): number { return this.buttonsX[index]; }
  buttonY(index: number): number { return this.buttonsY[index]; }
  choice(x: number, y: number): number {
    const anchorDx = x - this.anchorX;
    const anchorDy = y - this.anchorY;
    if (anchorDx * anchorDx + anchorDy * anchorDy < 18 * 18) return -1;
    let best = 31 * 31;
    let candidate = -1;
    for (let i = 0; i < this.optionCount(); i++) {
      const dx = x - this.buttonX(i);
      const dy = y - this.buttonY(i);
      const sq = dx * dx + dy * dy;
      if (sq < best) { best = sq; candidate = i; }
    }
    return candidate;
  }
  labelOnRight(): boolean {
    return this.left + this.right < this.hostWidth;
  }

  labelTop(chromeBottom: number): number {
    // Prefer the same 52vp gap above the photo on both surfaces, while keeping the
    // label below any foreground chrome (the home title belongs to HDS, not this stack).
    return Math.max(38, chromeBottom + 12, Math.min(this.top - 52, this.hostHeight - 85));
  }

  label(index: number): string {
    if (this.profileBoard) {
      if (index === 0) return 'pm_profile_board_hold_reorder';
      if (index === 1) return 'pm_share_7e564575';
      return 'pm_edit_05183656';
    }
    if (index === 1) return this.board ? 'pm_share_pin_d85b11f9' : 'pm_share_7e564575';
    if (index === 2) return 'pm_search_image_8f938fb8';
    if (index === 3) return 'pm_edit_pin_f9119bcf';
    if (index === 4) return 'pm_profile_board_hold_reorder';
    return this.board ? 'pm_move_to_another_board_62574b0d' : 'pm_save_60a53514';
  }
}

@Component
export struct PinmonyPinHoldPreview {
  @Prop frame: PinmonyPinHoldFrame;
  @Prop boardEditable: boolean = true;
  @Prop searchEnabled: boolean = true;
  @Prop selectedIndex: number = -1;
  @Prop coverDimmed: boolean = false;
  @Prop chromeBottom: number = 0;
  @Prop cursorX: number = 0;
  @Prop cursorY: number = 0;
  @StorageProp('systemDarkMode') private dark: boolean = false;
  @StorageProp('pinmonyLanguage') private uiLanguage: string = 'zh';

  @Builder
  private veil(x: number, y: number, w: number, h: number) {
    Column().width(w).height(h).position({ x: x, y: y })
      .backgroundColor($r('app.color.page_background')).opacity(0.88)
  }

  private tint(active: boolean): string {
    if (this.dark) return active ? '#D6F7F8FA' : '#D024272D';
    return active ? '#D6181A20' : '#D0FFFFFF';
  }

  private icon(index: number, active: boolean): Resource {
    if (index === 3 || (this.frame.profileBoard && index === 2)) return active !== this.dark ? $r('app.media.pin_hold_pencil_light') : $r('app.media.pin_hold_pencil_dark');
    if (index === 1) return $r('app.media.lucide_share_2');
    if (index === 4 || (this.frame.profileBoard && index === 0)) return $r('app.media.profile_sort_arrows');
    return $r('app.media.pin_hold_save');
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.veil(0, 0, this.frame.hostWidth, this.frame.top)
      this.veil(0, this.frame.bottom, this.frame.hostWidth, this.frame.hostHeight - this.frame.bottom)
      this.veil(0, this.frame.top, this.frame.left, this.frame.bottom - this.frame.top)
      this.veil(this.frame.right, this.frame.top, this.frame.hostWidth - this.frame.right, this.frame.bottom - this.frame.top)
      if (this.coverDimmed) {
        Column().width(this.frame.right - this.frame.left).height(this.frame.bottom - this.frame.top)
          .position({ x: this.frame.left, y: this.frame.top })
          .backgroundColor($r('app.color.page_background')).opacity(0.42)
      }
      ForEach(this.frame.board ? [0, 1, 2, 3, 4] : [0, 1, 2], (index: number) => {
        Stack() {
          Column().width('100%').height('100%').borderRadius(27).clip(true).backdropBlur(this.selectedIndex === index ? 18 : 14)
          Column().width('100%').height('100%').borderRadius(27).backgroundColor(this.tint(this.selectedIndex === index))
          if (index === 2 && !this.frame.profileBoard) {
            SymbolGlyph($r('sys.symbol.circle_viewfinder')).fontSize(24)
              .fontColor([this.selectedIndex === index ? $r('app.color.page_background') : $r('app.color.primary_text')])
          } else if (index === 3 || (this.frame.profileBoard && index === 2)) {
            Image(this.icon(index, this.selectedIndex === index)).width(25).height(25).draggable(false)
          } else {
            Image(this.icon(index, this.selectedIndex === index)).width(24).height(24).draggable(false)
              .fillColor(this.selectedIndex === index ? $r('app.color.page_background') : $r('app.color.primary_text'))
          }
        }.width(54).height(54).borderRadius(27)
          .opacity((this.frame.board && !this.boardEditable && (index === 0 || index === 4)) ||
            (!this.frame.profileBoard && index === 2 && !this.searchEnabled) ? 0.42 : 1).border({ width: 1, color: '#30999A9E' })
          .position({ x: this.frame.buttonX(index) - 27, y: this.frame.buttonY(index) - 27 })
          .scale({ x: this.selectedIndex === index ? 1.14 : 1, y: this.selectedIndex === index ? 1.14 : 1 })
          .animation({ duration: 100, curve: Curve.EaseOut })
      }, (index: number): string => index.toString())
      if (this.selectedIndex >= 0) {
        Row() {
          Text(PinmonyI18n.text(this.frame.label(this.selectedIndex), this.uiLanguage))
            .fontSize(36).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
            .textAlign(this.frame.labelOnRight() ? TextAlign.RIGHT : TextAlign.LEFT)
            .maxLines(2).constraintSize({ maxWidth: '75%' })
        }.width('100%').padding({ left: 16, right: 16 }).direction(Direction.Ltr)
          .justifyContent(this.frame.labelOnRight() ? FlexAlign.End : FlexAlign.Start)
          .position({ x: 0, y: this.frame.labelTop(this.chromeBottom) })
      }
      Stack() {
        Column().width(19).height(19).borderRadius(9.5).backgroundColor('#77FFFFFF')
      }.width(24).height(24).borderRadius(12).border({ width: 1, color: '#54999A9E' })
        .position({ x: this.cursorX - 12, y: this.cursorY - 12 })
    }.width('100%').height('100%').hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
      .transition(TransitionEffect.OPACITY.animation({ duration: 130, curve: Curve.EaseOut }))
  }
}
