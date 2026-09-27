# ShortLook Reborn

ShortLook 1.0.23（Dynastic）的复刻版，适配 iOS 16 和 RootHide（多巴胺隐根）。按原版二进制逐个类还原，文件名、包名、设置项都和原版一致。

- 目标设备：iPhone 14 Pro，iOS 16.6，Dopamine RootHide
- 包名：`co.dynastic.ios.tweak.shortlook`，版本 `1.0.23+reborn.1`，架构 `iphoneos-arm64e`
- 原版的 Flora 设置框架（`co.dynastic.ios.lib.flora`）合进了同一个 deb，control 里写了 Provides/Conflicts/Replaces

## 与原版的区别
- 没有特效（下雪等）和 Apple Watch 绕过，设置里对应的两组也删了。
- Flora 设置页不显示 Credits（原作者的服务器已经返回 404）。页头、导航栏和底部版权保持原样。
- 路径适配 RootHide（jbroot）。
- 同一个 deb 里带了两个联系人头像插件，走原版的插件接口，ShortLook 本体没有为它们做改动：
  - `ShortLook-WeChat.bundle`：读微信本地 `WCDB_Contact.sqlite` 里的头像 URL
  - `ShortLook-QQ.bundle`：从 qlogo 下载，个人和群都支持
- 原版行为上的一些怪癖是故意保留的，不是 bug。

## 设置（和原版相同）
- 启用
- 外观：显示联系人头像、半透明背景
- 显示通知内容
- 超时：时长
- 动作：抬起唤醒时关闭、未查看则恢复休眠
- 发送测试通知
- 高级：隐藏图标和头像、调试日志

## 目录
| 路径 | 内容 |
|---|---|
| `Tweak/` | ShortLook.dylib（SpringBoard） |
| `IMD/` | ShortLookIMD.dylib（IMDPersistenceAgent，给短信通知补联系人 ID） |
| `FloraSettings/` | Flora 设置框架（FloraSettings.bundle） |
| `ShortLookSettings/` | 设置页 plist 和图标（ShortLookSettings.bundle） |
| `Plugins/` | 微信、QQ 头像插件 |
| `layout/` | 原版素材、PreferenceLoader 入口、postinst/postrm |
| `.github/workflows/build.yml` | 自动编译 |

## 编译
推送到 `main` 分支后，GitHub Actions 会用 roothide/theos 和 iPhoneOS16.5.sdk 自动编译。deb 在 Actions 运行页面底部的 Artifacts 里。

本地编译要先装好 roothide Theos，然后执行：
```
make package FINALPACKAGE=1
```
