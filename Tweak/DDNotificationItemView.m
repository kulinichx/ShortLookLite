#import "DDNotificationItemView.h"
#import "DDNotificationViewSettings.h"
#import "DDNotificationContactPhotoProviderManager.h"
#import "DDAbstractNotification.h"
#import <QuartzCore/QuartzCore.h>

@implementation DDNotificationItemView {
	UILabel *titleLabel;
	UILabel *subtitleLabel;
	UILabel *bodyLabel;
	UILabel *senderTitleLabel;
	UILabel *footnoteLabel;
	UIStackView *titleStackView;
	BOOL shouldAnimateDuringUpdate;
	NSString *prevIconID;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		shouldAnimateDuringUpdate = NO;
		self.translatesAutoresizingMaskIntoConstraints = NO;

		UIView *iconContainer = [[UIView alloc] init];
		iconContainer.hidden = [DDNotificationViewSettings sharedSettings].hideNotificationIcon;
		_iconView = [[DDNotificationIconContainerView alloc] init];
		[iconContainer addSubview:_iconView];
		[_iconView.centerXAnchor constraintEqualToAnchor:iconContainer.centerXAnchor].active = YES;
		[_iconView.topAnchor constraintEqualToAnchor:iconContainer.topAnchor].active = YES;
		[_iconView.bottomAnchor constraintEqualToAnchor:iconContainer.bottomAnchor].active = YES;
		[_iconView.leftAnchor constraintGreaterThanOrEqualToAnchor:iconContainer.leftAnchor].active = YES;
		[_iconView.rightAnchor constraintLessThanOrEqualToAnchor:iconContainer.rightAnchor].active = YES;

		titleLabel = [[UILabel alloc] init];
		titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
		titleLabel.textColor = [UIColor whiteColor];
		titleLabel.font = [DDNotificationViewSettings sharedSettings].notificationTitleFont;
		titleLabel.numberOfLines = 2;
		titleLabel.textAlignment = NSTextAlignmentCenter;

		subtitleLabel = [[UILabel alloc] init];
		subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
		subtitleLabel.textColor = [UIColor whiteColor];
		subtitleLabel.font = [DDNotificationViewSettings sharedSettings].notificationSubtitleFont;
		subtitleLabel.numberOfLines = 1;
		subtitleLabel.textAlignment = NSTextAlignmentCenter;

		bodyLabel = [[UILabel alloc] init];
		bodyLabel.translatesAutoresizingMaskIntoConstraints = NO;
		bodyLabel.textColor = [UIColor colorWithWhite:1 alpha:0.7];
		bodyLabel.font = [DDNotificationViewSettings sharedSettings].notificationBodyFont;
		bodyLabel.numberOfLines = 0;
		bodyLabel.textAlignment = NSTextAlignmentCenter;

		senderTitleLabel = [[UILabel alloc] init];
		senderTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
		senderTitleLabel.textColor = [UIColor colorWithWhite:1 alpha:0.5];
		senderTitleLabel.font = [DDNotificationViewSettings sharedSettings].notificationSenderTitleFont;
		senderTitleLabel.numberOfLines = 1;
		senderTitleLabel.textAlignment = NSTextAlignmentCenter;

		footnoteLabel = [[UILabel alloc] init];
		footnoteLabel.translatesAutoresizingMaskIntoConstraints = NO;
		footnoteLabel.textColor = [UIColor colorWithWhite:1 alpha:0.35];
		footnoteLabel.font = [DDNotificationViewSettings sharedSettings].notificationFootnoteFont;
		footnoteLabel.numberOfLines = 1;
		footnoteLabel.textAlignment = NSTextAlignmentCenter;

		UIStackView *titleSubtitleStackView = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, subtitleLabel]];
		titleSubtitleStackView.axis = UILayoutConstraintAxisVertical;
		titleSubtitleStackView.distribution = UIStackViewDistributionFill;
		titleSubtitleStackView.alignment = UIStackViewAlignmentFill;
		titleSubtitleStackView.spacing = 2;

		UIStackView *contentStackView = [[UIStackView alloc] initWithArrangedSubviews:@[titleSubtitleStackView, bodyLabel]];
		contentStackView.axis = UILayoutConstraintAxisVertical;
		contentStackView.distribution = UIStackViewDistributionFill;
		contentStackView.alignment = UIStackViewAlignmentFill;
		contentStackView.spacing = 4;

		titleStackView = [[UIStackView alloc] initWithArrangedSubviews:@[contentStackView, senderTitleLabel]];
		titleStackView.axis = UILayoutConstraintAxisVertical;
		titleStackView.distribution = UIStackViewDistributionFill;
		titleStackView.alignment = UIStackViewAlignmentFill;
		titleStackView.spacing = 8;

		UIStackView *mainStackView = [[UIStackView alloc] initWithArrangedSubviews:@[iconContainer, titleStackView, footnoteLabel]];
		mainStackView.translatesAutoresizingMaskIntoConstraints = NO;
		mainStackView.axis = UILayoutConstraintAxisVertical;
		mainStackView.distribution = UIStackViewDistributionFill;
		mainStackView.alignment = UIStackViewAlignmentFill;
		mainStackView.spacing = 12;
		[self addSubview:mainStackView];
		[mainStackView.topAnchor constraintEqualToAnchor:self.topAnchor].active = YES;
		[mainStackView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor].active = YES;
		[mainStackView.leftAnchor constraintEqualToAnchor:self.leftAnchor].active = YES;
		[mainStackView.rightAnchor constraintEqualToAnchor:self.rightAnchor].active = YES;
	}
	return self;
}

