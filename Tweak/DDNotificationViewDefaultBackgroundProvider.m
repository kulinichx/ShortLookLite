#import "DDNotificationViewDefaultBackgroundProvider.h"

@implementation DDNotificationViewDefaultBackgroundProvider

- (UIView *)getBackgroundViewWithFrame:(CGRect)frame {
	UIView *view = [[UIView alloc] initWithFrame:frame];
	view.backgroundColor = [UIColor blackColor];
	return view;
}

@end
