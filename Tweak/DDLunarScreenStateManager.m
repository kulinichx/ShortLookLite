#import "DDLunarScreenStateManager.h"
#import "DDLunarSystemScreenStateProvider.h"

@implementation DDLunarScreenStateManager {
	NSMutableSet *providers;
}

+ (instancetype)sharedManager {
	static DDLunarScreenStateManager *sharedManager;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedManager = [[self alloc] init];
	});
	return sharedManager;
}

- (instancetype)init {
	if ((self = [super init])) {
		providers = [NSMutableSet set];
		[self registerScreenStateProvider:[[DDLunarSystemScreenStateProvider alloc] init]];
	}
	return self;
}

- (void)registerScreenStateProvider:(NSObject<DDLunarScreenStateProvider> *)provider {
	[providers addObject:provider];
}

- (void)deregisterScreenStateProvider:(NSObject<DDLunarScreenStateProvider> *)provider {
	[providers removeObject:provider];
}

- (DDLunarScreenState)screenState {
	NSEnumerator *enumerator = [providers objectEnumerator];
	NSObject<DDLunarScreenStateProvider> *provider;
	while ((provider = [enumerator nextObject])) {
		if ([provider respondsToSelector:@selector(isScreenOn)] && ![provider isScreenOn]) {
			if ([provider respondsToSelector:@selector(isSystemScreenProvider)]) {
				return [provider isSystemScreenProvider] ? DDLunarScreenStateOff : DDLunarScreenStateOffByProvider;
			}
			return DDLunarScreenStateOffByProvider;
		}
	}
	return DDLunarScreenStateOn;
}

@end
