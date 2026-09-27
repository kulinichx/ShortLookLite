// ShortLook Lite — 设置页
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface SLLRootListController : PSListController
@end

@implementation SLLRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)clearCache {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.kokol.shortlooklite/clearcache"), NULL, NULL, true);
}

- (void)runTest {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.kokol.shortlooklite/test"), NULL, NULL, true);
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"测试已发出"
        message:@"20 秒内：按侧键锁屏，再按一次侧键点亮屏幕，应看到全屏测试页。" preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
