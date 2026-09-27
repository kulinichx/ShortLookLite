#import "DDInnerShadowView.h"

@implementation DDInnerShadowView {
	CALayer *shadowLayer;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		shadowLayer = [CALayer layer];
		shadowLayer.frame = self.bounds;
		shadowLayer.shadowOffset = CGSizeZero;
		shadowLayer.shadowOpacity = 1;
		shadowLayer.masksToBounds = YES;
		self.shadowColor = [UIColor blackColor];
		self.shadowSize = 5;
		[self.layer addSublayer:shadowLayer];
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	shadowLayer.shadowPath = [self shadowPath];
	shadowLayer.frame = self.bounds;
}

- (UIColor *)shadowColor {
	return [UIColor colorWithCGColor:shadowLayer.shadowColor];
}

- (void)setShadowColor:(UIColor *)shadowColor {
	shadowLayer.shadowColor = shadowColor.CGColor;
}

- (CGFloat)shadowSize {
	return shadowLayer.shadowRadius;
}

- (void)setShadowSize:(CGFloat)shadowSize {
	shadowLayer.shadowRadius = shadowSize;
	shadowLayer.shadowPath = [self shadowPath];
}

- (void)setShadowCornerRadius:(CGFloat)shadowCornerRadius {
	_shadowCornerRadius = shadowCornerRadius;
	shadowLayer.shadowPath = [self shadowPath];
}

- (CGPathRef)shadowPath {
	CGFloat inset = self.shadowSize * -3;
	UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(self.bounds, inset, inset) cornerRadius:self.shadowCornerRadius];
	UIBezierPath *innerPath = [[UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:self.shadowCornerRadius] bezierPathByReversingPath];
	[path appendPath:innerPath];
	return path.CGPath;
}

@end
