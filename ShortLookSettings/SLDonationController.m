#import "../FloraSettings/PSPrivate.h"
#import "../SupportShared/SLDonationRequest.h"

// This controller lives in ShortLookSettings, not in SpringBoard or the shared Flora bundle.
@interface SLDonationPreviewController : UIViewController <UIScrollViewDelegate>
@property (nonatomic, strong) UIImage *codeImage;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, assign) CGSize lastViewportSize;
@end

@interface SLDonationController : PSViewController
@property (nonatomic, strong) NSDictionary *configuration;
@property (nonatomic, strong) NSArray<NSDictionary *> *channels;
@property (nonatomic, strong) UISegmentedControl *methodControl;
@property (nonatomic, strong) UIImageView *codeImageView;
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *instructionsLabel;
@property (nonatomic, strong) UIButton *previewButton;
@property (nonatomic, strong) UIButton *shareButton;
@property (nonatomic, strong) UIButton *openAppButton;
@property (nonatomic, strong) UIImage *currentImage;
@end

static NSString *SLDonationString(id value, NSString *fallback) {
	return [value isKindOfClass:[NSString class]] && [value length] > 0 ? value : fallback;
}

static UILabel *SLDonationLabel(NSString *text, UIFontTextStyle style) {
	UILabel *label = [[UILabel alloc] init];
	label.text = text;
	label.font = [UIFont preferredFontForTextStyle:style];
	label.adjustsFontForContentSizeCategory = YES;
	label.numberOfLines = 0;
	label.textAlignment = NSTextAlignmentCenter;
	label.textColor = [UIColor labelColor];
	return label;
}

