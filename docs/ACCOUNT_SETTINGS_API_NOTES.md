# 账号管理与个人信息接口

## 当前范围（2026-10-04）

“我的 → 设置 → 账号管理”呈现个人信息、电子邮件、密码、电话号码、转换为企业帐户、停用与删除分组。按用户最新要求移除顶部确认邮箱区域，主题仅在显示设置提供。个人信息页出生日期、性别和地区均读取当前账号，出生日期按“年/月/日”格式显示，不固定截图中的日期。

个人信息页保留出生日期、性别、国家/地区三行和箭头，但按用户要求三项点击无操作，不打开编辑子页、不触发写入。原有字段更新合同仅记录已有服务能力，当前 UI 不提供入口。其他账号管理提交、确认邮箱、帮助链接保持点击无操作；设置根页的退出账号保留系统确认弹窗，账户安全入口已移除。显示设置、优化推荐与新增个人资料可见性见下方说明。编辑个人资料沿用现有只读入口，不新增保存能力。

## 请求合同

来源为用户提供的“设置页的六项内容.har”。这些是 Pinterest 网站内部资源，不是官方开放 API；仍依赖当前 ArkWeb 登录会话，无 OAuth 或独立令牌体系。

- 读取 `GET /resource/UserSettingsResource/get/`，options 为空，source_url 为 `/settings/account-settings/`。返回当前账号 id、username、email、has_confirmed_email、birthdate、gender、custom_gender、country。id 仅在注入脚本临时内存使用，不传到原生展示合同，不记录或持久化。
- 读取 `GET /resource/CountriesResource/get/`，options 为空，source_url 为 `/settings/edit/country-region/`。列表字段为 key、name；校验两位大写代码和有界名称。原生列表支持按名称/代码搜索。
- 写入 `POST /resource/UserSettingsResource/update/`，Content-Type 为 application/x-www-form-urlencoded。data 为 JSON `{ options, context: {} }`，与 source_url 分别编码。surface_tag 固定为 settings。
- 出生日期：只写 birthdate、surface_tag；日期格式 YYYY-MM-DD，校验实际日历日期和不晚于今天，不自行换用 birthday 字段。
- 性别：user_id 从本次设置读取取得；gender 值只允许 female/male/unspecified。点击选择即时提交，只在响应确认后更新选中态。
- 自定义性别：先选择并确认 unspecified，再以完成按钮提交 custom_gender，非空且最多 500 字符。两次请求是 HAR 捕获的两个独立字段更新，不合并或重放。
- 地区：使用当前 CountriesResource 返回的 key，带 user_id、surface_tag；点击提交并在成功后返回个人信息。
- 写响应必须满足 resource_response.status=success、code=0，且返回修改字段与本次提交相同。请求发出或 HTTP 200 不代表保存成功。

## 会话、取消和状态

feature_settings 的模型和 PinWebSettingsStore 负责页面状态；Index 只协调当前会话脚本、轮询结果与返回。原生传输由 common_network 的 useNativeTransport 执行，凭据沿用 common_session。common_network 仅新增 CountriesResource 读取及 birthdate/gender/custom_gender/country 的单字段 UserSettingsResource 更新白名单，增加隐私布尔字段更新，不开放密码、邮箱、停用/删除等写入。

每次操作在读取设置后核对 username 与当前资料完整地址。请求绑定当前完整页面地址、原生文档 epoch、页面 token 和脚本 generation。总请求窗口 15 秒，重复点击不重复提交；关闭、返回读取页或明确会话失效废弃 token 并取消请求。写入期间阻止返回，避免未完成操作误更新其他页面；系统与标题栏返回按编辑页 → 个人信息 → 账号管理 → 设置 → 我的退栈。

读取失败显示读取错误与重新读取。写入异常或响应未确认显示“保存结果未确认”，只提供重新读取，不自动重新保存。失败不回退 DOM、不打开业务网页，不显示成功提示。成功响应仅更新确认过的字段。账号信息仅在本次设置页内存中展示，关闭后清理。

HDS MINI 负责标题栏与顶部安全区，正文绑定同一 Scroller；Index 在设置子页不增加状态栏 padding。颜色沿用 common_ui 深浅色资源；保持底栏隐藏与系统手势区。

## 验证与回退

`node scripts/check-account-settings.cjs <TypeScript模块路径>` 覆盖读取映射、日期合法性、账号身份、自定义性别、国家选项、写失败不重放、取消后的迟到响应和原生白名单。配合 check-native-network、check-module-architecture、登录门禁与根页保留检查，并构建 entry HAP。

合成检查和未签名构建不证明 Pinterest 线上可用或真机行为。真机需检查当前账号读取、三类字段实际保存、网络失败重新读取、深浅色、键盘、大字体、滚动及每层返回。无签名/安装验收时应明确报告。

