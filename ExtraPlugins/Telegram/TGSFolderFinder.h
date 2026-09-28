#import <Foundation/Foundation.h>

@interface TGSFolderFinder : NSObject
+ (NSString *)findSharedFolder:(NSString *)appGroupIdentifier;
@end
