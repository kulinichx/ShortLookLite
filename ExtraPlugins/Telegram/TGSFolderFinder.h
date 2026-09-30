#import <Foundation/Foundation.h>

@interface TGSFolderFinder : NSObject
+ (NSString *)findSharedFolder:(NSString *)appGroupIdentifier;
// AppGroup whose identifier contains bundleIdentifier and that holds telegram-data (third-party clients).
+ (NSString *)findTelegramFolderForBundleIdentifier:(NSString *)bundleIdentifier;
@end