static UIButton *SLDonationButton(NSString *title, NSString *symbol, id target, SEL action) {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
	UIButtonConfiguration *configuration = [UIButtonConfiguration tintedButtonConfiguration];
	configuration.title = title;
	configuration.image = [UIImage systemImageNamed:symbol];
	configuration.imagePadding = 8;
	configuration.contentInsets = NSDirectionalEdgeInsetsMake(14, 12, 14, 12);
	configuration.titleLineBreakMode = NSLineBreakByWordWrapping;
	button.configuration = configuration;
	button.titleLabel.adjustsFontForContentSizeCategory = YES;
	[button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
	return button;
}

// Use the system share sheet; do not request Photos access or write to the photo library directly.
static void SLShareDonationImage(UIViewController *presenter, UIImage *image, id anchor) {
	if (!image || presenter.presentedViewController) return;
	UIActivityViewController *sheet = [[UIActivityViewController alloc] initWithActivityItems:@[image] applicationActivities:nil];
	UIPopoverPresentationController *popover = sheet.popoverPresentationController;
	if ([anchor isKindOfClass:[UIBarButtonItem class]]) {
		popover.barButtonItem = anchor;
	} else {
		UIView *source = [anchor isKindOfClass:[UIView class]] ? anchor : presenter.view;
		popover.sourceView = source;
		popover.sourceRect = source.bounds;
	}
	[presenter presentViewController:sheet animated:YES completion:nil];
}

@implementation SLDonationController

- (UIImage *)imageForChannel:(NSDictionary *)channel {
	NSString *name = SLDonationString(self.configuration[channel[@"imageKey"]], @"");
	// QR resources are bundle-local file names, never external paths or downloaded images.
	if (![name isEqualToString:[name lastPathComponent]]) return nil;
	NSArray *extensions = @[@"png", @"jpg", @"jpeg"];
	if (![extensions containsObject:[[name pathExtension] lowercaseString]]) return nil;
	NSBundle *bundle = [NSBundle bundleForClass:[SLDonationController class]];
	NSString *path = [bundle pathForResource:name ofType:nil];
	UIImage *image = path ? [UIImage imageWithContentsOfFile:path] : nil;
	return image.size.width > 0 && image.size.height > 0 ? image : nil;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"赞赏支持";
	self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
	NSBundle *bundle = [NSBundle bundleForClass:[SLDonationController class]];
	NSString *configurationPath = [bundle pathForResource:@"Support" ofType:@"plist"];
	self.configuration = configurationPath ? ([NSDictionary dictionaryWithContentsOfFile:configurationPath] ?: @{}) : @{};
	self.channels = @[
		@{@"title": @"微信", @"codeName": @"微信赞赏码", @"imageKey": @"WeChatQRCode", @"appURL": @"weixin://"},
		@{@"title": @"支付宝", @"codeName": @"支付宝收款码", @"imageKey": @"AlipayQRCode", @"appURL": @"alipays://"}
	];

	UIScrollView *scrollView = [[UIScrollView alloc] init];
	scrollView.translatesAutoresizingMaskIntoConstraints = NO;
	scrollView.alwaysBounceVertical = YES;
	[self.view addSubview:scrollView];
	UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
	[NSLayoutConstraint activateConstraints:@[
		[scrollView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
		[scrollView.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor],
		[scrollView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor],
		[scrollView.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor],
		[scrollView.contentLayoutGuide.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor]
	]];

	UIStackView *content = [[UIStackView alloc] init];
	content.translatesAutoresizingMaskIntoConstraints = NO;
	content.axis = UILayoutConstraintAxisVertical;
	content.spacing = 16;
	[scrollView addSubview:content];
	NSLayoutConstraint *preferredWidth = [content.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor constant:-40];
	preferredWidth.priority = UILayoutPriorityDefaultHigh;
	[NSLayoutConstraint activateConstraints:@[
		[content.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor constant:24],
		[content.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor constant:-24],
		[content.centerXAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.centerXAnchor],
		[content.widthAnchor constraintLessThanOrEqualToConstant:520], preferredWidth
	]];

	UILabel *heart = SLDonationLabel(@"♥", UIFontTextStyleLargeTitle);
	heart.textColor = [UIColor systemPinkColor];
	heart.isAccessibilityElement = NO;
	[content addArrangedSubview:heart];
	[content addArrangedSubview:SLDonationLabel(@"支持 ShortLook Reborn", UIFontTextStyleTitle2)];
	NSString *message = SLDonationString(self.configuration[@"Message"], @"如果 ShortLook Reborn 为你带来便利，欢迎自愿赞赏，支持后续适配与维护。");
	[content addArrangedSubview:SLDonationLabel(message, UIFontTextStyleBody)];

	self.methodControl = [[UISegmentedControl alloc] initWithItems:@[@"微信", @"支付宝"]];
	self.methodControl.selectedSegmentIndex = ![self imageForChannel:self.channels[0]] && [self imageForChannel:self.channels[1]] ? 1 : 0;
	self.methodControl.accessibilityLabel = @"赞赏方式";
	[self.methodControl addTarget:self action:@selector(methodChanged:) forControlEvents:UIControlEventValueChanged];
	[content addArrangedSubview:self.methodControl];

	UIView *codeArea = [[UIView alloc] init];
	UIView *codeCard = [[UIView alloc] init];
	codeCard.translatesAutoresizingMaskIntoConstraints = NO;
	codeCard.backgroundColor = [UIColor whiteColor];
	codeCard.layer.cornerRadius = 20;
	codeCard.clipsToBounds = YES;
	[codeArea addSubview:codeCard];
	NSLayoutConstraint *preferredCardWidth = [codeCard.widthAnchor constraintEqualToAnchor:codeArea.widthAnchor];
	preferredCardWidth.priority = UILayoutPriorityDefaultHigh;
	[NSLayoutConstraint activateConstraints:@[
		[codeCard.centerXAnchor constraintEqualToAnchor:codeArea.centerXAnchor],
		[codeCard.topAnchor constraintEqualToAnchor:codeArea.topAnchor],
		[codeCard.bottomAnchor constraintEqualToAnchor:codeArea.bottomAnchor],
		[codeCard.widthAnchor constraintLessThanOrEqualToConstant:340],
		[codeCard.heightAnchor constraintEqualToAnchor:codeCard.widthAnchor], preferredCardWidth
	]];
	[content addArrangedSubview:codeArea];

	self.codeImageView = [[UIImageView alloc] init];
	self.codeImageView.translatesAutoresizingMaskIntoConstraints = NO;
	self.codeImageView.contentMode = UIViewContentModeScaleAspectFit;
	self.codeImageView.isAccessibilityElement = YES;
	[codeCard addSubview:self.codeImageView];
	self.placeholderLabel = SLDonationLabel(@"", UIFontTextStyleBody);
	self.placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
	self.placeholderLabel.textColor = [UIColor darkGrayColor];
	[codeCard addSubview:self.placeholderLabel];
	[NSLayoutConstraint activateConstraints:@[
		[self.codeImageView.leadingAnchor constraintEqualToAnchor:codeCard.leadingAnchor constant:20],
		[self.codeImageView.trailingAnchor constraintEqualToAnchor:codeCard.trailingAnchor constant:-20],
		[self.codeImageView.topAnchor constraintEqualToAnchor:codeCard.topAnchor constant:20],
		[self.codeImageView.bottomAnchor constraintEqualToAnchor:codeCard.bottomAnchor constant:-20],
		[self.placeholderLabel.centerYAnchor constraintEqualToAnchor:codeCard.centerYAnchor],
		[self.placeholderLabel.leadingAnchor constraintEqualToAnchor:codeCard.leadingAnchor constant:24],
		[self.placeholderLabel.trailingAnchor constraintEqualToAnchor:codeCard.trailingAnchor constant:-24]
	]];

	self.statusLabel = SLDonationLabel(@"", UIFontTextStyleFootnote);
	self.statusLabel.textColor = [UIColor secondaryLabelColor];
	[content addArrangedSubview:self.statusLabel];
	self.previewButton = SLDonationButton(@"查看大图", @"arrow.up.left.and.arrow.down.right", self, @selector(previewCode:));
	self.shareButton = SLDonationButton(@"分享二维码", @"square.and.arrow.up", self, @selector(shareCode:));
	self.openAppButton = SLDonationButton(@"", @"arrow.up.forward.app", self, @selector(openPaymentApp:));
	[content addArrangedSubview:self.previewButton];
	[content addArrangedSubview:self.shareButton];
	[content addArrangedSubview:self.openAppButton];
	self.instructionsLabel = SLDonationLabel(@"", UIFontTextStyleFootnote);
	self.instructionsLabel.textColor = [UIColor secondaryLabelColor];
	[content addArrangedSubview:self.instructionsLabel];
	UILabel *disclaimer = SLDonationLabel(@"赞赏完全自愿，不会解锁功能，也不影响使用。请在支付应用内核对收款方和金额后自行确认；本页不读取付款结果。", UIFontTextStyleFootnote);
	disclaimer.textColor = [UIColor secondaryLabelColor];
	[content addArrangedSubview:disclaimer];
	[self updateChannel];
}

- (NSDictionary *)selectedChannel {
	NSInteger index = self.methodControl.selectedSegmentIndex;
	return self.channels[index >= 0 && index < (NSInteger)self.channels.count ? index : 0];
}

- (void)updateChannel {
	NSDictionary *channel = [self selectedChannel];
	self.currentImage = [self imageForChannel:channel];
	BOOL configured = self.currentImage != nil;
	self.codeImageView.image = self.currentImage;
	self.codeImageView.hidden = !configured;
	self.codeImageView.accessibilityLabel = channel[@"codeName"];
	self.placeholderLabel.hidden = configured;
	self.placeholderLabel.text = [NSString stringWithFormat:@"尚未配置%@\n请等待维护者更新收款资料", channel[@"codeName"]];
	NSString *recipient = SLDonationString(self.configuration[@"RecipientName"], @"");
	self.statusLabel.text = !configured ? @"当前渠道暂不可用，不会发起付款请求。" : (recipient.length ? [NSString stringWithFormat:@"收款方：%@（付款前请再次核对）", recipient] : @"付款前请在支付应用内核对收款方和金额。");
	self.previewButton.enabled = configured;
	self.shareButton.enabled = configured;
	self.openAppButton.enabled = configured;
	UIButtonConfiguration *buttonConfiguration = [self.openAppButton.configuration copy];
	BOOL wechat = [channel[@"imageKey"] isEqualToString:@"WeChatQRCode"];
	buttonConfiguration.title = wechat ? @"尝试免扫码打开微信赞赏" : @"打开支付宝";
	self.openAppButton.configuration = buttonConfiguration;
	self.instructionsLabel.text = wechat && configured ? @"点击上方按钮后，由随包微信辅助组件尝试识别赞赏码。若仅打开微信主页，请确认已允许该组件在微信中加载，并完全退出微信后重试。此功能尚需实机验证；也可使用预览和系统分享。" : configured ? [NSString stringWithFormat:@"通过系统分享菜单保存或发送二维码，再打开%@，使用“扫一扫”从相册选择；也可以用另一台设备扫码。打开应用不会自动付款。", channel[@"title"]] : @"本版本尚未提供此渠道的二维码，不会使用示例码或第三方收款信息。";
}

- (void)methodChanged:(UISegmentedControl *)sender {
	[self updateChannel];
	UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, self.statusLabel);
}

- (void)previewCode:(id)sender {
	if (!self.currentImage || self.presentedViewController) return;
	SLDonationPreviewController *preview = [[SLDonationPreviewController alloc] init];
	preview.codeImage = self.currentImage;
	preview.title = [self selectedChannel][@"codeName"];
	UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:preview];
	navigation.modalPresentationStyle = UIModalPresentationFullScreen;
	[self presentViewController:navigation animated:YES completion:nil];
}

