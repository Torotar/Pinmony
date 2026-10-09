# 图板选项、整理选择与更多点子

## 范围（2026-10-03）

按用户提供的六张截图调整 `feature_board`，沿用 `PIN_BOARD_API_ENABLED=true`。
图板名称保留原有 HDS MINI 标题栏位置，分享按钮位于三点菜单左侧；正文为数量、当前所有者头像、整理/更多点子入口与两列瀑布流。
图板详情透传当前 BoardResource 返回的 privacy；仅 secret 图板在数量前显示轮廓锁头、“私密”和分隔点，公开或隐私状态未确认时不显示该标识。锁头沿用主题颜色，支持深浅色；静态检查和未签名HAP构建通过，真机显示待验证。
三点菜单采用原生 `bindSheet` 的 FIT_CONTENT 高度，按实际内容测量，内容行与帖子菜单同为17fp Medium文字、左右24/20vp和上下14vp内边距、底部20vp留白，沿用帖子菜单的拖动条、标题、右上角关闭按钮与遮罩，正文显示编辑信息和设置、存档。存档改用 UIContext.showAlertDialog 系统确认弹窗，标题“将图板存档？”，说明严格沿用用户截图，仅替换当前图板名称；取消关闭，存档提交原有校验接口；绑定当前图板会话，提交时禁止重复操作，失败保留真实状态，未知结果不允许重发。
编辑子页标题“编辑图板”，保留HDS MINI标题栏，右上角打勾提交；正文按用户截图排列名称、描述、私密图板、合作用户、设置（个性化、图板请求）和操作（删除图板）。协作者邀请配置保留读取值并原样提交；添加合作用户缺少邀请提交合同，仍无操作；删除图板已按既有HAR接入。
图板操作仅在当前会话用户与图板 owner ID 一致时启用；所有 Pin 集合不显示这些操作。
图板 Pin 卡片右下角三点（含更多点子未收藏卡片）复用首页 Pin 菜单及其已接入的收藏、分享、下载、查看更多/查看更少操作；使用当前图板地址和实际 Pin 身份读取帖子内部资源，重试保持来源地址，切换页面后废弃旧菜单。图片点击与菜单按钮独立，打开菜单不进入详情。
图板标题栏分享复用详情分享流程中的 ShareKit 系统分享能力，传递当前已校验图板地址和标题。图板的 Pinterest 联系人/邀请短链合同尚未确认，不套用 Pin 的 objectId/invite_category。邀请、添加到图板和添加图板区块仍无操作。
移动目标行保持正常颜色，不对不可移动图板降透明度；点击继续检查来源图板、归档、write权限及忙碌/未知结果限制，服务端提交校验保留。更多点子收藏按钮使用36vp白色圆形、24fp黑色加号，已收藏为黑色圆形白色勾号。
更多点子收藏经服务端校验后，卡片增加暗色遮罩，图片顶部显示“已收藏至 <当前图板名> 图板”，右下角显示勾号；卡片下方继续保留三点。反馈使用官方HdsSnackBar提示条，显示“已收藏至 <当前图板名>”，约4秒消失。按当前地址/会话中的saved新增项触发，重复快照不重复提示，忙碌或结果未知不提示成功，离页清理提示条。`check-board-save-feedback.cjs`验证这些通知边界；真机显示仍需验证。

这是依赖活动 ArkWeb 会话的 Pinterest 网站内部资源，不是官方开放 API 或原生 OAuth。
新请求继续经 `useNativeTransport` 使用 common_network RCP 与 common_session 凭据适配。
不导入抓包中的 Cookie、CSRF、用户或图板 ID。原生传输允许 `BoardResource/update` 和 `BoardResource/delete`。

## 接口合同

