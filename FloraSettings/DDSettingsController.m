#import "DDSettingsController.h"

@implementation DDSettingsController {
	UILabel *titleLabel;
	NSLayoutConstraint *headerContentsViewCenterConstraint;
	NSLayoutConstraint *headerViewTopConstraint;
	NSLayoutConstraint *headerViewHeightConstraint;
	BOOL themeNavigationBar;
	BOOL hasAppeared;
	NSString *companyName;
	BOOL showsDynasticBranding;
	NSInteger firstCopyrightYear;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	[self setExtendedLayoutIncludesOpaqueBars:YES];
	[self table].contentInset = UIEdgeInsetsMake(135, 0, 0, 0);
	UIEdgeInsets inset;
	if (@available(iOS 11, *)) {
		inset = [self table].adjustedContentInset;
	} else {
		inset = [self table].contentInset;
	}
	[self table].contentOffset = CGPointMake(-inset.left, -inset.top);
	[self table].keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;

	companyName = @"Dynastic";
	showsDynasticBranding = YES;
	firstCopyrightYear = 2016;
	NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:[[self preferencesBundle] pathForResource:[self tweakName] ofType:@"plist"]];
	if (plist) {
		if (plist[@"showsDynasticBranding"]) showsDynasticBranding = [plist[@"showsDynasticBranding"] boolValue];
		if (plist[@"companyName"]) companyName = [plist[@"companyName"] stringValue];
		if (plist[@"firstCopyrightYear"]) firstCopyrightYear = [plist[@"firstCopyrightYear"] integerValue];
	}
	themeNavigationBar = self.splitViewController == nil;

	self.titleView = [[DDSettingsNavigationTitleView alloc] initWithFrame:CGRectMake(0, 0, 200, 32)];
	self.titleView.title = [self tweakName];
	self.titleView.subtitle = [NSString stringWithFormat:@"Version %@", [self tweakVersion]];
	self.titleView.iconImage = [self tweakIcon];
	self.titleView.showingIcon = YES;
	self.navigationItem.titleView = self.titleView;

	if (showsDynasticBranding) {
		UIBarButtonItem *logoItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"NavLogo" inBundle:[self bundle] compatibleWithTraitCollection:nil] style:UIBarButtonItemStylePlain target:self action:@selector(openDynasticWebsite:)];
		self.navigationItem.rightBarButtonItem = logoItem;
	}

	self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 170)];
	self.headerView.translatesAutoresizingMaskIntoConstraints = NO;
	self.headerView.userInteractionEnabled = NO;
	self.headerView.preservesSuperviewLayoutMargins = YES;

	UIView *headerContentsView = [[UIView alloc] initWithFrame:self.headerView.bounds];
	headerContentsView.backgroundColor = self.headerColour;
	headerContentsView.preservesSuperviewLayoutMargins = YES;
	headerContentsView.translatesAutoresizingMaskIntoConstraints = NO;
	[self.headerView addSubview:headerContentsView];
	[headerContentsView.heightAnchor constraintEqualToAnchor:self.headerView.heightAnchor].active = YES;
	[headerContentsView.topAnchor constraintEqualToAnchor:self.headerView.topAnchor].active = YES;
	[headerContentsView.bottomAnchor constraintEqualToAnchor:self.headerView.bottomAnchor].active = YES;
	[headerContentsView.leftAnchor constraintEqualToAnchor:self.headerView.leftAnchor].active = YES;
	[headerContentsView.rightAnchor constraintEqualToAnchor:self.headerView.rightAnchor].active = YES;

	UILabel *companyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	companyLabel.text = companyName;
	companyLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
	companyLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.7];
	companyLabel.numberOfLines = 1;
	companyLabel.adjustsFontSizeToFitWidth = YES;
	companyLabel.minimumScaleFactor = (CGFloat)0.8333333134651184;
	companyLabel.clipsToBounds = YES;

	titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	NSMutableAttributedString *titleText = [[NSMutableAttributedString alloc] initWithString:[self tweakName] attributes:@{
		NSForegroundColorAttributeName: [UIColor whiteColor],
		NSFontAttributeName: [UIFont systemFontOfSize:36 weight:UIFontWeightMedium]
	}];
	NSAttributedString *versionText = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" v%@", [self tweakVersion]] attributes:@{
		NSForegroundColorAttributeName: [UIColor colorWithWhite:1.0 alpha:0.5],
		NSFontAttributeName: [UIFont systemFontOfSize:22 weight:UIFontWeightMedium]
	}];
	[titleText appendAttributedString:versionText];
	titleLabel.attributedText = titleText;
	titleLabel.numberOfLines = 1;
	titleLabel.adjustsFontSizeToFitWidth = YES;
	titleLabel.minimumScaleFactor = (CGFloat)0.8333333134651184;
	titleLabel.clipsToBounds = YES;

	UIStackView *stackView = [[UIStackView alloc] initWithArrangedSubviews:@[companyLabel, titleLabel]];
	stackView.translatesAutoresizingMaskIntoConstraints = NO;
	stackView.axis = UILayoutConstraintAxisVertical;
	stackView.spacing = 8;
	[headerContentsView addSubview:stackView];
	headerContentsViewCenterConstraint = [stackView.centerYAnchor constraintEqualToAnchor:headerContentsView.centerYAnchor];
	headerContentsViewCenterConstraint.active = YES;
	[stackView.leftAnchor constraintEqualToAnchor:headerContentsView.layoutMarginsGuide.leftAnchor].active = YES;
	[stackView.rightAnchor constraintEqualToAnchor:headerContentsView.layoutMarginsGuide.rightAnchor].active = YES;

	[self.view addSubview:self.headerView];
	[self.headerView.leftAnchor constraintEqualToAnchor:self.view.leftAnchor].active = YES;
	[self.headerView.rightAnchor constraintEqualToAnchor:self.view.rightAnchor].active = YES;
	headerViewHeightConstraint = [self.headerView.heightAnchor constraintEqualToConstant:170];
	headerViewHeightConstraint.active = YES;
	headerViewTopConstraint = [self.headerView.topAnchor constraintEqualToAnchor:self.topLayoutGuide.bottomAnchor];
	headerViewTopConstraint.active = YES;

	[self adjustForNavigationBarMode];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
	[super traitCollectionDidChange:previousTraitCollection];
	[self adjustForNavigationBarMode];
}

