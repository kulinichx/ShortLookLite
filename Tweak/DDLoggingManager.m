#import "DDLoggingManager.h"
#include <stdio.h>

@implementation DDLoggingManager {
	NSString *logPath;
}

+ (instancetype)sharedManager {
	static DDLoggingManager *sharedManager;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedManager = [[self alloc] init];
	});
	return sharedManager;
}

- (instancetype)init {
	if ((self = [super init])) {
		_writesToSyslog = YES;
	}
	return self;
}

- (void)setWritesToFile:(BOOL)writesToFile {
	_writesToFile = writesToFile;
	if (!writesToFile) {
		fclose(stderr);
		return;
	}
	if (![self createLogDirectory]) return;
	NSString *path = [self logPath];
	if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
		[[NSData data] writeToFile:path atomically:YES];
	}
	logPath = path;
}

- (void)logWithString:(NSString *)string {
	if (!_writesToFile && !_writesToSyslog) return;
	if (_writesToFile) freopen([logPath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stderr);
	NSLog(@"[%@] %@", @"ShortLook", string);
	if (_writesToFile) fclose(stderr);
}

- (void)logWithFormatString:(NSString *)format, ... {
	va_list arguments;
	va_start(arguments, format);
	NSString *string = [[NSString alloc] initWithFormat:format arguments:arguments];
	va_end(arguments);
	[self logWithString:string];
}

- (NSString *)logDirectoryPath {
	return [NSString stringWithFormat:@"/var/mobile/Dynastic/Logging/%@", @"ShortLook"];
}

- (NSString *)logPath {
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
	formatter.dateFormat = @"yyyy-MM-dd-HH:mm:ss";
	NSString *date = [formatter stringFromDate:[NSDate date]];
	return [NSString stringWithFormat:@"%@/%@-%@.log", [self logDirectoryPath], @"ShortLook", date];
}

- (BOOL)createLogDirectory {
	return [[NSFileManager defaultManager] createDirectoryAtPath:[self logDirectoryPath] withIntermediateDirectories:YES attributes:@{} error:nil];
}

- (void)removeLogDirectory {
	if ([self loggingDirectoryExists]) {
		[[NSFileManager defaultManager] removeItemAtPath:[self logDirectoryPath] error:nil];
	}
}

- (BOOL)loggingDirectoryExists {
	BOOL isDirectory = NO;
	BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:[self logDirectoryPath] isDirectory:&isDirectory];
	return exists && isDirectory;
}

@end
