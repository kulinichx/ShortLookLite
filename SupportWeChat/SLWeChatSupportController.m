#import "SLWeChatSupportController.h"
#import <objc/runtime.h>
#import <dlfcn.h>
#include <string.h>
#include <stdlib.h>

// These are invocation signatures, not implementations or links against WeChat classes.
// Every private method is checked at runtime before it is called.
@protocol SLWeChatScanAPI <NSObject>
- (instancetype)initWithCodeType:(int)codeType fromScene:(int)scene;
- (instancetype)initWithCodeType:(int)codeType;
- (instancetype)initWithViewController:(UIViewController *)controller logicParams:(id)params;
- (instancetype)initWithViewController:(UIViewController *)controller CodeType:(int)codeType;
- (instancetype)initWithDelegate:(id)delegate scannerParams:(id)params;
- (void)scanOnePicture:(UIImage *)image;
- (void)doScanQRCode:(UIImage *)image;
- (void)animateHideViews:(BOOL)hidden;
+ (id)defaultCenter;
- (id)getService:(Class)serviceClass;
- (id)scanLogicController;
- (void)setScanLogicController:(id)controller;
@end

NSBundle *SLWeChatSupportResources(void) {
	Dl_info info;
	if (!dladdr((const void *)&SLWeChatSupportResources, &info) || !info.dli_fname) return nil;
	NSString *library = [NSString stringWithUTF8String:info.dli_fname];
	for (NSUInteger i = 0; i < 3; i++) library = [library stringByDeletingLastPathComponent];
	return [NSBundle bundleWithPath:[library stringByAppendingPathComponent:@"PreferenceBundles/ShortLookSettings.bundle"]];
}

static const char *SLUnqualifiedType(const char *type) {
	while (type && *type && strchr("rnNoORV", *type)) type++;
	return type;
}

static BOOL SLCheckMethod(Class cls, SEL selector, const char *result, NSArray<NSString *> *arguments) {
	Method method = class_getInstanceMethod(cls, selector);
	if (!method || method_getNumberOfArguments(method) != arguments.count + 2) return NO;
	char type[128] = {0};
	method_getReturnType(method, type, sizeof(type));
	if (!*SLUnqualifiedType(type) || !strchr(result, *SLUnqualifiedType(type))) return NO;
	for (NSUInteger i = 0; i < arguments.count; i++) {
		method_getArgumentType(method, (unsigned int)i + 2, type, sizeof(type));
		if (!*SLUnqualifiedType(type) || !strchr(arguments[i].UTF8String, *SLUnqualifiedType(type))) return NO;
	}
	return YES;
}

// Preserve only the pre-existing scanner-controller reference, not messages or payment data.
static id SLReadCurrentScanLogic(id manager, BOOL *known) {
	*known = NO;
	if (SLCheckMethod(object_getClass(manager), @selector(scanLogicController), "@", @[])) {
		*known = YES;
		return [(id<SLWeChatScanAPI>)manager scanLogicController];
	}
	Ivar candidate = NULL;
	for (Class cls = object_getClass(manager); cls; cls = class_getSuperclass(cls)) {
		unsigned int count = 0;
		Ivar *ivars = class_copyIvarList(cls, &count);
		for (unsigned int i = 0; i < count; i++) {
			NSString *name = [[NSString stringWithUTF8String:ivar_getName(ivars[i])] lowercaseString];
			if (*ivar_getTypeEncoding(ivars[i]) == '@' && [name containsString:@"scan"] && [name containsString:@"logiccontroller"]) {
				if (candidate) { free(ivars); return nil; }
				candidate = ivars[i];
			}
		}
		free(ivars);
	}
	if (candidate) { *known = YES; return object_getIvar(manager, candidate); }
	return nil;
}

static UILabel *SLSupportText(NSString *text, UIFontTextStyle style) {
	UILabel *label = [[UILabel alloc] init];
	label.text = text;
	label.numberOfLines = 0;
	label.textAlignment = NSTextAlignmentCenter;
	label.font = [UIFont preferredFontForTextStyle:style];
	label.adjustsFontForContentSizeCategory = YES;
	return label;
}

@interface SLWeChatSupportController ()
@property (nonatomic, strong) UIImage *codeImage;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIViewController *imageContext;
@property (nonatomic, strong) id<SLWeChatScanAPI> scanLogic;
@property (nonatomic, strong) id<SLWeChatScanAPI> scanner;
@property (nonatomic, strong) id<SLWeChatScanAPI> resultsManager;
@property (nonatomic, strong) id previousScanLogic;
@property (nonatomic, assign) BOOL autoAttempted;
@end

