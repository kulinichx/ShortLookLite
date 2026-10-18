#import "SLWeChatSupportController.h"
#import "SLDonationQRCode.h"
#import <objc/runtime.h>
#import <dlfcn.h>

// 照搬 WCRefine 2.1-9 的 -[WCRefineRootViewController scanAppreciationQRCode]（反汇编 0x1e2517c）：
// 隐藏的 MsgImgFullScreenViewController 作为识图上下文 → ScanQRCodeLogicController(27, 2)
// → 交给 ScanQRCodeResultsMgr → NewQRCodeScanner scanOnePicture: → 微信自己推出原生赞赏页。
// 选金额、留言、支付全部由用户在微信原生页面操作，这里不调用任何金额/支付接口。

@protocol SLWeChatScanAPI <NSObject>
- (instancetype)initWithCodeType:(int)codeType fromScene:(int)scene;
- (instancetype)initWithCodeType:(int)codeType;
- (instancetype)initWithViewController:(UIViewController *)controller logicParams:(id)params;
- (instancetype)initWithDelegate:(id)delegate scannerParams:(id)params;
- (void)scanOnePicture:(UIImage *)image;
- (void)animateHideViews:(BOOL)hidden;
+ (id)defaultCenter;
- (id)getService:(Class)serviceClass;
- (void)setScanLogicController:(id)controller;
@end

NSBundle *SLWeChatSupportResources(void) {
	Dl_info info;
	if (!dladdr((const void *)&SLWeChatSupportResources, &info) || !info.dli_fname) return nil;
	NSString *library = [NSString stringWithUTF8String:info.dli_fname];
	for (NSUInteger i = 0; i < 3; i++) library = [library stringByDeletingLastPathComponent];
	return [NSBundle bundleWithPath:[library stringByAppendingPathComponent:@"PreferenceBundles/ShortLookSettings.bundle"]];
}
static char SLScannerKey;

static void SLShowError(UIViewController *presenter, NSString *message) {
	UIViewController *top = presenter;
	while (top.presentedViewController) top = top.presentedViewController;
	if (!top.view.window || [top isKindOfClass:[UIAlertController class]]) return;
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法打开微信赞赏" message:message preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
	[top presentViewController:alert animated:YES completion:nil];
}

void SLOpenWeChatNativeAppreciation(UIViewController *presenter) {
	if (!presenter) return;
	NSArray<NSString *> *names = @[@"MsgImgFullScreenViewController", @"ScanQRCodeLogicParams", @"NewQRCodeScannerParams",
		@"ScanQRCodeLogicController", @"MMServiceCenter", @"ScanQRCodeResultsMgr", @"NewQRCodeScanner"];
	for (NSString *name in names) {
		if (!objc_getClass(name.UTF8String)) {
			NSString *ver = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?";
			SLShowError(presenter, [NSString stringWithFormat:@"当前微信（%@）缺少 %@。", ver, name]);
			return;
		}
	}
	NSData *data = [[NSData alloc] initWithBase64EncodedString:SLDonationQRCodeBase64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
	UIImage *image = data ? [UIImage imageWithData:data] : nil;
	if (!image) { SLShowError(presenter, @"赞赏码图片加载失败。"); return; }

	@try {
		UIViewController *imageVC = [[NSClassFromString(@"MsgImgFullScreenViewController") alloc] init];
		if ([imageVC respondsToSelector:@selector(animateHideViews:)]) [(id<SLWeChatScanAPI>)imageVC animateHideViews:YES];

		id params = [(id<SLWeChatScanAPI>)[NSClassFromString(@"ScanQRCodeLogicParams") alloc] initWithCodeType:27 fromScene:2];
		id scannerParams = [(id<SLWeChatScanAPI>)[NSClassFromString(@"NewQRCodeScannerParams") alloc] initWithCodeType:27];
		id logic = [(id<SLWeChatScanAPI>)[NSClassFromString(@"ScanQRCodeLogicController") alloc] initWithViewController:imageVC logicParams:params];

		id<SLWeChatScanAPI> center = [(Class<SLWeChatScanAPI>)NSClassFromString(@"MMServiceCenter") defaultCenter];
		id manager = [center getService:NSClassFromString(@"ScanQRCodeResultsMgr")];
		if ([manager respondsToSelector:@selector(setScanLogicController:)]) [(id<SLWeChatScanAPI>)manager setScanLogicController:logic];

		id<SLWeChatScanAPI> scanner = [(id<SLWeChatScanAPI>)[NSClassFromString(@"NewQRCodeScanner") alloc] initWithDelegate:logic scannerParams:scannerParams];
		if (!imageVC || !params || !scannerParams || !logic || !scanner) {
			SLShowError(presenter, @"微信识码组件创建失败。");
			return;
		}
		// 识图期间保持 scanner 存活（随 imageVC 一起释放）
		objc_setAssociatedObject(imageVC, &SLScannerKey, scanner, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		[scanner scanOnePicture:image];

		// 与 WCRefine 相同：识图上下文挂到当前页面下（不显示），微信据此在当前导航栈推出赞赏页
		[presenter addChildViewController:imageVC];
		[imageVC didMoveToParentViewController:presenter];
	} @catch (NSException *e) {
		SLShowError(presenter, [NSString stringWithFormat:@"微信识码异常：%@", e.reason ?: e.name]);
	}
}
