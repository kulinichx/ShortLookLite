#import "DDApplication.h"
#import "DDApplicationColourAnalyzer.h"
#import "Private.h"

@implementation DDApplication

+ (instancetype)applicationFromNotificationRequest:(NCNotificationRequest *)request {
	SBApplication *application = [[NSClassFromString(@"SBApplicationController") sharedInstance] applicationWithBundleIdentifier:request.sectionIdentifier];
	UIImage *icon = [[self _getApplicationIconForApplication:application] copy];
	if (!icon) icon = [self _providedIconFromNotificationContent:request.content];
	BOOL usesSystemIcon = NO;
	if (request.sourceInfo && [request.sourceInfo[@"usesSystemIcon"] boolValue]) {
		NSURL *url = [[NSURL fileURLWithPath:jbroot(@"/Library/Application Support/Dynastic/ShortLook")] URLByAppendingPathComponent:@"system_notification.png"];
		icon = [UIImage imageWithContentsOfFile:url.path];
		usesSystemIcon = YES;
	}
	BOOL usesAttachmentImage = NO;
	if (!icon) {
		usesAttachmentImage = [request.content respondsToSelector:@selector(attachmentImage)] && request.content.attachmentImage != nil;
	}
	DDApplication *app = [[DDApplication alloc] initWithTitle:request.content.header icon:(usesAttachmentImage ? [request.content.attachmentImage copy] : [icon copy]) identifier:request.sectionIdentifier];
	app.usesInnerIconAppearance = usesAttachmentImage;
	app.allowsPreciseIconTransition = !(usesSystemIcon || usesAttachmentImage);
	return app;
}

+ (UIImage *)_getApplicationIconForApplication:(SBApplication *)application {
	if (!application) return nil;
	return [UIImage _applicationIconImageForBundleIdentifier:application.bundleIdentifier format:2 scale:3.0];
}

+ (UIImage *)_providedIconFromNotificationContent:(NCNotificationContent *)content {
	if ([content respondsToSelector:@selector(icon)]) return content.icon;
	if ([content respondsToSelector:@selector(icons)]) return content.icons.firstObject;
	return nil;
}

- (instancetype)initWithTitle:(NSString *)title icon:(UIImage *)icon identifier:(NSString *)identifier {
	if ((self = [super init])) {
		_title = title;
		_icon = icon;
		_identifier = identifier;
		_allowsPreciseIconTransition = YES;
	}
	return self;
}

- (UIColor *)iconTintColour {
	return [[DDApplicationColourAnalyzer sharedAnalyzer] idealColourForImage:_icon withIdentifier:_identifier];
}

@end
