# 评论写入和图片体验（2026-10-04）

依据用户提供的 `帖子评论.har` 和七张界面截图。功能依赖活动 ArkWeb 的 Pinterest 网站内部同源资源，并非官方开放 API。保持 `PIN_POST_EXTENSIONS_ENABLED` 现有开关，不增加自动 DOM 回退。

## 界面

评论采用 LARGE 半模态，左侧关闭按钮与“你觉得怎么样？”标题。列表占用可用空间，输入区固定在底部；空列表文案为“写评论，分享反馈，或者击个掌开始对话”。支持文字草稿、系统图片选择器、缩略图移除、图片评论回复引用、“编辑你的评论”状态和打勾提交。本人文字评论三点显示编辑、删除；本人图片体验可删除，图片体验编辑未确认，不显示编辑操作。删除确认文案为“你确定吗？”、“此评论将被删除”、“取消”、“删除”。

## 合同

- 文字发布：`AggregatedCommentResource/create`，`force=false`、`objectId=当前聚合ID`、`pinId=当前Pin`、`tags="[]"`、`text=输入`；endpoint 为 `v3_create_aggregated_pin_data_comment`。
- 编辑：`AggregatedCommentResource/update`，当前本人 `commentId`、force、tags、text；endpoint 为 `v3_update_aggregated_comment`。
- 文字删除：`AggregatedCommentResource/delete`，本人 `commentId`；成功 endpoint 为 `v3_delete_aggregated_comment` 且 data=null。
- 图片体验回复：`DidItCommentsResource/create`，objectId 为当前图片体验ID，其余发布字段相同；endpoint 为 `v3_create_user_did_it_data_comment`。新增 `父子级回复.har` 确认普通文字评论回复使用 `AggregatedCommentReplyResource/create`，objectId为当前父评论ID，pinId为当前Pin，force=false、tags="[]"、text为输入；成功endpoint为 `v3_create_aggregated_comment_reply`。原生列表的回复入口已启用，引用与输入区复用图片回复布局。
- 图片体验点赞/取消：`ApiResource/create` 或 delete，url=`/v3/did_it/<当前体验ID>/like/`、data={}；endpoint 为 `v3_like_user_did_it_data` / `v3_unlike_user_did_it_data`、data=null；确认后重新读取，数量不按点击推断。
- 删除图片体验：`ApiResource/delete`，url=`/v3/did_it/<体验ID>/`、data.pin=当前Pin；endpoint 为 `v3_delete_user_did_it_data`，响应聚合ID必须匹配当前帖子。
- 写资源 source_url=`/pin/<当前Pin>/`、handler=`www/pin/[id].js`。读取、分页和回复首批合同沿用帖子操作说明。

## 图片上传

系统选择器选择单张图片，原生 ImagePacker 转换 JPEG 后限定最大20MiB；不持久化临时文件。common_network 使用当前会话注册 `/v3/media/uploads/register/`，type=`triedit-image`；校验 `register_media_upload` 的 upload_id、固定上传主机和签名字段。原生RCP multipart仅向 `https://pinterest-media-upload.s3.amazonaws.com/` 上传签名表单及JPEG二进制，不发送网站Cookie/CSRF。临时上传参数只留在原生内存，不通过JS Proxy或日志传递。

通过 `/v3/media/uploads/`、data.upload_ids 查询上传状态，最多15次、间隔1秒；只在 `get_media_uploads` 返回当前上传ID、type一致、status=succeeded和32位signature时继续。注册及上传不自动重放。最终创建 `/v3/did_it/`，包括details、image_signatures、当前pin、截图HAR中确认的fields子集及text_tags="[]"；验证 `v3_create_user_did_it_data`、返回Pin、图片签名和文本。图片签名是媒体标识，上传签名凭据不跨层传递。

## 状态和验证

操作绑定当前Pin、评论快照对象、原生文档epoch和完整地址。通过当前会话用户ID校验本人编辑/删除权限；忙碌时阻止重复写入。写入结果未知时保留草稿，禁止再次提交，关闭后重新读取核对；验证成功后增加mutationVersion再清草稿并刷新。上传失败不会发送创建图片评论请求。离页、登出和关闭评论使上传当前性检查失效，迟到响应不能更新另一帖子。

`check-comment-writes.cjs` 验证合同、本人权限、文字/图片/回复、重复提交、未知结果及迟到响应；`check-comment-upload.cjs` 验证上传表单、主机白名单、凭据隔离和失效检查。静态模拟及未签名HAP编译不证明真机图片选择、键盘布局、RCP上传或Pinterest线上写入正常。
