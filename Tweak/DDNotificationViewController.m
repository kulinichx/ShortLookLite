#import "DDNotificationViewController.h"

@implementation DDNotificationViewController

- (void)loadView {
	self.view = [[DDNotificationView alloc] init];
}

- (DDNotificationView *)notificationView {
	return (DDNotificationView *)self.view;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	if ([[UIDevice currentDevice] respondsToSelector:@selector(userInterfaceIdiom)] && [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
		return UIInterfaceOrientationMaskAll;
	}
	return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)_canShowWhileLocked {
	return YES;
}

@end
