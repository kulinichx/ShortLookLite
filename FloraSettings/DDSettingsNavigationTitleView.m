#import "DDSettingsNavigationTitleView.h"

@implementation DDSettingsNavigationTitleView {
	UIStackView *titleStackView;
	UILabel *titleLabel;
	UILabel *subtitleLabel;
	UIImageView *iconImageView;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		titleLabel = [[UILabel alloc] init];
		titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
		titleLabel.numberOfLines = 1;
		titleLabel.textAlignment = NSTextAlignmentCenter;

		subtitleLabel = [[UILabel alloc] init];
		subtitleLabel.font = [UIFont systemFontOfSize:11];
		subtitleLabel.numberOfLines = 1;
		subtitleLabel.textAlignment = NSTextAlignmentCenter;

		[self setWhiteText:YES];

		titleStackView = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, subtitleLabel]];
		titleStackView.translatesAutoresizingMaskIntoConstraints = NO;
		titleStackView.axis = UILayoutConstraintAxisVertical;
		titleStackView.spacing = 1;
		[self addSubview:titleStackView];
		[titleStackView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor].active = YES;
		[titleStackView.leftAnchor constraintEqualToAnchor:self.leftAnchor].active = YES;
		[titleStackView.rightAnchor constraintEqualToAnchor:self.rightAnchor].active = YES;

		iconImageView = [[UIImageView alloc] init];
		iconImageView.translatesAutoresizingMaskIntoConstraints = NO;
		iconImageView.alpha = 0;
		[self addSubview:iconImageView];
		[iconImageView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor].active = YES;
		[iconImageView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor].active = YES;
		[iconImageView.widthAnchor constraintEqualToConstant:29].active = YES;
		[iconImageView.heightAnchor constraintEqualToConstant:29].active = YES;
	}
	return self;
}

- (void)setWhiteText:(BOOL)whiteText {
	_whiteText = whiteText;
	titleLabel.textColor = whiteText ? [UIColor whiteColor] : [UIColor blackColor];
	subtitleLabel.textColor = [UIColor colorWithWhite:(CGFloat)whiteText alpha:0.5];
}

- (void)setTitle:(NSString *)title {
	_title = title;
	titleLabel.text = self.title;
}

- (void)setSubtitle:(NSString *)subtitle {
	_subtitle = subtitle;
	subtitleLabel.text = subtitle;
	subtitleLabel.hidden = subtitle ? [subtitle isEqualToString:@""] : YES;
}

- (void)setIconImage:(UIImage *)iconImage {
	_iconImage = iconImage;
	iconImageView.image = iconImage;
}

- (void)setShowingIcon:(BOOL)showingIcon {
	_showingIcon = showingIcon;
	iconImageView.alpha = showingIcon;
	titleStackView.alpha = !showingIcon;
	iconImageView.transform = showingIcon ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0, -36);
	titleStackView.transform = !showingIcon ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0, 36);
}

- (void)setShowingIcon:(BOOL)showingIcon animated:(BOOL)animated {
	if (self.showingIcon == showingIcon) return;
	if (!animated) {
		[self setShowingIcon:showingIcon];
		return;
	}
	[UIView animateWithDuration:0.15 animations:^{
		[self setShowingIcon:showingIcon];
	}];
}

@end