- (void)setNotification:(NSObject<DDNotificationDisplayable> *)notification {
	[self setNotification:notification animated:NO];
}

- (void)setNotification:(NSObject<DDNotificationDisplayable> *)notification animated:(BOOL)animated {
	[self setNotification:notification animated:animated bounces:YES];
}

- (CATransition *)_textTransition {
	CATransition *transition = [[CATransition alloc] init];
	transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
	transition.type = kCATransitionFade;
	transition.duration = 0.2;
	transition.removedOnCompletion = YES;
	return transition;
}

- (void)setNotification:(NSObject<DDNotificationDisplayable> *)notification animated:(BOOL)animated bounces:(BOOL)bounces {
	BOOL senderTitleTransitioned = NO;
	if (animated) {
		CATransition *transition = [self _textTransition];
		if (![[notification title] isEqualToString:[self.notification title]]) {
			[titleLabel.layer addAnimation:transition forKey:@"textTransition"];
		}
		NSString *oldFootnote = [self.notification respondsToSelector:@selector(footnote)] ? [self.notification footnote] : nil;
		NSString *newFootnote = [notification respondsToSelector:@selector(footnote)] ? [notification footnote] : nil;
		BOOL newHidesSenderTitle = newFootnote && ![notification senderTitle];
		BOOL oldHidesSenderTitle = oldFootnote && ![self.notification senderTitle];
		if (newHidesSenderTitle == oldHidesSenderTitle && [notification senderTitle] != [self.notification senderTitle]) {
			[senderTitleLabel.layer addAnimation:transition forKey:@"textTransition"];
			senderTitleTransitioned = YES;
		}
		shouldAnimateDuringUpdate = YES;
		if (bounces) [self bounce];
	}

	NSObject<DDNotificationDisplayable> *oldNotification = _notification;
	_notification = notification;

	if (!notification) {
		[_iconView setIcon:[DDNotificationViewSettings sharedSettings].defaultIconImage];
		[_iconView setContactImage:nil withSettings:nil animated:animated];
		titleLabel.text = nil;
		senderTitleLabel.text = @" ";
		senderTitleLabel.textColor = [UIColor colorWithWhite:1 alpha:0.5];
		[self changeVariableVisibilityLabel:subtitleLabel textTo:nil animated:animated];
		[self changeVariableVisibilityLabel:bodyLabel textTo:nil animated:animated];
		[self setTruncatesLongNotificationBodies:YES];
		footnoteLabel.text = nil;
		[_iconView.badgeView setText:nil animated:shouldAnimateDuringUpdate];
		prevIconID = nil;
	} else {
		[_iconView setIcon:[notification icon] ?: [DDNotificationViewSettings sharedSettings].defaultIconImage];
		if ([notification isKindOfClass:[DDAbstractNotification class]]) {
			[_iconView setUsesInnerIconAppearance:[(DDAbstractNotification *)notification application].usesInnerIconAppearance];
		} else {
			[_iconView setUsesInnerIconAppearance:NO];
		}
		[self loadContactImageForNotification:notification oldNotification:oldNotification animated:animated];
		titleLabel.text = [notification title];
		UIColor *tintColour = [notification respondsToSelector:@selector(tintColour)] ? [notification tintColour] : nil;
		senderTitleLabel.textColor = tintColour ?: [UIColor colorWithWhite:1 alpha:0.5];
		senderTitleLabel.text = [notification senderTitle] ? [[notification senderTitle] uppercaseString] : @" ";
		[self changeVariableVisibilityLabel:subtitleLabel textTo:([notification respondsToSelector:@selector(subtitle)] ? [notification subtitle] : nil) animated:animated];
		[self changeVariableVisibilityLabel:bodyLabel textTo:([notification respondsToSelector:@selector(body)] ? [notification body] : nil) animated:animated];
		[self setTruncatesLongNotificationBodies:([notification respondsToSelector:@selector(allowsBodyTruncation)] ? [notification allowsBodyTruncation] : YES)];
		NSString *footnote = nil;
		if ([notification respondsToSelector:@selector(footnote)] && [notification footnote]) footnote = [[notification footnote] uppercaseString];
		footnoteLabel.text = footnote;
		[_iconView.badgeView setText:([notification respondsToSelector:@selector(badge)] ? [notification badge] : nil) animated:shouldAnimateDuringUpdate];
	}

	if (!senderTitleTransitioned) {
		[UIView animateWithDuration:(animated ? 0.2 : 0) delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:1 options:UIViewAnimationOptionAllowUserInteraction animations:^{
			self->senderTitleLabel.hidden = ![notification senderTitle] && self->footnoteLabel.text;
		} completion:nil];
	}
	shouldAnimateDuringUpdate = NO;
}

