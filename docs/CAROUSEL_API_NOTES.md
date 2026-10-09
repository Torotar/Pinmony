# 多图详情接入

> 2026-10-03 传输调整：现有业务 API 脚本在注入时适配原生 RCP，接口参数、数据优先级、业务成功校验和禁止自动回退规则继续沿用本文；网站自身请求、认证探测与标题 HTML 读取仍由 Web 执行。原生凭据仅运行时读取，失败不自动重放。范围、手动传输回退及验收边界见 [原生网络说明](NATIVE_NETWORK_NOTES.md)。


当前 ArkWeb 会话读取完整移动端 GraphQL 查询的 carouselData.carouselSlots；先读取 Pin ID 匹配的 Relay JSON，缺失时同源请求 /_/graphql/。请求参数来自 搜索结果.har，Cookie 与 CSRF 仅取当前会话，不复制 HAR 凭据。图片项保持接口顺序和字符串 slotId，优先 images_1200x，再选 736x 等；仅接受 HTTPS pinimg 域名与有效宽高，缺失项不静默丢弃。

原生 Swiper 不循环、不自动播放，显示页码；切换 Pin 重置图片位置，图片失败可重试。详情失败走现有错误重试，不自动退回 DOM。故事页不在本次支持范围。详情缓存保留已验证轮播数据。

手动关闭 PIN_CAROUSEL_API_ENABLED 并重建可恢复多图网页查看入口。完整撤回使用 backups/carousel-before-20261001/restore.ps1，默认仅校验，-Apply 才恢复已有文件，检测后续修改则停止。

离线检查 scripts/check-carousel-api.cjs；实际网站响应、滑动手势和深浅色外观仍需设备联网验证。

2026-10-05：已验证正文先展示，轮播另显示加载或错误状态；媒体重试复用当前 Pin 元数据，不重读基础详情。读取失败不会将封面作为完整轮播，也不提供网页回退。