- (void)adjustForNavigationBarMode {
	themeNavigationBar = self.traitCollection.horizontalSizeClass != UIUserInterfaceSizeClassRegular;
	[self.titleView setWhiteText:themeNavigationBar];
	headerContentsViewCenterConstraint.constant = themeNavigationBar ? -6 : 0;
	[self setThemedStatusBar:themeNavigationBar];
	[self setNavbarEffectActive:themeNavigationBar];
}

- (void)setThemedStatusBar:(BOOL)themedStatusBar {
	_themedStatusBar = themedStatusBar;
	[[UIApplication sharedApplication] setStatusBarStyle:themedStatusBar ? UIStatusBarStyleLightContent : self.originalStatusBarStyle];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if (!self.themedStatusBar) {
		self.originalStatusBarStyle = [[UIApplication sharedApplication] statusBarStyle];
	}
	[self setNavbarEffectActive:themeNavigationBar];
	[self setThemedStatusBar:themeNavigationBar];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	hasAppeared = YES;
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self setNavbarEffectActive:NO];
	[self setThemedStatusBar:NO];
}

- (void)_loadSpecifiers {
	[super _loadSpecifiers];
	[_specifiers insertObject:[PSSpecifier emptyGroupSpecifier] atIndex:0];
	// Credits group intentionally hidden in this rebuild (the credits server no longer exists).
	[self setTitle:[self tweakName]];
}

- (void)openDynasticWebsite:(id)sender {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://dynastic.co/?src=twkprefsnav"]];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section < [self numberOfSectionsInTableView:tableView] - 1) {
		return [super tableView:tableView titleForFooterInSection:section];
	}
	return [self copyrightText];
}

- (void)setNavbarEffectActive:(BOOL)active {
	if (self._navbarEffectActive == active) return;
	self._navbarEffectActive = active;
	UINavigationBar *navigationBar = self.navigationController.navigationController.navigationBar;
	if (active) {
		navigationBar.barTintColor = self.headerColour;
		navigationBar.tintColor = [UIColor whiteColor];
		navigationBar.barStyle = UIBarStyleBlackTranslucent;
		navigationBar.translucent = NO;
		navigationBar.shadowImage = [UIImage new];
	} else {
		navigationBar.barTintColor = [UINavigationBar appearance].barTintColor;
		navigationBar.tintColor = [UINavigationBar appearance].tintColor;
		navigationBar.barStyle = [UINavigationBar appearance].barStyle;
		navigationBar.translucent = YES;
		navigationBar.shadowImage = [UINavigationBar appearance].shadowImage;
	}
}

- (void)didScroll {
	UITableView *table = [self table];
	CGFloat topInset = table.contentInset.top;
	if (@available(iOS 11, *)) {
		topInset = table.adjustedContentInset.top;
	}
	headerViewHeightConstraint.constant = 170 - fmin(topInset + table.contentOffset.y, 0);
	headerViewTopConstraint.constant = -fmax(topInset + table.contentOffset.y, 0);
	CGFloat indicatorTop = fmax(170 - table.contentOffset.y - topInset, 0);
	UIEdgeInsets indicatorInsets = table.scrollIndicatorInsets;
	table.scrollIndicatorInsets = UIEdgeInsetsMake(indicatorTop, indicatorInsets.left, indicatorInsets.bottom, indicatorInsets.right);
	CGFloat titleMaxY = CGRectGetMaxY([titleLabel convertRect:titleLabel.bounds toView:self.headerView]);
	BOOL showingIcon = titleLabel ? (topInset + table.contentOffset.y <= titleMaxY) : YES;
	[self.titleView setShowingIcon:showingIcon animated:hasAppeared];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	[self didScroll];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	[self didScroll];
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView {
	[self didScroll];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
	[self didScroll];
}

- (NSString *)copyrightText {
	return [NSString stringWithFormat:@"© %@ %@", companyName, [self copyrightYearText]];
}

- (NSString *)copyrightYearText {
	NSInteger year = [[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian] component:NSCalendarUnitYear fromDate:[NSDate date]];
	if (firstCopyrightYear < year) {
		return [NSString stringWithFormat:@"%ld-%ld", (long)firstCopyrightYear, (long)year];
	}
	return [[NSNumber numberWithDouble:fmin((double)year, (double)firstCopyrightYear)] stringValue];
}

- (void)notificationButtonPerformedAction:(PSSpecifier *)specifier {
	NSString *name = specifier.properties[@"PostNotification"];
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)name, NULL, NULL, YES);
}

@end