- (void)shareCode:(id)sender {
	SLShareDonationImage(self, self.currentImage, sender);
}

- (void)openPaymentApp:(id)sender {
	if (!self.currentImage) return;
	NSDictionary *channel = [self selectedChannel];
	NSURL *url = [NSURL URLWithString:channel[@"appURL"]];
	if ([channel[@"imageKey"] isEqualToString:@"WeChatQRCode"]) {
		NSURLComponents *components = [[NSURLComponents alloc] init];
		components.scheme = SLDonationScheme;
		components.host = SLDonationHost;
		components.path = SLDonationPath;
		components.queryItems = @[
			[NSURLQueryItem queryItemWithName:@"v" value:@"1"],
			[NSURLQueryItem queryItemWithName:@"nonce" value:[NSUUID UUID].UUIDString],
			[NSURLQueryItem queryItemWithName:@"timestamp" value:[NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]]]
		];
		url = components.URL;
	}
	// The URL contains a bounded UI request only; never a payment amount or recipient payload.
	__weak SLDonationController *weakSelf = self;
	[[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
		if (success) {
			dispatch_async(dispatch_get_main_queue(), ^{
				weakSelf.statusLabel.text = @"系统已接受打开请求；这不代表微信赞赏页已经打开或付款成功。";
			});
			return;
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			SLDonationController *controller = weakSelf;
			if (!controller || !controller.view.window || controller.presentedViewController) return;
			NSString *message = [NSString stringWithFormat:@"请确认已安装%@。也可以先分享或保存二维码，再手动打开应用识别。", channel[@"title"]];
			UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法打开应用" message:message preferredStyle:UIAlertControllerStyleAlert];
			[alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:nil]];
			[controller presentViewController:alert animated:YES completion:nil];
		});
	}];
}