- 图板详情和 Pin 分页沿用 `BoardResource/get`、`BoardFeedResource/get`，保留原有代次、地址、会话、游标、去重、刷新与迟到响应防护。
- 编辑先读取 `BoardResource/get`，`field_set_key=edit`；提交 `BoardResource/update`，包含本次图板 ID、名称、描述、privacy、首页推荐、协作者邀请和协作申请开关、`sensitivity=null`。source_url 为运行时 `/board/<id>/edit/`，handler 为 `www/board/[id]/edit.js`。成功要求 status success、code 0、endpoint_name v3_edit_board、当前图板及 owner 身份、名称与隐私匹配。改名导致 URL 改变时，只接受同源、同 owner 的二段图板地址，原生协调器同步后台路由并保留资料返回地址。
- 存档先显示原生确认页；通过 `ApiResource/create` 提交 `/v3/boards/<id>/archive/`。成功要求 status success、code 0、endpoint_name v3_archive_board。没有取消归档或删除入口。
- 更多点子通过 `BoardContentRecommendationResource/get` 读取，options 为运行时图板 id、type board、`__track__referrer=23`。推荐与收藏使用 HAR 确认的 `_tools/more-ideas/?ideas_referrer=23` source_url 和 `www/[username]/[slug]/_tools/more-ideas.js` handler。23 为入口跟踪枚举，不是账号凭据。推荐最多映射 500 个合法 Pin，本轮没有加入未经抓包确认的推荐分页。
- 加号收藏通过 `RepinResource/create` 提交推荐 Pin ID、当前图板 ID、当前会话 user_id，以及该推荐对象存在的 tracking_params。只在 status success、code 0、endpoint_name v3_repin_handler、有效副本 ID、当前图板和当前用户的 pinner、is_repin=true 后显示勾选及已收藏文案。合法返回图片映射为当前图板的新卡片；同次流程已成功收藏的条目不可重复提交。
- 已确认写入或无法确认结果后，使原生资料缓存及后台资料接口缓存失效，以便返回资料重新读取。

## 整理边界

整理第一步对齐整理点子页的三列分行布局、多选和全选；已选缩略图固定在滚动区上方，目标列表底部固定创建图板入口（本轮点击无操作）；全选只覆盖已经加载的条目。
滚动末尾沿用图板 Pin 分页，无选中项时下一步禁用。
下一步读取 `BoardsResource/get`，沿用 HAR 的 privacy_filter all、sort custom、profile_grid_item、filter_stories true、当前 owner username、page_size 25、group_by mix_public_private、include_archived true、filter_all_pins false。
source_url 为运行时 `/board/<id>/organize/repin/`，handler 为 `www/board/[id]/organize.js`；支持 bookmarks 分页、去重、同游标重试，最多显示 500 个图板。

用户补充单张和三张多选移动 HAR 并授权接入后，点击目标图板通过 ApiResource/create 提交 options.url=/v3/pins/bulk/move/、data={board_id:目标图板ID,pin_ids:当前来源图板已加载且选中的Pin ID数组}。source_url=/board/<来源图板ID>/organize/repin/，handler=www/board/[id]/organize.js。只允许当前列表中具有 write 权限、未归档且不是来源图板的目标；选中ID必须非空、无重复、最多500个，并属于当前来源列表。成功要求 status success、code 0、endpoint_name v3_move_pins、data=null；确认后关闭整理页、移除本地已移动卡片并重新读取来源图板及Pin列表，资料缓存失效。请求期间锁定提交和返回，未知结果保留选中内容并阻止重发，关闭后刷新核对。区块移动和添加区块/创建仍无操作：抓包没有提供区块字段。
返回目标列表上一层保留选中项；关闭流程、切换会话或图板清理旧请求归属和选择。

## 生命周期、验证与手动关闭

读写结果同时校验完整图板地址、session、请求 generation 和流程 epoch。关闭后不接受迟到读取。
写入期间锁定返回及提交。网络、超时、响应格式或业务字段无法确认时，不按点击推断成功、不自动重放、不显示写入重试；关闭后刷新核对。
失败不回退 DOM 或可见业务网页，不持久化账号凭据或流程数据。

`check-board-options.cjs` 覆盖单张/三张移动参数、目标权限及归档校验、重复提交锁和移动迟到响应、未知 Pin 拒绝、收藏参数及重复锁、业务响应归属、未确认结果阻止重发、编辑及迟到读取，并可传入 SDK TypeScript 路径检查原生网络许可。
`check-board-api.cjs` 覆盖既有图板读取、分页、会话及刷新。`check-board-opening.cjs` 使用当前 Store 模拟图板入口、返回和整理嵌套返回。
离线测试和无签名 HAP 不能证明 Pinterest 线上请求、写入、手机布局、安全区、滑动或深浅色验收。

本轮未修改任何 backups 快照或恢复脚本。关闭 `PIN_BOARD_API_ENABLED` 会关闭整个原生图板接口层；在当前原生登录约束下不会允许可见业务网页回退。局部撤回本轮功能需恢复本轮修改的源码，不能强制运行旧快照恢复脚本覆盖后续变更。





## 删除图板
编辑页删除入口显示系统确认弹窗；确认后使用当前会话 POST BoardResource/delete，options={board_id:当前图板ID}，source_url=/board/<id>/edit/，handler=www/board/[id]/edit.js。只有所有者、当前编辑会话且未忙碌或结果未知时提交。成功必须 status=success、code=0、endpoint_name=v3_delete_board、data=null；确认后清除Pin列表、使资料缓存失效并返回图板来源。未知结果禁止自动重发。添加合作用户仅发现读取记录，没有邀请写入合同。
