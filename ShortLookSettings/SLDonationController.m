#import "../FloraSettings/PSPrivate.h"
#import "../SupportShared/SLDonationRequest.h"

// A transit controller only. WCRefine's amount/remark/payment pages belong
// to WeChat; do not recreate those pages or send an amount/payment command.
@interface SLDonationController : PSViewController
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *indicator;
@property (nonatomic, assign) BOOL requested;
@end

@implementation SLDonationController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"赞赏支持";
	self.view.backgroundColor = UIColor.systemBackgroundColor;
	UIStackView *content = [[UIStackView alloc] init];
	content.axis = UILayoutConstraintAxisVertical;
	content.alignment = UIStackViewAlignmentCenter;
	content.spacing = 18;
	content.translatesAutoresizingMaskIntoConstraints = NO;
	[self.view addSubview:content];
	[NSLayoutConstraint activateConstraints:@[
		[content.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:24],
		[content.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-24],
		[content.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor]
	]];
	self.indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
	[content addArrangedSubview:self.indicator];
	self.statusLabel = [[UILabel alloc] init];
	self.statusLabel.text = @"正在打开微信原生赞赏页…";
	self.statusLabel.textAlignment = NSTextAlignmentCenter;
	self.statusLabel.numberOfLines = 0;
	self.statusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
	self.statusLabel.adjustsFontForContentSizeCategory = YES;
	[content addArrangedSubview:self.statusLabel];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if (self.requested) return;
	self.requested = YES;
	[self.indicator startAnimating];
	NSURLComponents *components = [[NSURLComponents alloc] init];
	components.scheme = SLDonationScheme;
	components.host = SLDonationHost;
	components.path = SLDonationPath;
	components.queryItems = @[
		[NSURLQueryItem queryItemWithName:@"v" value:@"3"],
		[NSURLQueryItem queryItemWithName:@"nonce" value:NSUUID.UUID.UUIDString],
		[NSURLQueryItem queryItemWithName:@"timestamp" value:[NSString stringWithFormat:@"%.0f", NSDate.date.timeIntervalSince1970]]
	];
	__weak typeof(self) weakSelf = self;
	[[UIApplication sharedApplication] openURL:components.URL options:@{} completionHandler:^(BOOL opened) {
		dispatch_async(dispatch_get_main_queue(), ^{
			SLDonationController *strongSelf = weakSelf;
			if (!strongSelf) return;
			[strongSelf.indicator stopAnimating];
			strongSelf.statusLabel.text = opened
				? @"已向微信发送打开请求。请在微信原生赞赏页选择金额、填写留言并自行确认；不会自动付款。若仅打开微信主页，请确认已允许微信加载随包的 ShortLookSupportWeChat 组件，并彻底退出微信后重试。"
				: @"无法打开微信，未发起付款。请确认已安装微信，再返回 ShortLook 重新打开赞赏入口。";
		});
	}];
}

@end
