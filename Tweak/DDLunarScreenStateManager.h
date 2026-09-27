#import "DDNotificationProtocols.h"

typedef NS_ENUM(NSUInteger, DDLunarScreenState) {
	DDLunarScreenStateOff = 0,
	DDLunarScreenStateOffByProvider = 1,
	DDLunarScreenStateOn = 2,
};

@interface DDLunarScreenStateManager : NSObject
+ (instancetype)sharedManager;
- (void)registerScreenStateProvider:(NSObject<DDLunarScreenStateProvider> *)provider;
- (void)deregisterScreenStateProvider:(NSObject<DDLunarScreenStateProvider> *)provider;
- (DDLunarScreenState)screenState;
@end
