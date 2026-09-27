#import <UIKit/UIKit.h>
#import "DDNotificationProtocols.h"

@interface DDNotificationViewManager : NSObject <DDNotificationViewDelegate>
+ (instancetype)sharedManager;
- (void)createViewIfDoesntExist;
- (void)destroyView:(UIView *)view;
- (void)destroyView;
- (void)prepareForPresentation;
- (void)tearDownPresentationIfNotBeingUsed;
- (void)presentNotification:(NSObject<DDNotificationDisplayable> *)notification;
- (void)presentNotification:(NSObject<DDNotificationDisplayable> *)notification indefinitely:(BOOL)indefinitely;
- (void)dismissPresentedNotificationForced:(BOOL)forced forSource:(DDNotificationDismissSource)source;
- (void)dismissPresentedNotificationForced:(BOOL)forced animationMultiplier:(double)animationMultiplier forSource:(DDNotificationDismissSource)source;
- (void)refreshDisplayedNotification;
- (void)presentWelcomeNotification;
- (BOOL)isPresenting;
- (BOOL)isPresentingNotification;
- (void)notifyPresentedNotification:(NSObject<DDNotificationDisplayable> *)notification;
- (void)notifyDismissedNotification:(NSObject<DDNotificationDisplayable> *)notification;
- (BOOL)requestShouldDismissNotification:(NSObject<DDNotificationDisplayable> *)notification forSource:(DDNotificationDismissSource)source;
- (void)prepareForDemoNotificationWithCompletion:(void (^)(void))completion;
- (void)destroyDemoNotificationPreparations;
@property (nonatomic, retain) UIView *targetView;
@property (nonatomic, retain) NSObject<DDNotificationControlSource> *controlSource;
@end
