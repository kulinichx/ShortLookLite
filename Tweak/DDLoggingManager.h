#import <Foundation/Foundation.h>

@interface DDLoggingManager : NSObject
+ (instancetype)sharedManager;
- (void)logWithString:(NSString *)string;
- (void)logWithFormatString:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);
- (NSString *)logDirectoryPath;
- (NSString *)logPath;
- (BOOL)createLogDirectory;
- (void)removeLogDirectory;
- (BOOL)loggingDirectoryExists;
@property (nonatomic, assign) BOOL writesToSyslog;
@property (nonatomic, assign) BOOL writesToFile;
@end
