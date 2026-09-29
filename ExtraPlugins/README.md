# 其他 App 的头像插件（Reborn 版）

原版 ShortLook 时代的第三方头像插件，按 RootHide 重新编译。每个插件单独一个 deb，装哪个取决于你用哪个 App。
包名、bundle 名、类名都和原来一样，版本号后面加了 `+reborn.1`（Telegram 已到 `+reborn.2`），都依赖 ShortLook Reborn。

| 插件 | App | 头像来源 | 相比原版的修改 |
|---|---|---|---|
| Twitter | X（com.atebits.Tweetie2） | 推送里的 `users.sender.profile_image_url`，去掉 `_normal` 取大图 | 字段类型检查 |
| Instagram | com.burbn.instagram | 推送里的 `a` | 字段类型检查 |
| Discord | com.hammerandchisel.discord | 推送里的 `user_id` + `user_avatar` → cdn.discordapp.com | 原版依赖的 discord-api.dynastic.co 已停止服务（502），改为直接拼 Discord CDN 地址；没有自定义头像时用 Discord 的默认头像 |
| GitHub | com.github.stormbreaker.prod / com.github.mobile | 推送标题里的用户名 → github.com/<用户名>.png | 标题是"owner/repo"时取 owner，只接受合法的 GitHub 用户名 |
| Telegram | ph.telegra.Telegraph | Telegram 本地 AppGroup 里的 spotlight 数据（高清头像 → avatar.png → 首字母头像）；Telegram 只给「联系人」写这份数据 | AppGroup 路径缓存；读文件放到后台；读不到图片时交还 ShortLook（原版会交一张空图）；reborn.2：目录名按 Telegram 的 PeerId.toInt64()（优先取 userInfo 的 peerId，否则由 from_id 换算），修正 ID ≥ 2^32 的新账号找不到头像；诊断日志 /var/mobile/Library/Caches/ShortLook/Telegram.log |
| Pinterest | pinterest | 推送里的 `aps.alert.img` | 字段类型检查 |
| TikTok | com.zhiliaoapp.musically（国际版） | 推送里的 `attachment` | 字段类型检查 |
| YouTube | com.google.ios.youtube | 推送里的 `attachment-url-static`（显示视频缩略图，不是头像，原版就是这样） | 字段类型检查 |
| 抖音（新增，诊断版 1.0.0~diag.1） | com.ss.iphone.ugc.Aweme | 推送里的 `attachment` 或含 avatar/image/icon 等字样的图片地址 → 通知自带的会话图片；都没有交回 ShortLook | 原版没有抖音插件，这是新写的；包名 com.kokol.shortlook.plugin.contact-photo.douyin；日志 /var/mobile/Library/Caches/ShortLook/Douyin.log |

所有插件：推送字段先检查类型（字符串 / 数字 / 数组 / 字典都能安全处理），只接受 http/https 地址。原版在 App 改了推送格式时可能让 SpringBoard 抛异常。

头像能不能出来，取决于这些 App 现在的推送里还有没有上面这些字段。没有的话 ShortLook 会照常显示 App 图标，不会出错。

微信、QQ 插件在 `../Plugins/`，已经打进 ShortLook 主包，这里不重复提供（原来的 jeffresc/jerrytian 微信、QQ 包不要再装）。

## 编译
CI 会在主包之后逐个执行 `make -C ExtraPlugins/<名字> package`，deb 放在 Artifacts 的 `plugins/` 目录里。
本地：`make -C ExtraPlugins/Discord package FINALPACKAGE=1`
