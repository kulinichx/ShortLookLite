# 直接进入微信原生赞赏

## 需求与修正

用户要求参照 WCRefine：点击赞赏入口，直接进入微信原生赞赏金额页，再由微信处理留言及最终付款确认。**不展示二维码，不要求用户保存、分享或手动识别图片。** support1 采用二维码主页面，不符合此要求；support2 已删除该主流程。

正确素材仍是用户的 `DEB/我的赞赏码.jpg`，随包保存为 `SupportWeChat.jpg`，只供微信内部识别，绝不作为赞赏界面展示。原始字节 SHA-256：`1e7bd3830378d49b22c8023d055b3e54601ec2a7b267eb3f7b4f511ed250fd4a`。

## 主流程

1. 系统设置 → ShortLook → 微信赞赏。此功能仅有微信入口，明确点击后立即转至微信，无渠道选择或其他占位。
2. 随包的微信辅助组件只处理专用、限时且去重的打开请求，来源应用若系统提供则校验为设置；常规微信 URL 原样继续处理。
3. 组件在微信**现有导航栈**创建内部识别上下文，按参考包实际调用的现代接口准备逻辑参数和识别器，并将随包素材交给微信。
4. 下一个赞赏相关可见页面由微信自己提供：原生金额页、留言和支付确认。组件不创建自己的二维码页或支付页。
5. 接口不支持或超时，明确弹出错误并结束；不会改成二维码、分享或打开首页来冒充直达成功。

## 参考调用与边界

静态参考链：`MsgImgFullScreenViewController` → `ScanQRCodeLogicParams(27,2)` / `NewQRCodeScannerParams(27)` → `ScanQRCodeLogicController initWithViewController:logicParams:` → `MMServiceCenter` / `ScanQRCodeResultsMgr setScanLogicController:` → `NewQRCodeScanner initWithDelegate:logic scannerParams:` → `scanOnePicture:`。原始参考 deb 只读，在内存中做静态分析，未执行其中代码。

内部图像上下文是原生识别所需对象，其 view 不加入界面、不被 present。辅助组件仅有 NSObject 会话对象、短暂加载指示和失败提示，不再包一层自定义赞赏导航页。用实际出现的 `WCPayQRCodeRewardPayerDetailViewController` 判断原生页面入口，URL 被系统接受或图片已提交都不算进入成功。

私有方法先检查签名。此前额外加入的“必须读到原识码 getter 才能调用”门槛已删除：尽力保存旧上下文，仅当可读回且仍是本次控制器时恢复，不覆盖微信后续新建的识码上下文。没有旧版猜测路径或二维码兜底。

只向主微信 `com.tencent.xin` 注入，不改变通知、头像、共享 Flora，不依赖安装 WCRefine，不钩金额选择、付款确认、交易结果、联系人或消息。不自动选择金额或付款，不读交易记录，不引入支付 SDK、远端收款配置或跟踪代码。

## 安装与验证

当前包版本 `1.0.25~support3+reborn`，RootHide／隐根目标。安装后完全退出重开微信；若对微信禁用注入，需要允许此辅助组件加载。本功能仅支持微信，不保留其他收款渠道的入口、配置或占位。

```bash
python -m unittest discover -s ShortLookSettings/tests -v
clang -std=c11 -Wall -Wextra -Werror ShortLookSettings/tests/test_request.c -lm -o /tmp/shortlook-request-test
/tmp/shortlook-request-test
make package FINALPACKAGE=1
```

编译检查不替代实机：需确认点入口后进入正确收款方的原生金额页，冷／热启动、选额／取消／返回及原通知／头像无回归。验证页面入口不需要实际付款。若失败，反馈微信版本和错误提示，不提供密码、付款码或交易记录。回退可重装保留的旧包，再完全退出微信。
