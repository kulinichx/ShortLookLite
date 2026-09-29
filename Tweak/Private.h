// SpringBoard / UserNotifications private interfaces used by ShortLook.
#import <UIKit/UIKit.h>
#import <Contacts/Contacts.h>
#import <UserNotifications/UserNotifications.h>
#if __has_include(<roothide.h>)
#import <roothide.h>
#else
// Rootless (official Theos): THEOS_PACKAGE_INSTALL_PREFIX is "/var/jb"; rootful: "".
#ifndef THEOS_PACKAGE_INSTALL_PREFIX
#define THEOS_PACKAGE_INSTALL_PREFIX ""
#endif
#define jbroot(path) ([@THEOS_PACKAGE_INSTALL_PREFIX stringByAppendingString:(path)])
#endif
#import "NSObject+SafeKVC.h"
#import "UIFont+SystemCompact.h"

@interface NCNotificationOptions : NSObject
@property (nonatomic, readonly) BOOL suppressesTitleWhenLocked;
@property (nonatomic, readonly) BOOL suppressesSubtitleWhenLocked;
@property (nonatomic, readonly) BOOL suppressesBodyWhenLocked;
@property (nonatomic, readonly) BOOL canTurnOnDisplay;
@end

@interface NCNotificationContent : NSObject
@property (nonatomic, copy, readonly) NSString *header;
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) NSString *subtitle;
@property (nonatomic, copy, readonly) NSString *message;
@property (nonatomic, readonly) UIImage *icon;
@property (nonatomic, readonly) NSArray *icons;
@property (nonatomic, readonly) UIImage *attachmentImage;
@end

@interface NCNotificationRequest : NSObject
@property (nonatomic, copy, readonly) NSString *sectionIdentifier;
@property (nonatomic, readonly) NCNotificationContent *content;
@property (nonatomic, readonly) NCNotificationOptions *options;
@property (nonatomic, readonly) NSDictionary *sourceInfo;
@property (nonatomic, readonly) UNNotification *userNotification;
@property (nonatomic, readonly) NSString *contactIdentifier;
@property (nonatomic, readonly) NSArray *peopleIdentifiers;
+ (instancetype)notificationRequestWithSectionId:(NSString *)sectionId notificationId:(NSString *)notificationId threadId:(NSString *)threadId title:(NSString *)title message:(NSString *)message timestamp:(NSDate *)timestamp destinations:(NSSet *)destinations;
+ (instancetype)notificationRequestWithAlertItem:(id)alertItem;
@end


@interface SBApplication : NSObject
@property (nonatomic, readonly) NSString *bundleIdentifier;
@property (nonatomic, readonly) NSString *displayName;
@end

@interface SBApplicationController : NSObject
+ (instancetype)sharedInstance;
- (SBApplication *)applicationWithBundleIdentifier:(NSString *)bundleIdentifier;
- (NSArray *)allBundleIdentifiers;
+ (NSArray *)alwaysAvailableApplicationBundle;
@end

@interface UIImage (DDPrivate)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier format:(int)format scale:(CGFloat)scale;
@end


@interface UIScreen (DDPrivate)
@property (nonatomic, readonly) CGFloat _displayCornerRadius;
@end

@interface _UIBackdropView : UIView
- (instancetype)initWithPrivateStyle:(NSInteger)style;
- (void)transitionToPrivateStyle:(NSInteger)style;
@end

@interface SBFUserAuthenticationController : NSObject
- (BOOL)_isUserAuthenticated;
@end

@interface SBDashBoardViewController : UIViewController
@property (nonatomic, readonly) id mainPageContentViewController;
- (BOOL)hasContentAboveDashBoard;
- (BOOL)hasContentAboveCoverSheet;
- (BOOL)isMainPageVisible;
@end

@interface SBAlertItem : NSObject
- (UIImage *)_iconImage;
@end

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
@property (nonatomic, readonly) BOOL isLockScreenVisible;
- (BOOL)_isPasscodeVisible;
- (SBFUserAuthenticationController *)_userAuthController;
- (SBDashBoardViewController *)dashBoardViewController;
- (SBDashBoardViewController *)coverSheetViewController;
- (void)lockUIFromSource:(int)source withOptions:(NSDictionary *)options completion:(id)completion;
- (void)unlockUIFromSource:(int)source withOptions:(NSDictionary *)options;
- (void)_activateLockScreenAnimated:(BOOL)animated animationProvider:(id)provider automatically:(BOOL)automatically inScreenOffMode:(BOOL)screenOff dismissNotificationCenter:(BOOL)dismissNC completion:(id)completion;
- (void)_activateLockScreenAnimated:(BOOL)animated animationProvider:(id)provider automatically:(BOOL)automatically inScreenOffMode:(BOOL)screenOff dimInAnimation:(BOOL)dim dismissNotificationCenter:(BOOL)dismissNC completion:(id)completion;
@end

@interface SBScreenWakeAnimationController : NSObject
+ (instancetype)sharedInstance;
- (void)sleepForSource:(long long)source completion:(void (^)(void))completion;
@end

@interface NCNotificationDispatcher : NSObject
- (void)postNotificationWithRequest:(NCNotificationRequest *)request;
- (void)withdrawNotificationWithRequest:(NCNotificationRequest *)request;
@end

@interface SBNCNotificationDispatcher : NSObject
@property (nonatomic, retain) NCNotificationDispatcher *dispatcher;
@end

@interface SpringBoard : UIApplication
@property (nonatomic, readonly) SBNCNotificationDispatcher *notificationDispatcher;
@end

@interface SBNCScreenController : NSObject
- (BOOL)canTurnOnScreenForNotificationRequest:(NCNotificationRequest *)request;
@end

@interface SBNCAlertingController : NSObject
- (SBNCScreenController *)screenController;
@end

@interface NCNotificationListCell : UIView
@property (nonatomic, readonly) id contentViewController;
@end

@interface NCNotificationShortLookView : UIView
@property (nonatomic, readonly) UIButton *iconButton;
@property (nonatomic, readonly) NSArray *iconButtons;
@end

@interface NCNotificationListViewController : UICollectionViewController
- (NSIndexPath *)indexPathForNotificationRequest:(NCNotificationRequest *)request;
@end

@interface NCNotificationListCache : NSObject
- (id)listCellForNotificationRequest:(NCNotificationRequest *)request viewControllerDelegate:(id)delegate createNewIfNecessary:(BOOL)create shouldConfigure:(BOOL)configure;
@end

@interface NCNotificationMasterList : NSObject
@property (nonatomic, readonly) NCNotificationListCache *notificationListCache;
@end

@interface NCNotificationStructuredListViewController : UIViewController
@property (nonatomic, readonly) NCNotificationMasterList *masterList;
@end

@interface CNContactStore (DDPrivate)
- (id)_ios_meContactWithKeysToFetch:(NSArray *)keys error:(NSError **)error;
@end

@interface CNPhoneNumber (DDPrivate)
- (NSString *)unformattedInternationalStringValue;
@end

@interface CSMainPageContentViewController : UIViewController
@property (nonatomic, readonly) id combinedListViewController;
@end
