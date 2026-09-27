#import "DDNotificationIconView.h"
#import "DDNotificationViewSettings.h"

@implementation DDNotificationIconView {
	CALayer *iconMask;
	UIImage *_savedImage;
	UIImageView *innerIconView;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		self.translatesAutoresizingMaskIntoConstraints = NO;
		[self.widthAnchor constraintEqualToAnchor:self.heightAnchor].active = YES;
		[self setUsesInnerIconAppearance:NO];
		UIImage *maskImage = [DDNotificationViewSettings sharedSettings].iconMaskImage;
		if (maskImage) {
			iconMask = [CALayer layer];
			iconMask.contents = (__bridge id)maskImage.CGImage;
			iconMask.frame = self.bounds;
			self.layer.mask = iconMask;
			self.layer.masksToBounds = YES;
		}
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	iconMask.frame = self.bounds;
}

- (void)setUsesInnerIconAppearance:(BOOL)usesInnerIconAppearance {
	_usesInnerIconAppearance = usesInnerIconAppearance;
	self.backgroundColor = usesInnerIconAppearance ? [UIColor colorWithWhite:1 alpha:0.1] : [UIColor clearColor];
	self.contentMode = usesInnerIconAppearance ? UIViewContentModeScaleAspectFit : UIViewContentModeScaleAspectFill;
	[self populateImage];
}

- (void)setImage:(UIImage *)image {
	_savedImage = image;
	[self populateImage];
}

- (void)populateImage {
	[super setImage:_usesInnerIconAppearance ? nil : _savedImage];
	innerIconView.image = _usesInnerIconAppearance ? [_savedImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] : nil;
}

@end
