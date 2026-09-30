// Credit: u/Mordred666
// Source: https://reddit.com/r/jailbreakdevelopers/comments/5wb3tv/application_appgroup_path/
// Reborn: the AppGroup folder is looked up once and cached (the original scanned every
// AppGroup container on every notification).

#import "TGSFolderFinder.h"

@implementation TGSFolderFinder

+ (NSString *)findSharedFolder:(NSString *)appGroupIdentifier {
	static NSString *cachedFolder;
	static NSString *cachedIdentifier;
	@synchronized (self) {
		if (cachedFolder && [cachedIdentifier isEqualToString:appGroupIdentifier] && [[NSFileManager defaultManager] fileExistsAtPath:cachedFolder]) return cachedFolder;
		NSString *folder = [self findFolder:appGroupIdentifier inDirectory:@"/var/mobile/Containers/Shared/AppGroup/"];
		cachedFolder = folder;
		cachedIdentifier = folder ? appGroupIdentifier : nil;
		return folder;
	}
}

+ (NSString *)findFolder:(NSString *)identifier inDirectory:(NSString *)directory {
	NSFileManager *manager = [NSFileManager defaultManager];
	for (NSString *folder in [manager contentsOfDirectoryAtPath:directory error:nil]) {
		NSString *folderPath = [directory stringByAppendingPathComponent:folder];
		NSString *metadataPath = [folderPath stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
		NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
		id containerIdentifier = metadata[@"MCMMetadataIdentifier"];
		if ([containerIdentifier isKindOfClass:[NSString class]] && [[(NSString *)containerIdentifier lowercaseString] isEqualToString:identifier.lowercaseString]) {
			return folderPath;
		}
	}
	return nil;
}

+ (NSString *)findTelegramFolderForBundleIdentifier:(NSString *)bundleIdentifier {
	if (!bundleIdentifier.length) return nil;
	static NSMutableDictionary<NSString *, NSString *> *cache;
	@synchronized (self) {
		if (!cache) cache = [NSMutableDictionary dictionary];
		NSFileManager *manager = [NSFileManager defaultManager];
		NSString *cached = cache[bundleIdentifier];
		if (cached && [manager fileExistsAtPath:cached]) return cached;
		NSString *directory = @"/var/mobile/Containers/Shared/AppGroup/";
		NSString *needle = bundleIdentifier.lowercaseString;
		for (NSString *folder in [manager contentsOfDirectoryAtPath:directory error:nil]) {
			NSString *folderPath = [directory stringByAppendingPathComponent:folder];
			NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:[folderPath stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"]];
			id identifier = metadata[@"MCMMetadataIdentifier"];
			if (![identifier isKindOfClass:[NSString class]] || ![[(NSString *)identifier lowercaseString] containsString:needle]) continue;
			if (![manager fileExistsAtPath:[folderPath stringByAppendingPathComponent:@"telegram-data"]]) continue;
			cache[bundleIdentifier] = folderPath;
			return folderPath;
		}
		return nil;
	}
}

@end
