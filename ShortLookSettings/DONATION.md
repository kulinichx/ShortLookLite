# 赞赏支持（实验性免扫码桥接）

用户于 2026-10-18 确认原生双渠道设置页，并明确允许随包新增微信侧辅助组件。微信素材来自用户的 `DEB/我的赞赏码.jpg`；保持原始字节，SHA-256：`1e7bd3830378d49b22c8023d055b3e54601ec2a7b267eb3f7b4f511ed250fd4a`。

## 使用与范围

- ShortLook 设置底部 → 赞赏支持 → 微信 →「尝试免扫码打开微信赞赏」。
- 随包的 `ShortLookSupportWeChat.dylib` 只过滤主微信 `com.tencent.xin`，不注入扩展，不依赖 WCRefine，不改变通知与头像逻辑。
- 安装后完全退出并重新打开微信；越狱环境若对微信禁用了插件注入，需要允许此组件加载。
- URL 只携带固定主机、版本、UUID 和 60 秒有效时间戳。不携带任意图片路径、收款人、金额、回调或执行命令；校验来源应用（若系统提供）、拒绝重复 nonce，普通微信 URL 继续原有处理。
- 微信侧从已安装的 ShortLookSettings bundle 读取随包图片，检查私有接口签名后再请求微信识别。私有接口缺失／签名改变／无法保存原识码上下文时明确停止，不把打开微信主页当作直达成功。
- 现代路径参考 supplied WCRefine 静态调用：ScanQRCodeLogicParams(27,2)、NewQRCodeScannerParams(27)、ScanQRCodeLogicController、ScanQRCodeResultsMgr、NewQRCodeScanner.scanOnePicture:。保留并在退出时尽力恢复原识码控制器。旧接口只在签名匹配时使用。
- 不钩金额选择、付款确认或付款结果，不自动选额／支付，不读取联系人、消息、账户或付款记录，不添加支付 SDK、远端收款配置或分析上报。
- 金额、留言、收款方核对和最终支付均由微信页面及用户完成。
- 图片预览、缩放和系统分享是明确标注的兼容方式。不直接请求相册权限或写相册。

## 当前验证边界

这是 `1.0.25~support1+reborn` 测试版本。静态检查／编译／链接不等同于设备验证。免扫码路线仍需在目标微信版本、RootHide 注入配置及冷启动／热启动场景实机测试；不存在“所有微信版本已兼容”的保证。若失败，报告微信版本和界面错误，不需要提供密码、付款码或交易记录。

## 收款资料

`Resources/Support.plist` 管理收款方展示名、说明和 bundle 根目录图片文件名。微信已使用真实赞赏码 `SupportWeChat.jpg`；支付宝尚无素材，因此渠道清楚显示未配置并禁用操作，不使用假码。后续接入 `SupportAlipay.png`，重新编译。不要把付款码、密码或令牌放入资源。

## 验证与回退

```bash
python -m unittest discover -s ShortLookSettings/tests -v
clang -std=c11 -Wall -Wextra -Werror ShortLookSettings/tests/test_request.c -lm -o /tmp/shortlook-request-test
/tmp/shortlook-request-test
make package FINALPACKAGE=1
```

正式 arm64e RootHide ABI 及签名打包沿用项目现有 Actions/Theos；Linux 手工链接仅作检查，不作为发布产物。保留已有 DEB 文件。回退时重装之前的主包，并完全退出微信以卸载旧进程内组件。

实机验收：冷／热启动直达、原生选额／取消／返回、二维码收款方一致、微信普通 URL 不受影响、二维码分享与预览、原有通知／头像无回归。没有实机证据前，不把“系统已接受 URL”或“已请求识码”写成支付成功。