手动撤回接入时，在 PinWebSettingsPage 中移除账号管理的导航回调，恢复该项无操作；不改变其他业务开关，不执行旧快照覆盖。历史原生登录基线仍为 backups/native-login-before-20261002-102059，不能用其旧单模块路径强制覆盖当前架构。

## 显示、推荐与资料可见性（2026-10-04）

显示设置按用户要求移除“外观”分组标题与底栏收起动画的说明文案，底栏收起动画开关移入此页，沿用 bottomBarScrollCollapseEnabled 的持久化与现有滑动动作。主题通过 themePreference 持久化 system/light/dark；默认跟随系统。使用应用 ColorMode 切换，EntryAbility 同步资源与状态栏/导航栏字色；主题入口仅保留在显示设置，账号管理不再提供。不是通过网站 API 修改主题。账号与偏好子页的 Scroll 显式顶部对齐，短内容从标题栏下方排列；优化推荐使用 CapsuleSegmentButtonV2 切换 AI 内容与动态，切换后正文回到顶部。

优化推荐包含 AI 内容和动态分段；顶部介绍移到 HDS MINI 标题栏右侧 exclamationmark_circle Symbol 菜单，点击通过 UIContext.showAlertDialog 系统弹窗展示原文：

- AI 主题列表通过 ApiResource/get → /v3/users/settings/gen_ai/ 读取；标签、key、opt_out 和 interest_ids 均来自当前响应，最多 40 项。多 ID 主题保留全部 ID，只在脚本运行内存中使用。开关开启对应 opt_out=false。
- 单主题与显示 AI 内容总开关通过 ApiResource/create → /v3/users/settings/ 提交 gen_ai_topics_opt_in 或 gen_ai_topics_opt_out，值为当前主题对应的字符串 ID 数组；gen_ai_topics_update_source=hf_tuner。总开关用当前返回全部主题的 ID 并集，单次提交，不逐项写入。业务成功后校验 opt_out 列表，再重新读取主题确认实际状态；不会按点击推断成功。
- 动态使用 UserRecentActivityResource/get，options={username:me, filter_type:all}，source_url=/edit/activity/。按本次接口返回的 Pin 图片和比例呈现双列，保留返回 bookmark。首份 HAR 只有首屏读取。补充的动态推荐.har 捕获两次关闭推荐，用户确认两次都是关闭：ApiResource/update → /v3/pfy/{当前Pin ID}/feedback/，data={pin:当前Pin ID, feedback_type:4, through_id:当前Pin ID, rec_reason_type:4}。ID 仅来自当前列表，提交前重新读取列表核对；成功需 status=success、code=0、endpoint_name=v3_provide_pfy_pin_feedback，并匹配返回 Pin id/type。确认后显示暗色遮罩与“已关闭此 Pin 图推荐”；不自动重放，结果不确定时标记未确认并禁用再次提交。按用户截图定制右下角紫色勾选操作控件，点击请求关闭推荐；确认关闭后变为白色未勾选方块、暗色图片与提示文案。勾选控件是关闭动作入口，列表未提供可核验的历史推荐开关状态；关闭证据只留当前脚本内存，关闭设置会话后清理。恢复推荐尚无捕获合同，暂不接入；分页仍未接入，不打开业务网页。

新增设置入口“个人资料可见性”，读取 opt_in_private_account、search_privacy_enabled（缺失时读取 exclude_from_search）、allow_switch_between_private_and_public_profile、can_edit_search_privacy。缺失权限、家长验证码启用或验证待完成时不启用私密切换；不绕过验证。

私密开关先展示图四/图五对应的公开/设为私密确认面板，取消不发请求。面板使用数值高度 min(380vp, 当前页面高度×0.8)，不使用默认 MEDIUM 或 FIT_CONTENT；内容可滚动，支持系统关闭控件、遮罩与返回。确认后 UserSettingsResource/update 单字段提交 opt_in_private_account，带当前 user_id、surface_tag=settings、user_confirm_skip_passcode=false。搜索隐私单独更新 exclude_from_search。业务响应核对布尔字段，再重新读取设置确认；若读回失败，保持保存未确认错误且不自动重放。搜索隐私不能与私密开关合并猜测写入。

检查 scripts/check-settings-preferences.cjs 覆盖动态映射、动态无写入、当前 AI 主题及多 ID、总开关、单主题、回读校验、错误不重放、账号权限与跳过验证码禁止；scripts/check-settings-display.cjs 覆盖主题切换、失败恢复、系统栏颜色和面板返回层级；配合既有账号、网络、登录与模块检查。手机上的面板高度、旋转、大字体、触控、真实保存、主题资源和系统栏仍需签名安装后验证。
