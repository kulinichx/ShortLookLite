#import <UIKit/UIKit.h>

@class DDNotificationContactPhotoPromiseOffer, DDUserNotification;

typedef NS_ENUM(long long, DDNotificationDismissSource) {
	DDNotificationDismissSourceTimer = 0,
	DDNotificationDismissSourceReplaced = 1,
	DDNotificationDismissSourceTap = 2,
	DDNotificationDismissSourceRaiseToWake = 3,
	DDNotificationDismissSourceSleep = 4,
	DDNotificationDismissSourceMenuButton = 5,
};

@protocol DDNotificationDisplayable <NSObject>
@required
- (NSString *)title;
- (NSString *)senderTitle;
- (UIImage *)icon;
- (BOOL)allowsPreciseIconTransition;
- (NSString *)senderIdentifier;
@optional
- (NSString *)subtitle;
- (NSString *)body;
- (NSString *)footnote;
- (NSString *)badge;
- (UIColor *)tintColour;
- (BOOL)allowsBodyTruncation;
@end

@protocol DDCoalescableNotification <NSObject>
@required
- (NSObject<DDNotificationDisplayable> *)coalescedNotificationWithNotification:(NSObject<DDNotificationDisplayable> *)notification;
@end

@protocol DDNotificationRefreshable <NSObject>
@required
- (NSObject<DDNotificationRefreshable> *)refreshedNotification;
@end

@protocol DDUserNotificationContactPhotoProxying <NSObject>
@required
- (DDUserNotification *)userNotification;
@end

@protocol DDLunarScreenStateProvider <NSObject>
@required
- (BOOL)isScreenOn;
@optional
- (BOOL)isSystemScreenProvider;
@end

@protocol DDNotificationAnimationProviding <NSObject>
@required
- (instancetype)initWithNotification:(NSObject<DDNotificationDisplayable> *)notification;
- (CGRect)transitionEndRect;
@optional
- (void)didStartTransition;
- (void)didFinishTransition;
- (void)animateTransitionForNotificationIconView:(UIImageView *)iconView withDuration:(NSTimeInterval)duration;
@end

@protocol DDNotificationControlSource <NSObject>
@required
- (BOOL)shouldDismissNotification:(NSObject<DDNotificationDisplayable> *)notification forSource:(DDNotificationDismissSource)source;
@optional
- (void)presentedNotification:(NSObject<DDNotificationDisplayable> *)notification;
- (void)dismissedNotification:(NSObject<DDNotificationDisplayable> *)notification;
- (BOOL)shouldAnimateBackgroundDismissForNotification:(NSObject<DDNotificationDisplayable> *)notification withSource:(DDNotificationDismissSource)source;
@end

@protocol DDNotificationContactPhotoProviding <NSObject>
@required
- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(DDUserNotification *)notification;
@end

@protocol DDNotificationDisplayableContactPhotoProviding <NSObject>
@required
- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(NSObject<DDNotificationDisplayable> *)notification;
@end

@protocol DDNotificationViewBackgroundProviding <NSObject>
@required
- (UIView *)getBackgroundViewWithFrame:(CGRect)frame;
@optional
- (void)setBackgroundViewVisible:(BOOL)visible;
@end

@protocol DDNotificationViewDelegate <NSObject>
@required
- (void)handleDestructionRequestFromNotificationView:(UIView *)notificationView;
@end
