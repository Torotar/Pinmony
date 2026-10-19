import { PinmonyI18n } from 'common_foundation';
import { HdsNavigation, ScrollEffectType, hdsMaterial, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { PinmonySettingsStore } from '../stores/PinmonySettingsStore';
import { PinmonyCountry } from '../models/PinmonyAccountSettings';
@Component
export struct PinmonyAccountPage {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
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
  private title(): string { return this.store.screen === 'account' ? this.uiText("pm_account_management_3c072712") : this.store.screen === 'personal' ? this.uiText("pm_personal_information_640803d8") : this.store.screen === 'birthdate' ? this.uiText("pm_date_of_birth_1c54caca") : this.store.screen === 'gender' ? this.uiText("pm_gender_a752a7d8") : this.uiText("pm_country_region_45e22a8a"); }
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
          icon: new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]), label: this.uiText("pm_done_c0b3fbff"), isEnabled: this.canSave(),
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
    return p.length === 3 ? p[0] + this.uiText("pm_y_62ef900a") + Number(p[1]).toString() + this.uiText("pm_month_1625179b") + Number(p[2]).toString() + '日' : '';
  }
  private gender(): string { return this.store.data?.gender === 'female' ? this.uiText("pm_female_0ab4610b") : this.store.data?.gender === 'male' ? this.uiText("pm_male_4e79758a") : this.store.data?.gender === 'unspecified' ? this.store.data.customGender || '自定义' : ''; }
  @Builder
  private dateField(field: string, value: string) {
    Column({ space: 6 }) {
      Text(this.uiText(field === 'year' ? "pm_y_62ef900a" : field === 'month' ? "pm_month_1625179b" : "pm_day_85217f7a")).fontSize(13).fontColor($r('app.color.secondary_text'))
      TextInput({ text: value }).type(InputType.Number).maxLength(field === 'year' ? 4 : 2).fontColor($r('app.color.primary_text'))
        .backgroundColor(Color.Transparent).enabled(!this.store.busy).accessibilityText(this.uiText(field === 'year' ? "pm_y_62ef900a" : field === 'month' ? "pm_month_1625179b" : "pm_day_85217f7a"))
        .onChange((v: string) => { if (field === 'year') this.year = v; else if (field === 'month') this.month = v; else this.day = v; })
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
            Text(this.store.busy ? this.uiText("pm_saving_6bdb4435") : this.uiText("pm_loading_86b6d0d6")).fontColor($r('app.color.secondary_text'))
          }
          if (this.store.error) {
            Text(PinmonyI18n.render(this.store.error, this.uiLanguage)).fontColor($r('app.color.secondary_text'))
            Button(this.uiText("pm_reload_df7392cc")).enabled(!this.store.loading && !this.store.busy).onClick(() => { this.request(this.store.screen === 'country' ? 'countries' : 'read'); })
          }
          if (this.store.data?.ready && !this.store.loading) {
            if (this.store.screen === 'account') {
              Text(this.uiText("pm_your_account_d80b3d08")).fontSize(14).fontColor($r('app.color.secondary_text')).margin({ top: 12 })
              this.row(this.uiText("pm_personal_information_640803d8"), '', 'personal')
              this.row(this.uiText("pm_email_1b2714b8"), this.store.data.email)
              this.row(this.uiText("pm_password_a621ab60"), this.uiText("pm_change_password_946e28f6"))
              this.row(this.uiText("pm_phone_number_8e87c0dd"), this.uiText("pm_add_number_9d820e33"))
              this.row(this.uiText("pm_convert_to_a_business_account_4935be59"), '', '', this.uiText("pm_a_business_account_gives_you_tools_such_as_ads_and_analytics_to__50598c20"))
              Text(this.uiText("pm_deactivation_and_deletion_75be0aea")).fontSize(14).fontColor($r('app.color.secondary_text')).margin({ top: 20 })
              this.row(this.uiText("pm_deactivate_your_account_06052a52"), '', '', this.uiText("pm_temporarily_hide_your_profile_pins_and_boards_a6d31140"))
              this.row(this.uiText("pm_delete_your_data_and_account_ff4cef48"), '', '', this.uiText("pm_permanently_delete_your_data_and_everything_associated_with_your_2cb85273"))
            } else if (this.store.screen === 'personal') {
              if (this.birthday()) { this.row(this.uiText("pm_date_of_birth_1c54caca"), this.birthday()) }
              this.row(this.uiText("pm_gender_a752a7d8"), this.gender())
              this.row(this.uiText("pm_country_region_45e22a8a"), this.store.data.country)
            } else if (this.store.screen === 'birthdate') {
              Text(this.uiText("pm_your_date_of_birth_helps_personalize_recommendations_and_ads_and_00165eee")).fontSize(15).fontColor($r('app.color.secondary_text'))
              Text(this.uiText("pm_learn_why_we_ask_for_your_date_of_birth_09763a7d")).fontSize(14).fontColor($r('app.color.secondary_text')).decoration({ type: TextDecorationType.Underline }).onClick(() => {})
              Row({ space: 12 }) {
                this.dateField('year', this.year)
                this.dateField('month', this.month)
                this.dateField('day', this.day)
              }.width('100%').margin({ top: 28 })
            } else if (this.store.screen === 'gender') {
              this.genderRow(this.uiText("pm_female_0ab4610b"), 'female')
              this.genderRow(this.uiText("pm_male_4e79758a"), 'male')
              this.genderRow(this.uiText("pm_custom_4eafa9e9"), 'unspecified')
              if (this.store.data.gender === 'unspecified') {
                TextInput({ text: this.custom, placeholder: this.uiText("pm_enter_your_gender_e4d76c65") }).maxLength(500).enabled(!this.store.busy)
                  .fontColor($r('app.color.primary_text')).placeholderColor($r('app.color.secondary_text')).backgroundColor($r('app.color.surface_muted'))
                  .onChange((v: string) => { this.custom = v; })
                Text(this.custom.length.toString() + '/500').width('100%').textAlign(TextAlign.End).fontSize(12).fontColor($r('app.color.secondary_text'))
              }
            } else if (this.store.screen === 'country') {
              TextInput({ text: this.query, placeholder: this.uiText("pm_search_countries_regions_79d74e48") }).fontColor($r('app.color.primary_text'))
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
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
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
