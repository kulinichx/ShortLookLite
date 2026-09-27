#import "DDNotificationContactImageView.h"

@implementation DDNotificationContactImageView

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		self.translatesAutoresizingMaskIntoConstraints = NO;
		self.contentMode = UIViewContentModeScaleAspectFill;
		[self.widthAnchor constraintEqualToAnchor:self.heightAnchor].active = YES;
		self.layer.masksToBounds = YES;
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	self.layer.cornerRadius = MIN(self.bounds.size.width, self.bounds.size.height) * 0.5;
}

@end
