import { HdsNavigation, ScrollEffectType, hdsMaterial, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { PinmonySettingsStore } from '../stores/PinmonySettingsStore';
import { PinmonyCountry } from '../models/PinmonyAccountSettings';
@Component
export struct PinmonyAccountPage {
  @ObjectLink store: PinmonySettingsStore;
  onRequest?: (action: string, value: string) => Promise<void>;
  onBack?: () => void;
  @State private year: string = '';
  @State private month: string = '';
  @State private day: string = '';
  @State private custom: string = '';
  @State private query: string = '';
  private paths: NavPathStack = new NavPathStack();
  private scroller: Scroller = new Scroller();
  aboutToAppear(): void { this.paths.pushPath({ name: 'account' }, false); }
  private async request(action: string, value: string = ''): Promise<void> { if (this.onRequest) await this.onRequest(action, value); }
  private open(screen: string): void {
    const parts: string[] = (this.store.data?.birthdate || '').split('-');
    this.year = parts[0] || ''; this.month = parts[1] || ''; this.day = parts[2] || '';
    this.custom = this.store.data?.customGender || ''; this.query = '';
    this.store.screen = screen; this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
    if (screen === 'country') this.request('countries');
  }
  private title(): string { return this.store.screen === 'account' ? '账户管理' : this.store.screen === 'personal' ? '个人信息' : this.store.screen === 'birthdate' ? '出生日期' : this.store.screen === 'gender' ? '性别' : '国家/地区'; }
  private date(): string { return this.year.padStart(4, '0') + '-' + this.month.padStart(2, '0') + '-' + this.day.padStart(2, '0'); }
  private canSave(): boolean {
    if (!this.store.data || this.store.loading || this.store.busy || this.store.error) return false;
    if (this.store.screen === 'gender') return this.store.data.gender === 'unspecified' && !!this.custom.trim() && this.custom.length <= 500 && this.custom !== this.store.data.customGender;
    if (this.store.screen !== 'birthdate' || !/^\d{4}$/.test(this.year) || !/^\d{1,2}$/.test(this.month) || !/^\d{1,2}$/.test(this.day)) return false;
    const value: string = this.date(); const date: Date = new Date(value + 'T00:00:00Z');
    return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value && value <= new Date().toISOString().slice(0, 10) && value !== this.store.data.birthdate;
  }
  private async save(action: string, value: string): Promise<void> {
    await this.request(action, value);
    if (!this.store.error && this.store.data?.saved && action !== 'gender') this.store.screen = 'personal';
  }
  private options(): HdsNavigationTitleBarOptions {
    return { avoidLayoutSafeArea: true, enableComponentSafeArea: true,
      style: { scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE },
        scrollEffectStyle: { contentStyle: { backIconStyle: { iconColor: $r('app.color.primary_text') }, menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: { contentStyle: { backIconStyle: { iconColor: $r('app.color.primary_text') }, menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } },  backgroundStyle: { backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0 } } },
      content: { title: { mainTitle: this.title() }, backIcon: { isEnabled: !this.store.busy, action: () => { if (this.onBack) this.onBack(); } },
        menu: { value: ['birthdate', 'gender'].includes(this.store.screen) ? [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]), label: '完成', isEnabled: this.canSave(),
          action: () => { if (this.canSave()) this.save(this.store.screen === 'birthdate' ? 'birthdate' : 'customGender', this.store.screen === 'birthdate' ? this.date() : this.custom); }
        } }] : [] } } };
  }
  @Builder
  private row(label: string, value: string = '', target: string = '', subtitle: string = '') {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 8 }) {
        Row({ space: 12 }) {
          Text(label).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).layoutWeight(1)
          if (value) { Text(value).fontSize(15).fontColor($r('app.color.secondary_text')).maxLines(2) }
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([$r('app.color.primary_text')])
        }.width('100%')
        if (subtitle) { Text(subtitle).width('100%').fontSize(14).fontColor($r('app.color.secondary_text')) }
      }.width('100%').padding({ top: 16, bottom: 16 }).alignItems(HorizontalAlign.Start)
    }.width('100%').backgroundColor(Color.Transparent).enabled(!this.store.loading && !this.store.busy)
      .onClick(() => { if (target) this.open(target); }).accessibilityText(label)
  }
  private birthday(): string {
    const p: string[] = (this.store.data?.birthdate || '').split('-');
    return p.length === 3 ? p[0] + '年' + Number(p[1]).toString() + '月' + Number(p[2]).toString() + '日' : '';
  }
  private gender(): string { return this.store.data?.gender === 'female' ? '女' : this.store.data?.gender === 'male' ? '男' : this.store.data?.gender === 'unspecified' ? this.store.data.customGender || '自定义' : ''; }
  @Builder
  private dateField(label: string, value: string) {
    Column({ space: 6 }) {
      Text(label).fontSize(13).fontColor($r('app.color.secondary_text'))
      TextInput({ text: value }).type(InputType.Number).maxLength(label === '年' ? 4 : 2).fontColor($r('app.color.primary_text'))
        .backgroundColor(Color.Transparent).enabled(!this.store.busy).accessibilityText(label)
        .onChange((v: string) => { if (label === '年') this.year = v; else if (label === '月') this.month = v; else this.day = v; })
    }.layoutWeight(1).padding(10).border({ width: 1, color: $r('app.color.secondary_text'), radius: 14 }).alignItems(HorizontalAlign.Start)
  }
  @Builder
  private genderRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(20).fontColor($r('app.color.primary_text')).layoutWeight(1)
      Radio({ value: value, group: 'account-gender' }).checked(this.store.data?.gender === value)
        .enabled(!this.store.busy && !this.store.loading && !this.store.error).accessibilityText(label)
        .onChange((checked: boolean) => { if (checked && this.store.data?.gender !== value) this.save('gender', value); })
    }.width('100%').constraintSize({ minHeight: 48 })
  }
  @Builder
  private destination(_name?: string, _param?: Object) {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Center }) {
      Scroll(this.scroller) {
        Column({ space: 8 }) {
          if (this.store.loading || this.store.busy) {
            Text(this.store.busy ? '正在保存…' : '正在读取…').fontColor($r('app.color.secondary_text'))
          }
          if (this.store.error) {
            Text(this.store.error).fontColor($r('app.color.secondary_text'))
            Button('重新读取').enabled(!this.store.loading && !this.store.busy).onClick(() => { this.request(this.store.screen === 'country' ? 'countries' : 'read'); })
          }
          if (this.store.data?.ready && !this.store.loading) {
            if (this.store.screen === 'account') {
              Text('你的帐户').fontSize(14).fontColor($r('app.color.secondary_text')).margin({ top: 12 })
              this.row('个人信息', '', 'personal')
              this.row('电子邮件', this.store.data.email)
              this.row('密码', '更改密码')
              this.row('电话号码', '添加号码')
              this.row('转换为企业帐户', '', '', '拥有企业帐户后，你可以使用工具（例如广告和分析工具），以便在 Pinterest 上拓展业务')
              Text('停用和删除').fontSize(14).fontColor($r('app.color.secondary_text')).margin({ top: 20 })
              this.row('停用你的帐户', '', '', '暂时隐藏你的个人资料、Pin 图和图板')
              this.row('删除你的数据和帐户', '', '', '永久删除你的数据以及与你的帐户关联的所有内容')
            } else if (this.store.screen === 'personal') {
              if (this.birthday()) { this.row('出生日期', this.birthday()) }
              this.row('性别', this.gender())
              this.row('国家/地区', this.store.data.country)
            } else if (this.store.screen === 'birthdate') {
              Text('出生日期有助于为你提供更加个性化的体验，例如相关推荐内容和广告，其还有助于维护 Pinterest 社区的安全。此信息在你的个人资料中不可见。').fontSize(15).fontColor($r('app.color.secondary_text'))
              Text('详细了解我们为什么要求你提供出生日期').fontSize(14).fontColor($r('app.color.secondary_text')).decoration({ type: TextDecorationType.Underline }).onClick(() => {})
              Row({ space: 12 }) {
                this.dateField('年', this.year)
                this.dateField('月', this.month)
                this.dateField('日', this.day)
              }.width('100%').margin({ top: 28 })
            } else if (this.store.screen === 'gender') {
              this.genderRow('女', 'female')
              this.genderRow('男', 'male')
              this.genderRow('自定义', 'unspecified')
              if (this.store.data.gender === 'unspecified') {
                TextInput({ text: this.custom, placeholder: '输入你的性别' }).maxLength(500).enabled(!this.store.busy)
                  .fontColor($r('app.color.primary_text')).placeholderColor($r('app.color.secondary_text')).backgroundColor($r('app.color.surface_muted'))
                  .onChange((v: string) => { this.custom = v; })
                Text(this.custom.length.toString() + '/500').width('100%').textAlign(TextAlign.End).fontSize(12).fontColor($r('app.color.secondary_text'))
              }
            } else if (this.store.screen === 'country') {
              TextInput({ text: this.query, placeholder: '搜索国家/地区' }).fontColor($r('app.color.primary_text'))
                .placeholderColor($r('app.color.secondary_text')).backgroundColor($r('app.color.surface_muted')).onChange((v: string) => { this.query = v; })
              ForEach(this.store.data.countries.filter((c: PinmonyCountry) => (c.name + c.key).toLowerCase().includes(this.query.toLowerCase())).sort((a: PinmonyCountry, b: PinmonyCountry) => a.key === this.store.data?.country ? -1 : b.key === this.store.data?.country ? 1 : 0), (c: PinmonyCountry) => {
                Button({ type: ButtonType.Normal }) {
                  Row({ space: 12 }) {
                    Text(c.name).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).layoutWeight(1).textAlign(TextAlign.Start)
                    if (c.key === this.store.data?.country) { SymbolGlyph($r('sys.symbol.checkmark')).fontSize(20).fontColor([$r('app.color.primary_text')]) }
                  }.width('100%').padding({ top: 14, bottom: 14 })
                }.width('100%').constraintSize({ minHeight: 48 })
                  .fontColor($r('app.color.primary_text')).backgroundColor(Color.Transparent).enabled(!this.store.busy && !this.store.error)
                  .onClick(() => { this.save('country', c.key); })
              }, (c: PinmonyCountry) => c.key)
            }
          }
        }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 32 }).alignItems(HorizontalAlign.Start)
      }.width('100%').height('100%').align(Alignment.TopStart)
      if (this.store.loading || this.store.busy) {
        LoadingProgress().width(40).height(40).color($r('app.color.primary_text')).hitTestBehavior(HitTestMode.None)
      }
      }.width('100%').height('100%')
    }.titleBar(this.options()).titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
      .bindToScrollable([this.scroller]).onBackPressed(() => { if (this.onBack) this.onBack(); return true; })
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP]).backgroundColor($r('app.color.page_background'))
  }
  build() {
    HdsNavigation(this.paths) { Column().width('100%').height('100%') }
      .width('100%').height('100%').hideTitleBar(true).navDestination(this.destination).backgroundColor($r('app.color.page_background'))
  }
}
