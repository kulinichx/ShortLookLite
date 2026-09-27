# ShortLook Lite

锁屏通知全屏大头像，是 ShortLook 的精简重写版。适用于 iOS 16 和 RootHide（多巴胺隐根）。

- 目标设备：iPhone 14 Pro，iOS 16.6，Dopamine RootHide
- 包名：`com.kokol.shortlooklite`，架构 `iphoneos-arm64e`

## 功能（0.1.0）
- 手机锁屏时来通知，且系统点亮了屏幕，就显示一屏黑底，中间是大圆头像、名字和消息，右下角是 App 小图标，顶部显示时间。
- 头像来源，按顺序尝试：
  1. 微信：读本地 `WCDB_Contact.sqlite`，取出头像 URL 后下载原图，缓存 3 天。
  2. QQ：从 qlogo 下载头像，个人和群都支持。
  3. 通讯录：用于短信、电话和 iOS 通讯类通知。
  4. 通知里自带的发送者图片。
  5. 以上都没有时，用 App 图标。
- 省电：插件不会主动点亮屏幕，也不会让屏幕多亮一会儿。屏幕熄灭或回到全天候显示（AOD）时，这一屏立即关闭。
- 以下情况也会关闭：解锁、点击、滑动，或者到了设定的秒数。
- 连续来多条通知时，只显示最新的一条。
- 消息内容可以设为「跟随系统显示预览」「总是显示」或「不显示」。系统预览设为「解锁时」的话，Face ID 认出你之前只显示头像和名字。
- 屏幕最下面 110pt 不拦截触摸，系统上滑解锁照常能用。

## 设置
在「设置 → ShortLook Lite」里可以调：
- 启用
- 显示时长：随屏幕 / 5 / 10 / 20 秒
- 消息内容
- 是否在顶部显示时间
- 发送测试
- 清除头像缓存
- 调试日志

## 调试日志
日志文件是 `/var/mobile/Library/Caches/ShortLookLite/sll.log`，可以用 Filza 打开。0.1 版会记录以下内容，方便实机排查：
- 每条通知的 userInfo 键名，以及微信 `u`、QQ `r` 字段的值
- 屏幕状态（BacklightServices 读数、hasBlankedScreen）
- 头像的来源和下载结果
- 开机 8 秒后，相关私有类里的方法名（诊断用）

## 编译
推送到 `main` 分支后，GitHub Actions 会用 roothide/theos 和 iPhoneOS16.5.sdk 自动编译。编译好的 deb 在 Actions 运行页面底部的 Artifacts 里。

本地编译要先装好 roothide Theos，然后执行：
```
make package FINALPACKAGE=1
```

## 目录
| 路径 | 内容 |
|---|---|
| `Tweak.x` | 钩子、显示逻辑、设置读取 |
| `Sources/SLLUtil.m` | 日志、安全取值、屏幕和锁屏状态 |
| `Sources/SLLAvatar.m` | 头像来源（微信、QQ、通讯录）和缓存 |
| `Sources/SLLOverlayView.m` | 全屏界面 |
| `Prefs/` | 设置页 |
| `.github/workflows/build.yml` | 自动编译 |

## 已知待实机确认
- 微信 `u`、QQ `r` 在 iOS 16 通知里的实际位置。代码会从多个位置合并读取，日志里能看到具体在哪。
- 在 AOD 下，屏幕状态能否可靠区分出来。优先读 BacklightServices，读不到时退回 hasBlankedScreen。
- 专注模式静音的通知：如果你正看着亮着的锁屏时收到，也会弹出这一屏。
