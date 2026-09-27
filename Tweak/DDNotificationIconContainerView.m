#import "DDNotificationIconContainerView.h"
#import "DDNotificationContactPhotoSettings.h"

@implementation DDNotificationIconContainerView {
	NSLayoutConstraint *badgeViewHorizontalConstraint;
	NSLayoutConstraint *badgeViewVerticalConstraint;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		self.translatesAutoresizingMaskIntoConstraints = NO;
		self.clipsToBounds = NO;
		[self.heightAnchor constraintEqualToConstant:152].active = YES;
		[self.widthAnchor constraintEqualToAnchor:self.heightAnchor].active = YES;

		_contactImageView = [[DDNotificationContactImageView alloc] init];
		_contactImageView.alpha = 0;
		[self addSubview:_contactImageView];
		[_contactImageView.topAnchor constraintEqualToAnchor:self.topAnchor].active = YES;
		[_contactImageView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor].active = YES;
		[_contactImageView.leftAnchor constraintEqualToAnchor:self.leftAnchor].active = YES;
		[_contactImageView.rightAnchor constraintEqualToAnchor:self.rightAnchor].active = YES;

		_iconImageView = [[DDNotificationIconView alloc] init];
		[self addSubview:_iconImageView];
		[_iconImageView.heightAnchor constraintEqualToAnchor:self.heightAnchor].active = YES;
		[_iconImageView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor].active = YES;
		[_iconImageView.widthAnchor constraintEqualToAnchor:self.widthAnchor].active = YES;
		[_iconImageView.rightAnchor constraintEqualToAnchor:self.rightAnchor].active = YES;

		_badgeView = [[DDNotificationBadgeView alloc] init];
		[self addSubview:_badgeView];
		badgeViewVerticalConstraint = [_badgeView.centerYAnchor constraintEqualToAnchor:self.topAnchor constant:6];
		badgeViewHorizontalConstraint = [_badgeView.centerXAnchor constraintEqualToAnchor:self.trailingAnchor constant:-6];
		badgeViewVerticalConstraint.active = YES;
		badgeViewHorizontalConstraint.active = YES;
	}
	return self;
}

- (void)setIcon:(UIImage *)icon {
	_icon = icon;
	self.iconImageView.image = icon;
}

- (void)setUsesInnerIconAppearance:(BOOL)usesInnerIconAppearance {
	_usesInnerIconAppearance = usesInnerIconAppearance;
	self.iconImageView.usesInnerIconAppearance = usesInnerIconAppearance;
}

- (void)setContactImage:(UIImage *)contactImage withSettings:(DDNotificationContactPhotoSettings *)settings {
	if (_contactImage == contactImage) return;
	_contactImage = contactImage;
	[self setContactImage:contactImage withSettings:settings animated:NO];
}

- (void)setContactImage:(UIImage *)contactImage withSettings:(DDNotificationContactPhotoSettings *)settings animated:(BOOL)animated {
	if (![NSThread isMainThread]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self setContactImage:contactImage withSettings:settings animated:animated];
		});
	} else if (!animated) {
		[self setContactImage:contactImage withSettings:settings takingOverForAnimation:NO];
	} else {
		[UIView animateWithDuration:contactImage ? 0.4 : 0.2 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:1 options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState animations:^{
			[self setContactImage:contactImage withSettings:settings takingOverForAnimation:YES];
		} completion:^(BOOL finished) {
			if (finished) {
				self.contactImageView.image = contactImage;
				self.contactImageView.backgroundColor = settings ? settings.backgroundColor : [DDNotificationContactPhotoSettings defaultBackgroundColor];
			}
		}];
	}
}

- (void)setContactImage:(UIImage *)contactImage withSettings:(DDNotificationContactPhotoSettings *)settings takingOverForAnimation:(BOOL)takingOver {
	if (contactImage || !self.contactImageView.image) {
		self.contactImageView.image = contactImage;
		self.contactImageView.backgroundColor = settings ? settings.backgroundColor : [DDNotificationContactPhotoSettings defaultBackgroundColor];
	}
	self.contactImageView.alpha = contactImage ? 1 : 0;
	CGFloat badgeOffset = contactImage ? 20 : 6;
	badgeViewVerticalConstraint.constant = badgeOffset;
	badgeViewHorizontalConstraint.constant = -badgeOffset;
	[self layoutIfNeeded];

	CGAffineTransform transform;
	if (contactImage) {
		CGFloat scale = 0.28;
		CGAffineTransform scaled = CGAffineTransformScale(CGAffineTransformIdentity, scale, scale);
		CGSize contactSize = self.contactImageView.bounds.size;
		CGSize iconSize = self.iconImageView.bounds.size;
		transform = CGAffineTransformTranslate(scaled, contactSize.width + iconSize.width * scale, contactSize.height + iconSize.height * scale);
	} else {
		transform = CGAffineTransformIdentity;
	}
	self.iconImageView.transform = transform;
}

@end