- (void)changeVariableVisibilityLabel:(UILabel *)label textTo:(NSString *)text animated:(BOOL)animated {
	if (!animated) {
		label.hidden = !text;
		label.alpha = text ? 1 : 0;
		label.text = text;
		return;
	}
	BOOL visible = text != nil;
	if (visible == (label.text != nil)) {
		// Matches the original binary: only a fade transition is added here, the text itself is not replaced.
		CATransition *transition = [self _textTransition];
		[label.layer addAnimation:transition forKey:@"textTransition"];
		return;
	}
	label.alpha = label.text ? 1 : 0;
	if (text) label.text = text;
	[UIView animateWithDuration:0.2 delay:0 usingSpringWithDamping:1 initialSpringVelocity:1 options:UIViewAnimationOptionAllowUserInteraction animations:^{
		label.hidden = !visible;
		if (!visible) label.alpha = 0;
	} completion:^(BOOL finished) {
		if (finished && !visible) label.text = text;
	}];
	[UIView animateWithDuration:0.15 delay:0.05 options:UIViewAnimationOptionAllowUserInteraction animations:^{
		label.alpha = visible;
	} completion:nil];
}

- (void)setTruncatesLongNotificationBodies:(BOOL)truncatesLongNotificationBodies {
	_truncatesLongNotificationBodies = truncatesLongNotificationBodies;
	bodyLabel.numberOfLines = truncatesLongNotificationBodies ? 4 : 0;
}

