#import "SLDiag.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *const kSLDiagDirectory = @"/var/mobile/Library/Caches/ShortLook";

static dispatch_queue_t SLDiagQueue(void) {
	static dispatch_queue_t queue;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		queue = dispatch_queue_create("co.dynastic.ios.tweak.shortlook.diag", DISPATCH_QUEUE_SERIAL);
	});
	return queue;
}

void SLDiagLog(NSString *format, ...) {
	va_list arguments;
	va_start(arguments, format);
	NSString *message = [[NSString alloc] initWithFormat:format arguments:arguments];
	va_end(arguments);
	NSLog(@"[ShortLook] %@", message);
	NSDate *date = [NSDate date];
	dispatch_async(SLDiagQueue(), ^{
		static NSDateFormatter *formatter;
		if (!formatter) {
			formatter = [[NSDateFormatter alloc] init];
			formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
			formatter.dateFormat = @"MM-dd HH:mm:ss.SSS";
		}
		NSFileManager *fileManager = [NSFileManager defaultManager];
		[fileManager createDirectoryAtPath:kSLDiagDirectory withIntermediateDirectories:YES attributes:nil error:nil];
		NSString *path = [kSLDiagDirectory stringByAppendingPathComponent:@"debug.log"];
		NSDictionary *attributes = [fileManager attributesOfItemAtPath:path error:nil];
		if (attributes && attributes.fileSize > 2 * 1024 * 1024) [fileManager removeItemAtPath:path error:nil];
		NSString *line = [NSString stringWithFormat:@"%@ %@\n", [formatter stringFromDate:date], message];
		FILE *file = fopen(path.fileSystemRepresentation, "a");
		if (!file) return;
		fputs(line.UTF8String, file);
		fclose(file);
	});
}

static void SLDiagCheck(NSString *className, NSString *selectorName, BOOL isClassMethod) {
	Class cls = NSClassFromString(className);
	if (!cls) {
		SLDiagLog(@"  [类不存在] %@", className);
		return;
	}
	SEL selector = NSSelectorFromString(selectorName);
	BOOL exists = isClassMethod ? class_getClassMethod(cls, selector) != NULL : class_getInstanceMethod(cls, selector) != NULL;
	SLDiagLog(@"  [%@] %@%@ %@", exists ? @"有" : @"无", isClassMethod ? @"+" : @"-", className, selectorName);
}

static void SLDiagListMethods(NSString *className, NSString *filter) {
	Class cls = NSClassFromString(className);
	if (!cls) {
		SLDiagLog(@"  方法表 %@：类不存在", className);
		return;
	}
	NSRegularExpression *regex = filter ? [NSRegularExpression regularExpressionWithPattern:filter options:NSRegularExpressionCaseInsensitive error:nil] : nil;
	NSMutableArray *names = [NSMutableArray array];
	for (int pass = 0; pass < 2; pass++) {
		Class target = pass == 0 ? cls : object_getClass(cls);
		unsigned int count = 0;
		Method *methods = class_copyMethodList(target, &count);
		for (unsigned int i = 0; i < count; i++) {
			NSString *name = NSStringFromSelector(method_getName(methods[i]));
			if (regex && ![regex firstMatchInString:name options:0 range:NSMakeRange(0, name.length)]) continue;
			[names addObject:[(pass == 0 ? @"-" : @"+") stringByAppendingString:name]];
		}
		free(methods);
	}
	[names sortUsingSelector:@selector(compare:)];
	SLDiagLog(@"  方法表 %@（%lu 个%@）：%@", className, (unsigned long)names.count, filter ? [NSString stringWithFormat:@"，筛选 %@", filter] : @"", [names componentsJoinedByString:@" "]);
}

static void SLDiagListIvars(NSString *className, NSString *filter) {
	Class cls = NSClassFromString(className);
	if (!cls) return;
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:filter options:NSRegularExpressionCaseInsensitive error:nil];
	NSMutableArray *names = [NSMutableArray array];
	unsigned int count = 0;
	Ivar *ivars = class_copyIvarList(cls, &count);
	for (unsigned int i = 0; i < count; i++) {
		NSString *name = [NSString stringWithUTF8String:ivar_getName(ivars[i]) ?: ""];
		if ([regex firstMatchInString:name options:0 range:NSMakeRange(0, name.length)]) [names addObject:name];
	}
	free(ivars);
	SLDiagLog(@"  成员变量 %@（筛选 %@）：%@", className, filter, [names componentsJoinedByString:@" "]);
}

