#import "../FloraSettings/PSPrivate.h"
#import "../SupportShared/SLDonationRequest.h"

// This is a relay/choice page, never a QR-code presentation page.
@interface SLDonationController : PSViewController
@property (nonatomic, strong) UIButton *wechatButton;
@property (nonatomic, strong) UIButton *alipayButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, assign) BOOL didDispatchAutomatically;
@property (nonatomic, assign) BOOL openingApplication;
@property (nonatomic, assign) BOOL wechatConfigured;
@end

@implementation SLDonationController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"赞赏支持";
	self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSString *configurationPath = [bundle pathForResource:@"Support" ofType:@"plist"];
	NSDictionary *configuration = configurationPath ? [NSDictionary dictionaryWithContentsOfFile:configurationPath] : nil;
	NSString *asset = configuration[@"WeChatQRCode"];
	self.wechatConfigured = [asset isKindOfClass:[NSString class]] && [asset isEqualToString:asset.lastPathComponent] && [bundle pathForResource:asset ofType:nil] != nil;

	UIStackView *stack = [[UIStackView alloc] init];
	stack.axis = UILayoutConstraintAxisVertical;
	stack.spacing = 20;
	stack.translatesAutoresizingMaskIntoConstraints = NO;
	[self.view addSubview:stack];
	[NSLayoutConstraint activateConstraints:@[
		[stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:24],
		[stack.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-24],
		[stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:32]
	]];
	UILabel *heading = [[UILabel alloc] init];
	heading.text = @"支持 ShortLook Reborn";
	heading.textAlignment = NSTextAlignmentCenter;
	heading.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle2];
	heading.adjustsFontForContentSizeCategory = YES;
	heading.numberOfLines = 0;
	heading.textColor = [UIColor labelColor];
	[stack addArrangedSubview:heading];

	self.wechatButton = [UIButton buttonWithType:UIButtonTypeSystem];
	[self.wechatButton setTitle:@"微信赞赏" forState:UIControlStateNormal];
	self.wechatButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
	self.wechatButton.titleLabel.adjustsFontForContentSizeCategory = YES;
	[self.wechatButton.heightAnchor constraintGreaterThanOrEqualToConstant:52].active = YES;
	[self.wechatButton addTarget:self action:@selector(openWeChatAppreciation:) forControlEvents:UIControlEventTouchUpInside];
	self.wechatButton.enabled = self.wechatConfigured;
	[stack addArrangedSubview:self.wechatButton];

	// No Alipay recipient has been supplied. Do not invent an operative payment entry.
	self.alipayButton = [UIButton buttonWithType:UIButtonTypeSystem];
	[self.alipayButton setTitle:@"支付宝（尚未配置）" forState:UIControlStateNormal];
	self.alipayButton.enabled = NO;
	[self.alipayButton.heightAnchor constraintGreaterThanOrEqualToConstant:48].active = YES;
	[stack addArrangedSubview:self.alipayButton];

	self.statusLabel = [[UILabel alloc] init];
	self.statusLabel.text = self.wechatConfigured ? @"将直接打开微信原生赞赏页，由微信提供金额选择和付款确认。" : @"尚未配置赞赏收款资料。";
	self.statusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
	self.statusLabel.adjustsFontForContentSizeCategory = YES;
	self.statusLabel.textColor = [UIColor secondaryLabelColor];
	self.statusLabel.textAlignment = NSTextAlignmentCenter;
	self.statusLabel.numberOfLines = 0;
	[stack addArrangedSubview:self.statusLabel];
	UILabel *footer = [[UILabel alloc] init];
	footer.text = @"赞赏完全自愿，不影响正常使用。请在微信页面核对收款方；金额和最终付款由你确认。";
	footer.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
	footer.adjustsFontForContentSizeCategory = YES;
	footer.textColor = [UIColor secondaryLabelColor];
	footer.textAlignment = NSTextAlignmentCenter;
	footer.numberOfLines = 0;
	[stack addArrangedSubview:footer];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	// The user already chose "赞赏支持". With WeChat as the only configured channel,
	// relay that explicit action immediately instead of inserting another manual step.
	if (!self.didDispatchAutomatically && self.wechatConfigured) {
		self.didDispatchAutomatically = YES;
		[self openWeChatAppreciation:nil];
	}
}

- (void)openWeChatAppreciation:(id)sender {
	if (!self.wechatConfigured || self.openingApplication) return;
	self.openingApplication = YES;
	self.wechatButton.enabled = NO;
	NSURLComponents *components = [[NSURLComponents alloc] init];
	components.scheme = SLDonationScheme;
	components.host = SLDonationHost;
	components.path = SLDonationPath;
	components.queryItems = @[
		[NSURLQueryItem queryItemWithName:@"v" value:@"1"],
		[NSURLQueryItem queryItemWithName:@"nonce" value:[NSUUID UUID].UUIDString],
		[NSURLQueryItem queryItemWithName:@"timestamp" value:[NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]]]
	];
	self.statusLabel.text = @"正在打开微信赞赏…";
	__weak SLDonationController *weakSelf = self;
	[[UIApplication sharedApplication] openURL:components.URL options:@{} completionHandler:^(BOOL opened) {
		dispatch_async(dispatch_get_main_queue(), ^{
			SLDonationController *strongSelf = weakSelf;
			if (!strongSelf) return;
			strongSelf.openingApplication = NO;
			strongSelf.wechatButton.enabled = strongSelf.wechatConfigured;
			if (opened) {
				strongSelf.statusLabel.text = @"已切换微信。赞赏金额和付款确认应由微信原生页面提供；若只到微信主页，请确认辅助组件允许在微信加载。";
			} else {
				strongSelf.statusLabel.text = @"无法打开微信，未发起赞赏。";
				UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法打开微信赞赏" message:@"请确认已安装微信。没有发起付款。" preferredStyle:UIAlertControllerStyleAlert];
				[alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
				if (!strongSelf.presentedViewController) [strongSelf presentViewController:alert animated:YES completion:nil];
			}
		});
	}];
}

@end
