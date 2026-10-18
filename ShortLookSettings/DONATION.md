# ShortLook 原生微信赞赏（native1）

## 用户目标

系统设置 → ShortLook → 赞赏支持 → 微信原生赞赏金额页 → 用户选择金额/其他金额 → 微信原生金额及留言页 → 用户点击赞赏 → 微信原生付款确认 → 用户自行决定支付或取消。

仅微信，使用 `DEB/我的赞赏码.jpg` 的原始图片作为内部识别资源。不展示二维码，不跳转到其他收款方，不仿造付款界面，不代点“赞赏”或“支付”。金额选项和收款信息来自用户自己的微信赞赏码，由微信呈现，不复制参考作者的姓名、头像或累计赞赏次数。若需与参考图相同六档金额，需在自己的微信赞赏码设置中配置，不能用插件伪造原生收款金额。

## 参考包只读分析

参考：`DEB/WCRefine_2.1-9_隐根.deb`。只读取归档及 Mach-O 元数据/机器码；未加载、执行或安装参考插件。

`WCRefineRootViewController -scanAppreciationQRCode` 位于参考 dylib 的 `0x1e2517c`，下一方法起点 `0x1e25958`。本分析中的地址相对于参考包内 arm64 Mach-O，不是本项目地址。

该方法解码作者内置图片，创建 `MsgImgFullScreenViewController`，调用 `animateHideViews:YES`，随后使用：

1. `ScanQRCodeLogicParams initWithCodeType:27 fromScene:2`
2. `NewQRCodeScannerParams initWithCodeType:27`
3. `ScanQRCodeLogicController initWithViewController:logicParams:`
4. `MMServiceCenter defaultCenter` → `getService:ScanQRCodeResultsMgr`
5. `setScanLogicController:`
6. `NewQRCodeScanner initWithDelegate:scannerParams:` → `scanOnePicture:`
7. 将图片上下文作为子控制器保留。

这条入口没有向赞赏页面传入自定义金额，也没有在入口中代点付款确认。ShortLook 只重写相同入口思想和自身桥接，不复制参考二进制、作者收款图片、统计或联网配置。

## 当前实现

- `SLDonationController` 仅为设置到微信的自动中转页，不再自绘金额网格。
- URI v3 只携带版本、一次性 nonce 和短时 timestamp，不携带金额/收款人/支付指令。
- helper 只注入 `com.tencent.xin`，检查微信私有类及方法签名后才调用。
- 资源按 dylib 的相对位置查找，兼容 RootHide 路径，不固定越狱根目录。
- 只有检测到 `WCPayQRCodeRewardPayerDetailViewController` 才标记已进入原生赞赏流程；URL 打开成功不代表流程成功。
- 原生流程存在时保留图片识别上下文；退出后清理，只在仍持有自己的扫描上下文时恢复先前引用。
- 不读取输入金额、留言、支付方式或支付结果；不读取支付记录，不进行网络遥测。
- 不调用 `amountBtnClick:`，不查找“赞赏/支付”按钮并发事件，不自动创建支付确认操作。
- 清除了 7 个赞赏相关文件末尾误混入的 PowerShell CLIXML。包括注入 Filter plist、资源配置和编译源码。
- 原 ShortLook 的通知、IMD、头像插件和 Flora 共用代码不在修改范围内。

## 验证与限制

测试命令：`py ShortLookSettings/tests/test_donation.py`（Windows）或 `python3 ShortLookSettings/tests/test_donation.py`（Linux/macOS）。

静态/配置检查不能证明微信私有接口在手机上可用。必须分别验证：

1. 在 RootHide 中允许微信加载随包 helper，完全退出设置与微信后重新打开。
2. 冷启动和热启动微信都能进入**用户自己的**原生赞赏金额页，而不是仅打开微信首页。
3. 六档/其他金额的显示由自己的赞赏码配置决定；选择金额后可编辑留言，核对金额和收款人。
4. 用户自己点击赞赏后出现微信原生付款确认；测试只需要取消，不需要真实支付。
5. 返回、取消、重复打开、普通微信 URL、扫一扫和原通知/头像功能无回归。

截至写入此文档，尚无本轮手机实测结论；不得将对象编译、静态检查、CI 成功或 URL 接受报告为微信原生流程已跑通。