@end

@implementation SLDonationPreviewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(closePreview:)];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareCode:)];
	self.scrollView = [[UIScrollView alloc] init];
	self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
	self.scrollView.delegate = self;
	self.scrollView.minimumZoomScale = 1.0;
	self.scrollView.maximumZoomScale = 4.0;
	self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
	[self.view addSubview:self.scrollView];
	UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
	[NSLayoutConstraint activateConstraints:@[
		[self.scrollView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor],
		[self.scrollView.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor],
		[self.scrollView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
		[self.scrollView.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor]
	]];
	self.imageView = [[UIImageView alloc] initWithImage:self.codeImage];
	self.imageView.contentMode = UIViewContentModeScaleAspectFit;
	self.imageView.backgroundColor = [UIColor whiteColor];
	self.imageView.isAccessibilityElement = YES;
	self.imageView.accessibilityLabel = self.title;
	self.imageView.accessibilityHint = @"可双指缩放；右上角可分享二维码。";
	[self.scrollView addSubview:self.imageView];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	CGSize viewport = self.scrollView.bounds.size;
	if (CGSizeEqualToSize(viewport, self.lastViewportSize) || viewport.width <= 40 || viewport.height <= 40) return;
	self.lastViewportSize = viewport;
	self.scrollView.zoomScale = 1.0;
	CGSize imageSize = self.codeImage.size;
	if (imageSize.width <= 0 || imageSize.height <= 0) return;
	CGFloat scale = MIN((viewport.width - 40) / imageSize.width, (viewport.height - 40) / imageSize.height);
	self.imageView.frame = CGRectMake(0, 0, imageSize.width * scale, imageSize.height * scale);
	self.scrollView.contentSize = self.imageView.bounds.size;
	[self centerImage];
}

- (void)centerImage {
	CGFloat vertical = MAX((self.scrollView.bounds.size.height - self.scrollView.contentSize.height) / 2, 0);
	CGFloat horizontal = MAX((self.scrollView.bounds.size.width - self.scrollView.contentSize.width) / 2, 0);
	self.scrollView.contentInset = UIEdgeInsetsMake(vertical, horizontal, vertical, horizontal);
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
	return self.imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
	[self centerImage];
}

- (void)closePreview:(id)sender {
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)shareCode:(id)sender {
	SLShareDonationImage(self, self.codeImage, sender);
}

@end