@implementation SLWeChatSupportController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"赞赏支持";
	self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(closeSupport:)];
	NSBundle *bundle = SLWeChatSupportResources();
	NSString *configurationPath = [bundle pathForResource:@"Support" ofType:@"plist"];
	NSDictionary *configuration = configurationPath ? [NSDictionary dictionaryWithContentsOfFile:configurationPath] : nil;
	NSString *name = configuration[@"WeChatQRCode"];
	if ([name isKindOfClass:[NSString class]] && [name isEqualToString:name.lastPathComponent] && [@[@"jpg", @"jpeg", @"png"] containsObject:name.pathExtension.lowercaseString]) {
		NSString *path = [bundle pathForResource:name ofType:nil];
		if (path) self.codeImage = [UIImage imageWithContentsOfFile:path];
	}

	UIScrollView *scroll = [[UIScrollView alloc] init];
	scroll.translatesAutoresizingMaskIntoConstraints = NO;
	[self.view addSubview:scroll];
	UIStackView *stack = [[UIStackView alloc] init];
	stack.translatesAutoresizingMaskIntoConstraints = NO;
	stack.axis = UILayoutConstraintAxisVertical;
	stack.spacing = 20;
	[scroll addSubview:stack];
	[NSLayoutConstraint activateConstraints:@[
		[scroll.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
		[scroll.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
		[scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
		[scroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
		[stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:24],
		[stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-24],
		[stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:24],
		[stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24],
		[stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-48]
	]];
	[stack addArrangedSubview:SLSupportText(@"支持 ShortLook Reborn", UIFontTextStyleTitle2)];
	UIImageView *image = [[UIImageView alloc] initWithImage:self.codeImage];
	image.contentMode = UIViewContentModeScaleAspectFit;
	image.isAccessibilityElement = YES;
	image.accessibilityLabel = @"项目维护者提供的微信赞赏码";
	[image.heightAnchor constraintEqualToConstant:280].active = YES;
	[stack addArrangedSubview:image];
	self.statusLabel = SLSupportText(@"正在检查微信识码接口…", UIFontTextStyleBody);
	[stack addArrangedSubview:self.statusLabel];
	UIButton *retry = [UIButton buttonWithType:UIButtonTypeSystem];
	[retry setTitle:@"重新请求微信识别" forState:UIControlStateNormal];
	[retry addTarget:self action:@selector(startRecognition:) forControlEvents:UIControlEventTouchUpInside];
	[retry.heightAnchor constraintGreaterThanOrEqualToConstant:48].active = YES;
	[stack addArrangedSubview:retry];
	UIButton *share = [UIButton buttonWithType:UIButtonTypeSystem];
	[share setTitle:@"分享赞赏码（兼容方式）" forState:UIControlStateNormal];
	[share addTarget:self action:@selector(shareCode:) forControlEvents:UIControlEventTouchUpInside];
	share.enabled = self.codeImage != nil;
	[share.heightAnchor constraintGreaterThanOrEqualToConstant:48].active = YES;
	[stack addArrangedSubview:share];
	[stack addArrangedSubview:SLSupportText(@"赞赏完全自愿。金额选择、收款方核对和最终付款均在微信内由你完成。辅助组件不会自动付款，也不会读取付款记录。", UIFontTextStyleFootnote)];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if (!self.autoAttempted) {
		self.autoAttempted = YES;
		__weak SLWeChatSupportController *weakSelf = self;
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			if (weakSelf.view.window) [weakSelf startRecognition:nil];
		});
	}
}

- (void)restoreScanContext {
	BOOL known = NO;
	if (self.resultsManager && SLReadCurrentScanLogic(self.resultsManager, &known) == self.scanLogic && known) [self.resultsManager setScanLogicController:self.previousScanLogic];
	self.resultsManager = nil;
	self.previousScanLogic = nil;
	self.scanner = nil;
	self.scanLogic = nil;
	if (self.imageContext) {
		[self.imageContext willMoveToParentViewController:nil];
		[self.imageContext removeFromParentViewController];
		self.imageContext = nil;
	}
}

- (void)startRecognition:(id)sender {
	if (!self.codeImage) {
		self.statusLabel.text = @"无法读取随包赞赏码。请返回 ShortLook 设置，检查安装是否完整。";
		return;
	}
	if (self.navigationController.topViewController != self || self.presentedViewController) return;
	@try {
		[self restoreScanContext];
		Class logicClass = NSClassFromString(@"ScanQRCodeLogicController");
		Class paramsClass = NSClassFromString(@"ScanQRCodeLogicParams");
		Class scannerParamsClass = NSClassFromString(@"NewQRCodeScannerParams");
		Class scannerClass = NSClassFromString(@"NewQRCodeScanner");
		Class imageClass = NSClassFromString(@"MsgImgFullScreenViewController");
		Class centerClass = NSClassFromString(@"MMServiceCenter");
		Class managerClass = NSClassFromString(@"ScanQRCodeResultsMgr");
		BOOL modern = SLCheckMethod(paramsClass, @selector(initWithCodeType:fromScene:), "@", @[@"iI", @"iI"]) &&
			SLCheckMethod(scannerParamsClass, @selector(initWithCodeType:), "@", @[@"iI"]) &&
			SLCheckMethod(logicClass, @selector(initWithViewController:logicParams:), "@", @[@"@", @"@"]) &&
			SLCheckMethod(scannerClass, @selector(initWithDelegate:scannerParams:), "@", @[@"@", @"@"]) &&
			SLCheckMethod(scannerClass, @selector(scanOnePicture:), "v", @[@"@"]) &&
			SLCheckMethod(object_getClass(centerClass), @selector(defaultCenter), "@", @[]) &&
			SLCheckMethod(centerClass, @selector(getService:), "@", @[@"#@"]) &&
			SLCheckMethod(managerClass, @selector(setScanLogicController:), "v", @[@"@"]);
		BOOL legacy = SLCheckMethod(logicClass, @selector(initWithViewController:CodeType:), "@", @[@"@", @"iI"]) &&
			SLCheckMethod(logicClass, @selector(doScanQRCode:), "v", @[@"@"]);
		if (!imageClass || ![imageClass isSubclassOfClass:[UIViewController class]] || (!modern && !legacy)) {
			NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"未知";
			self.statusLabel.text = [NSString stringWithFormat:@"微信 %@ 的识码接口未通过兼容检查，已停止自动识别。可使用下方兼容方式；没有发起付款。", version];
			return;
		}
		self.imageContext = [[imageClass alloc] init];
		if (!self.imageContext) { self.statusLabel.text = @"微信未能创建识码上下文，已停止。"; return; }
		[self addChildViewController:self.imageContext];
		[self.imageContext didMoveToParentViewController:self];
		if (SLCheckMethod(imageClass, @selector(animateHideViews:), "v", @[@"Bc"])) [(id<SLWeChatScanAPI>)self.imageContext animateHideViews:YES];
		if (modern) {
			// Source/code-type observed in the supplied WCRefine reference, not a payment amount.
			id params = [(id<SLWeChatScanAPI>)[paramsClass alloc] initWithCodeType:27 fromScene:2];
			id scannerParams = [(id<SLWeChatScanAPI>)[scannerParamsClass alloc] initWithCodeType:27];
			self.scanLogic = [(id<SLWeChatScanAPI>)[logicClass alloc] initWithViewController:self.imageContext logicParams:params];
			id<SLWeChatScanAPI> center = [(Class<SLWeChatScanAPI>)centerClass defaultCenter];
			id<SLWeChatScanAPI> manager = [center getService:managerClass];
			self.scanner = [(id<SLWeChatScanAPI>)[scannerClass alloc] initWithDelegate:self.scanLogic scannerParams:scannerParams];
			if (!params || !scannerParams || !self.scanLogic || !manager || !self.scanner) {
				[self restoreScanContext]; self.statusLabel.text = @"微信识码组件未就绪，已停止。请使用兼容方式。"; return;
			}
			BOOL contextKnown = NO;
			self.previousScanLogic = SLReadCurrentScanLogic(manager, &contextKnown);
			if (!contextKnown) { [self restoreScanContext]; self.statusLabel.text = @"无法安全保存微信当前识码上下文，已停止。请使用兼容方式。"; return; }
			self.resultsManager = manager;
			[manager setScanLogicController:self.scanLogic];
			[self.scanner scanOnePicture:self.codeImage];
		} else {
			self.scanLogic = [(id<SLWeChatScanAPI>)[logicClass alloc] initWithViewController:self.imageContext CodeType:19];
			if (!self.scanLogic) { [self restoreScanContext]; self.statusLabel.text = @"微信识码组件未就绪，已停止。"; return; }
			[self.scanLogic doScanQRCode:self.codeImage];
		}
		self.statusLabel.text = @"已把随包赞赏码交给微信识别。请以微信实际显示的赞赏页面为准，并核对收款方；这不代表识别或付款已经成功。";
	} @catch (NSException *exception) {
		// Report only the exception class, never image contents, account data or payment details.
		self.statusLabel.text = [NSString stringWithFormat:@"微信识码接口出现异常（%@），已停止。请使用兼容方式。", exception.name];
		@try { [self restoreScanContext]; } @catch (NSException *ignored) { }
	}
}

- (void)shareCode:(UIButton *)sender {
	if (!self.codeImage || self.presentedViewController) return;
	UIActivityViewController *sheet = [[UIActivityViewController alloc] initWithActivityItems:@[self.codeImage] applicationActivities:nil];
	sheet.popoverPresentationController.sourceView = sender;
	sheet.popoverPresentationController.sourceRect = sender.bounds;
	[self presentViewController:sheet animated:YES completion:nil];
}

- (void)closeSupport:(id)sender {
	@try { [self restoreScanContext]; } @catch (NSException *ignored) { }
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	if (!self.navigationController || self.navigationController.isBeingDismissed || self.isMovingFromParentViewController) {
		@try { [self restoreScanContext]; } @catch (NSException *ignored) { }
	}
}

@end
