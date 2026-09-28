// Shared helpers for the reborn builds of the classic ShortLook contact photo plugins.
// Everything a plugin reads from a notification payload goes through these checks first:
// app payloads change over time, and a value of an unexpected type used to be enough to
// throw inside SpringBoard.
#import <Foundation/Foundation.h>
#import "ShortLook-API.h"

static inline id SLPayloadValue(id object, NSString *keyPath) {
	for (NSString *key in [keyPath componentsSeparatedByString:@"."]) {
		if ([object isKindOfClass:[NSArray class]]) object = [(NSArray *)object firstObject];
		if (![object isKindOfClass:[NSDictionary class]]) return nil;
		object = ((NSDictionary *)object)[key];
	}
	return object;
}

static inline NSString *SLPayloadString(id object, NSString *keyPath) {
	id value = SLPayloadValue(object, keyPath);
	if ([value isKindOfClass:[NSArray class]]) value = [(NSArray *)value firstObject];
	if ([value isKindOfClass:[NSNumber class]]) value = [(NSNumber *)value stringValue];
	if (![value isKindOfClass:[NSString class]]) return nil;
	NSString *string = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	return string.length ? string : nil;
}

static inline NSURL *SLWebURL(NSString *string) {
	if (!string) return nil;
	NSURL *url = [NSURL URLWithString:string];
	NSString *scheme = url.scheme.lowercaseString;
	if (!url.host.length || !([scheme isEqualToString:@"https"] || [scheme isEqualToString:@"http"])) return nil;
	return url;
}

static inline DDNotificationContactPhotoPromiseOffer *SLDownloadOffer(NSString *photoIdentifier, NSURL *url) {
	if (!photoIdentifier.length || !url) return nil;
	return [NSClassFromString(@"DDNotificationContactPhotoPromiseOffer") offerDownloadingPromiseWithPhotoIdentifier:photoIdentifier fromURL:url];
}