- (void)loadContactImageForNotification:(NSObject<DDNotificationDisplayable> *)notification oldNotification:(NSObject<DDNotificationDisplayable> *)oldNotification animated:(BOOL)animated {
	CFTimeInterval startTime = CACurrentMediaTime();
	DDNotificationContactPhotoPromiseOffer *offer = [[DDNotificationContactPhotoProviderManager sharedManager] contactPhotoPromiseOfferForNotification:notification];
	__block BOOL didLoadContactPhoto = NO;
	if (offer) {
		if ([notification isKindOfClass:[DDAbstractNotification class]]) {
			DDAbstractNotification *abstractNotification = (DDAbstractNotification *)notification;
			if (offer.titleOverride) abstractNotification._titleOverride = offer.titleOverride;
			if (offer.subtitleOverride) abstractNotification._subtitleOverride = offer.subtitleOverride;
			if (offer.bodyOverride) abstractNotification._bodyOverride = offer.bodyOverride;
		}
		BOOL loading = [[DDNotificationContactPhotoProviderManager sharedManager] getContactPhotoForOffer:offer withSenderIdentifier:[notification senderIdentifier] completionHandler:^(UIImage *image, DDNotificationContactPhotoSettings *settings) {
			if (image && self.notification == notification) {
				didLoadContactPhoto = YES;
				BOOL animateImage = (CACurrentMediaTime() - startTime) > 0.15;
				if (oldNotification && animated) animateImage = YES;
				[self.iconView setContactImage:image withSettings:settings animated:animateImage];
			}
		}];
		if (loading) {
			if (didLoadContactPhoto) {
				prevIconID = offer.photoIdentifier;
				return;
			}
			if ([offer.photoIdentifier isEqualToString:prevIconID] && [[oldNotification senderIdentifier] isEqualToString:[notification senderIdentifier]]) {
				prevIconID = offer.photoIdentifier;
				return;
			}
		}
	}
	[_iconView setContactImage:nil withSettings:nil animated:animated];
	prevIconID = offer ? offer.photoIdentifier : nil;
}

- (void)bounce {
	[UIView animateKeyframesWithDuration:[DDNotificationViewSettings sharedSettings].animationDurationMultiplier * 0.2 delay:0 options:UIViewKeyframeAnimationOptionAllowUserInteraction | UIViewKeyframeAnimationOptionCalculationModePaced animations:^{
		[UIView addKeyframeWithRelativeStartTime:0 relativeDuration:[DDNotificationViewSettings sharedSettings].animationDurationMultiplier * 0.1 animations:^{
			self.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1.1, 1.1);
		}];
		[UIView addKeyframeWithRelativeStartTime:[DDNotificationViewSettings sharedSettings].animationDurationMultiplier * 0.1 relativeDuration:[DDNotificationViewSettings sharedSettings].animationDurationMultiplier * 0.1 animations:^{
			self.transform = CGAffineTransformIdentity;
		}];
	} completion:nil];
}

- (void)animateIconToFrame:(CGRect)frame inView:(UIView *)view {
	titleStackView.alpha = 0;
	titleStackView.transform = CGAffineTransformScale(CGAffineTransformIdentity, 0.75, 0.75);
	_iconView.contactImageView.alpha = 0;
	_iconView.contactImageView.transform = CGAffineTransformScale(CGAffineTransformIdentity, 0.25, 0.25);
	_iconView.badgeView.alpha = 0;
	UIImageView *iconImageView = (UIImageView *)_iconView.iconImageView;
	iconImageView.center = [view convertPoint:CGPointMake(frame.origin.x + frame.size.width * 0.5, frame.origin.y + frame.size.height * 0.5) toView:iconImageView.superview];
	iconImageView.transform = CGAffineTransformScale(CGAffineTransformIdentity, frame.size.width / iconImageView.bounds.size.width, frame.size.height / iconImageView.bounds.size.height);
}

@end
