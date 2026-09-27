#import "DDNotificationContactPhotoProviderCache.h"

#define kMaximumCachedItems 50

@implementation DDNotificationContactPhotoProviderCache {
	NSMutableDictionary *cachedItems;
	NSMutableOrderedSet *recentlyAccessedKeys;
}

- (instancetype)init {
	if ((self = [super init])) {
		cachedItems = [NSMutableDictionary new];
		recentlyAccessedKeys = [NSMutableOrderedSet new];
	}
	return self;
}

- (void)addContactPhoto:(UIImage *)contactPhoto andSettings:(DDNotificationContactPhotoSettings *)settings withIdentifier:(NSString *)identifier forSenderIdentifier:(NSString *)senderIdentifier {
	NSString *key = [self cacheKeyForItemWithIdentifier:identifier forSenderIdentifier:senderIdentifier];
	cachedItems[key] = [DDNotificationContactPhotoProviderCachedItem itemWithContactPhoto:contactPhoto andSettings:settings];
	[self recordRecentAccessOfContactPhotoWithIdentifier:identifier forSenderIdentifier:senderIdentifier];
	[self evictAppropriateItems];
}

- (DDNotificationContactPhotoProviderCachedItem *)cachedItemWithIdentifier:(NSString *)identifier forSenderIdentifier:(NSString *)senderIdentifier {
	DDNotificationContactPhotoProviderCachedItem *item = cachedItems[[self cacheKeyForItemWithIdentifier:identifier forSenderIdentifier:senderIdentifier]];
	if (item) [self recordRecentAccessOfContactPhotoWithIdentifier:identifier forSenderIdentifier:senderIdentifier];
	return item;
}

- (BOOL)hasCachedItemWithIdentifier:(NSString *)identifier forSenderIdentifier:(NSString *)senderIdentifier {
	NSString *key = [self cacheKeyForItemWithIdentifier:identifier forSenderIdentifier:senderIdentifier];
	return [[cachedItems allKeys] containsObject:key];
}

- (void)clearCache {
	cachedItems = [NSMutableDictionary new];
	recentlyAccessedKeys = [NSMutableOrderedSet new];
}

- (void)evictAppropriateItems {
	if (cachedItems.count <= kMaximumCachedItems || recentlyAccessedKeys.count <= kMaximumCachedItems) return;
	NSUInteger count = recentlyAccessedKeys.count;
	NSArray *keysToEvict = [recentlyAccessedKeys objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, count - kMaximumCachedItems)]];
	for (NSString *key in keysToEvict) {
		[cachedItems removeObjectForKey:key];
	}
	[recentlyAccessedKeys removeObjectsInRange:NSMakeRange(0, count - kMaximumCachedItems)];
}

- (void)recordRecentAccessOfContactPhotoWithIdentifier:(NSString *)identifier forSenderIdentifier:(NSString *)senderIdentifier {
	NSString *key = [self cacheKeyForItemWithIdentifier:identifier forSenderIdentifier:senderIdentifier];
	if ([recentlyAccessedKeys containsObject:key]) [recentlyAccessedKeys removeObject:key];
	[recentlyAccessedKeys addObject:key];
}

- (NSString *)cacheKeyForItemWithIdentifier:(NSString *)identifier forSenderIdentifier:(NSString *)senderIdentifier {
	return [NSString stringWithFormat:@"b.%@-p.%@", identifier, senderIdentifier];
}

@end
