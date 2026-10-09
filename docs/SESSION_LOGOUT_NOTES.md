# 原生退出账号

用户提供的 `登录.har` 捕获一次 `POST /resource/UserSessionResource/delete/`，HTTP 200，`resource_response.status=success`、`http_status=200`、`data.success=true`。表单包含 `source_url=/settings/` 与 `data={options:{disable_auth_failure_redirect:true},context:{}}`，handler 为 `www/settings.js`。这是活动网站会话中的内部资源，不是官方开放 API。HAR 和其中的账户、凭据及安全校验字段不存入项目。

设置根页点击“退出账号”先展示系统确认弹窗；取消不发请求，确认且仍属于当前设置根页/请求代次才通过原生 RCP 发起该已确认请求。当前 Cookie/CSRF 来自 common_session 的逐请求适配，沿用完整属性同步响应 Cookie、关闭自动重定向、文档 epoch 与地址校验。原生传输仅放行这一种 UserSessionResource 写合同，不开放登录 create、读取 get、其他选项或其他来源路径。

操作期间禁止重复点击和关闭设置；结果未确认时保留当前登录状态、显示真实失败入口，不自动重放。仅 HTTP 200 不代表成功，必须同时校验上述业务字段；迟到响应不得退出后来建立的会话。抓包中的 client_context 仍标记已登录，因此不能把该字段当作退出结果。业务成功后清理根页、详情、面板与旧请求，禁用文档保留、清理 Web 历史，进入真实登录页。进入登录文档前，旧网页认证和导航回调不能恢复已退出状态。不删除或复制 ArkWeb 自身凭据，不自动提交密码。

`feature_settings/src/main/ets/services/PinWebLogout.ets` 中 `PIN_LOGOUT_API_ENABLED=false` 可手动关闭本入口；保留按钮且点击无操作，不自动退回 DOM。现有受保护备份不修改，也不强制覆盖后续源代码。

`check-logout-api.cjs` 验证参数白名单、重复点击、业务确认、失败保留、迟到响应、开关与禁止重放；`check-session-startup.cjs` 覆盖旧认证回调不能撤销已确认退出。离线检查与 HAP 编译不代表设备上的 Cookie 会话失效或网站登录次数限制已解除。真机需单次执行设置退出，检查登录页、返回不能恢复旧账号、关闭重开仍按当前网站会话，以及退出失败保留状态。加载速度测试无需反复退出并登录。