void SLDiagDumpRuntime(void) {
	SLDiagLog(@"==== 运行时检查（iOS %@）====", [UIDevice currentDevice].systemVersion);
	SLDiagLog(@"原版钩子和调用的方法：");
	SLDiagCheck(@"SBNCAlertingController", @"_alertNowForNotificationRequest:", NO);
	SLDiagCheck(@"SBNCAlertingController", @"screenController", NO);
	SLDiagCheck(@"SBNCScreenController", @"canTurnOnScreenForNotificationRequest:", NO);
	SLDiagCheck(@"SBScreenWakeAnimationController", @"_runCompletionHandlerForWake:", NO);
	SLDiagCheck(@"SBScreenWakeAnimationController", @"_runCompletionHandlerForWake:reason:", NO);
	SLDiagCheck(@"SBScreenWakeAnimationController", @"sharedInstance", YES);
	SLDiagCheck(@"SBScreenWakeAnimationController", @"sleepForSource:completion:", NO);
	SLDiagCheck(@"SBLiftToWakeController", @"wakeGestureManager:didUpdateWakeGesture:orientation:detectedAt:", NO);
	SLDiagCheck(@"NCNotificationRequest", @"notificationRequestWithAlertItem:", YES);
	SLDiagCheck(@"SBLockScreenManager", @"sharedInstance", YES);
	SLDiagCheck(@"SBLockScreenManager", @"isLockScreenVisible", NO);
	SLDiagCheck(@"SBLockScreenManager", @"noteMenuButtonSinglePress", NO);
	SLDiagCheck(@"SBLockScreenManager", @"_activateLockScreenAnimated:animationProvider:automatically:inScreenOffMode:dismissNotificationCenter:completion:", NO);
	SLDiagCheck(@"SBLockScreenManager", @"_activateLockScreenAnimated:animationProvider:automatically:inScreenOffMode:dimInAnimation:dismissNotificationCenter:completion:", NO);
	SLDiagCheck(@"SBLockScreenManager", @"unlockUIFromSource:withOptions:", NO);
	SLDiagCheck(@"SBLockScreenManager", @"lockUIFromSource:withOptions:completion:", NO);
	SLDiagCheck(@"SBFUserAuthenticationController", @"_handleSuccessfulAuthentication:responder:", NO);
	Class lockScreenManagerClass = NSClassFromString(@"SBLockScreenManager");
	SLDiagLog(@"  [%@] SBLockScreenManager 成员变量 _isScreenOn", lockScreenManagerClass && class_getInstanceVariable(lockScreenManagerClass, "_isScreenOn") ? @"有" : @"无");
	SLDiagLog(@"相关类的方法（用来找 iOS 16 的替代方法）：");
	SLDiagListMethods(@"SBNCAlertingController", nil);
	SLDiagListMethods(@"SBNCScreenController", nil);
	SLDiagListMethods(@"SBScreenWakeAnimationController", nil);
	SLDiagListMethods(@"SBLockScreenManager", @"screen|wake|lock|visible|backlight");
	SLDiagListIvars(@"SBLockScreenManager", @"screen|wake|backlight|lock");
	SLDiagListMethods(@"SBBacklightController", @"screen|backlight|wake|sleep");
	SLDiagListMethods(@"SBLiftToWakeController", nil);
	SLDiagListMethods(@"NCNotificationDispatcher", @"post|request");
	SLDiagListMethods(@"SBNCNotificationDispatcher", @"post|request|alert");
	SLDiagCheck(@"NCNotificationRequest", @"notificationRequestWithSectionId:notificationId:threadId:title:message:timestamp:destinations:", YES);
	SLDiagCheck(@"SBApplicationController", @"alwaysAvailableApplicationBundle", YES);
	SLDiagListMethods(@"NCMutableNotificationRequest", @"^set");
	SLDiagListMethods(@"NCMutableNotificationContent", @"^set");
	SLDiagListMethods(@"NCMutableNotificationOptions", @"^set");
	for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
		SLDiagLog(@"  scene %@ role=%@ id=%@", NSStringFromClass([scene class]), scene.session.role, scene.session.persistentIdentifier);
	}
	SLDiagLog(@"==== 运行时检查结束 ====");
}
