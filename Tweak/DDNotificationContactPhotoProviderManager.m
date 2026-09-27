#import "DDNotificationContactPhotoProviderManager.h"
#import "DDNotificationContactPhotoProviderCache.h"
#import "DDNotificationViewSettings.h"
#import "DDUserNotification.h"

@implementation DDNotificationContactPhotoProviderManager {
	NSMutableSet *globalProviders;
	NSMutableDictionary *providersByBundleIdentifier;
	DDNotificationContactPhotoProviderCache *cache;
}

+ (instancetype)sharedManager {
	static DDNotificationContactPhotoProviderManager *sharedManager;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedManager = [[self alloc] init];
	});
	return sharedManager;
}

- (instancetype)init {
	if ((self = [super init])) {
		globalProviders = [NSMutableSet set];
		providersByBundleIdentifier = [NSMutableDictionary dictionary];
		cache = [[DDNotificationContactPhotoProviderCache alloc] init];
	}
	return self;
}

- (void)registerProvider:(Class)providerClass {
	[self registerProvider:providerClass forBundleIdentifier:nil];
}

- (void)registerProvider:(Class)providerClass forBundleIdentifier:(NSString *)bundleIdentifier {
	id provider = [[providerClass alloc] init];
	if (!bundleIdentifier) {
		[globalProviders addObject:provider];
	} else {
		if (!providersByBundleIdentifier[bundleIdentifier]) providersByBundleIdentifier[bundleIdentifier] = [NSMutableSet set];
		[providersByBundleIdentifier[bundleIdentifier] addObject:provider];
	}
}

- (NSArray *)providersForNotification:(NSObject<DDNotificationDisplayable> *)notification {
	if (![DDNotificationViewSettings sharedSettings].loadContactPhotos) return @[];
	NSMutableArray *providers = [[globalProviders allObjects] mutableCopy];
	if (providersByBundleIdentifier[notification.senderIdentifier]) {
		[providers addObjectsFromArray:[providersByBundleIdentifier[notification.senderIdentifier] allObjects]];
	}
	return providers;
}

- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(NSObject<DDNotificationDisplayable> *)notification {
	for (id provider in [self providersForNotification:notification]) {
		if (![provider respondsToSelector:@selector(contactPhotoPromiseOfferForNotification:)]) continue;
		if (![provider conformsToProtocol:@protocol(DDNotificationContactPhotoProviding)]) {
			// Providers that accept any displayable notification.
			DDNotificationContactPhotoPromiseOffer *offer = [provider contactPhotoPromiseOfferForNotification:(id)notification];
			if (offer && offer.photoIdentifier) return offer;
		} else if ([notification isKindOfClass:[DDUserNotification class]]) {
			DDNotificationContactPhotoPromiseOffer *offer = [provider contactPhotoPromiseOfferForNotification:(DDUserNotification *)notification];
			if (offer && offer.photoIdentifier) return offer;
		} else if ([notification conformsToProtocol:@protocol(DDUserNotificationContactPhotoProxying)]) {
			DDUserNotification *userNotification = [(id<DDUserNotificationContactPhotoProxying>)notification userNotification];
			if (userNotification) return [self contactPhotoPromiseOfferForNotification:userNotification];
		}
	}
	return nil;
}

- (BOOL)getContactPhotoForOffer:(DDNotificationContactPhotoPromiseOffer *)offer withSenderIdentifier:(NSString *)senderIdentifier completionHandler:(void (^)(UIImage *image, DDNotificationContactPhotoSettings *settings))completionHandler {
	if ([cache hasCachedItemWithIdentifier:offer.photoIdentifier forSenderIdentifier:senderIdentifier]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			DDNotificationContactPhotoProviderCachedItem *item = [self->cache cachedItemWithIdentifier:offer.photoIdentifier forSenderIdentifier:senderIdentifier];
			completionHandler(item.contactPhoto, item.settings);
		});
		return YES;
	}
	DDNotificationContactPhotoPromise *promise = [offer generatePromise];
	if (!promise) {
		completionHandler(nil, nil);
		return NO;
	}
	__weak DDNotificationContactPhotoPromise *weakPromise = promise;
	[promise registerForUpdatesWithHandler:^(UIImage *image) {
		DDNotificationContactPhotoPromise *strongPromise = weakPromise;
		if (strongPromise.settings.usesCaching) {
			[self->cache addContactPhoto:image andSettings:strongPromise.settings withIdentifier:offer.photoIdentifier forSenderIdentifier:senderIdentifier];
		}
		completionHandler(image, strongPromise.settings);
	}];
	return YES;
}

- (NSString *)contactPhotoIdentifierForUserNotification:(DDUserNotification *)notification {
	for (id provider in [self providersForNotification:notification]) {
		if (![provider respondsToSelector:@selector(contactPhotoPromiseOfferForNotification:)]) continue;
		DDNotificationContactPhotoPromiseOffer *offer = [provider contactPhotoPromiseOfferForNotification:notification];
		if (offer) return offer.photoIdentifier;
	}
	return nil;
}

@end
