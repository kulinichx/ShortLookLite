// Telegram Contact Photos for ShortLook, by RedenticDev (1.1.0). Reborn port:
// - same lookup as the original (HD avatar from data.json, then avatar.png, then initials);
// - the file work runs inside the promise (off SpringBoard's main thread) and the AppGroup path is cached;
// - an unreadable image rejects the promise instead of handing ShortLook a nil image;
// - payload / JSON values are type-checked.
#import "SLPluginSupport.h"
#import <UIKit/UIKit.h>
#import "TGSFolderFinder.h"
#import "TGSInitialsPictureGenerator.h"

@interface NCNotificationRequest : NSObject
- (NSString *)threadIdentifier;
@end

@interface TelegramContactPhotoProvider : NSObject <DDNotificationContactPhotoProviding>
@end

static NSString *TGSString(id value) {
	return [value isKindOfClass:[NSString class]] && [(NSString *)value length] ? value : nil;
}

static UIImage *TGSPhotoForThread(NSString *threadIdentifier) {
	NSString *sharedFolder = [TGSFolderFinder findSharedFolder:@"group.ph.telegra.Telegraph"];
	if (!sharedFolder) return nil;
	NSString *conversationFolder = [NSString stringWithFormat:@"%@/telegram-data/accounts-metadata/spotlight/p:%@", sharedFolder, threadIdentifier];
	NSString *firstName = nil;
	NSString *lastName = nil;

	// HD profile picture
	NSData *jsonData = [NSData dataWithContentsOfFile:[conversationFolder stringByAppendingPathComponent:@"data.json"]];
	if (jsonData) {
		id parsed = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
		if ([parsed isKindOfClass:[NSDictionary class]]) {
			NSString *avatarSourcePath = TGSString(parsed[@"avatarSourcePath"]);
			if (avatarSourcePath) {
				UIImage *image = [UIImage imageWithContentsOfFile:[sharedFolder stringByAppendingPathComponent:avatarSourcePath]];
				if (image) return image;
			}
			firstName = TGSString(parsed[@"firstName"]);
			lastName = TGSString(parsed[@"lastName"]);
		}
	}

	// SD profile picture
	UIImage *image = [UIImage imageWithContentsOfFile:[conversationFolder stringByAppendingPathComponent:@"avatar.png"]];
	if (image) return image;

	// Initials, like Telegram does for contacts without a photo
	if (firstName) {
		return [TGSInitialsPictureGenerator generatePictureWithFirstLetter:[[firstName uppercaseString] characterAtIndex:0]
		                                                      secondLetter:lastName ? [[lastName uppercaseString] characterAtIndex:0] : '\0'];
	}
	return nil;
}

@implementation TelegramContactPhotoProvider

- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(DDUserNotification *)notification {
	NCNotificationRequest *request = notification.request;
	NSString *threadIdentifier = [request respondsToSelector:@selector(threadIdentifier)] ? TGSString([request threadIdentifier]) : nil;
	if (!threadIdentifier) return nil;
	NSString *lowercase = threadIdentifier.lowercaseString;
	// Locked app / secret chat: Telegram gives no sender info. Negative IDs are groups and bots (unsupported by the original too).
	if ([lowercase isEqualToString:@"locked"] || [lowercase isEqualToString:@"secret"] || [threadIdentifier hasPrefix:@"-"]) return nil;
	if ([threadIdentifier rangeOfString:@"/"].location != NSNotFound || [threadIdentifier rangeOfString:@".."].location != NSNotFound) return nil;

	DDNotificationContactPhotoPromiseOffer *offer = [[NSClassFromString(@"DDNotificationContactPhotoPromiseOffer") alloc] initWithPhotoIdentifier:threadIdentifier];
	[offer fulfillWithBlock:^(DDNotificationContactPhotoPromise *promise) {
		UIImage *image = TGSPhotoForThread(threadIdentifier);
		if (image) [promise resolveWithImage:image];
		else [promise reject];
	}];
	return offer;
}

@end
