#import "DDNotificationContactPhotoProviderPluginLoader.h"
#import "DDNotificationContactPhotoProviderManager.h"
#import "Private.h"

#define kPluginDirectory jbroot(@"/Library/Dynastic/ShortLook/Plugins/ContactPhotoProviders/")

@implementation DDNotificationContactPhotoProviderPluginLoader

- (void)loadPlugins {
	for (NSBundle *bundle in [self allPluginBundles]) {
		[self loadBundle:bundle];
	}
}

- (NSArray *)allPluginBundles {
	NSMutableArray *bundles = [NSMutableArray array];
	NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:kPluginDirectory error:nil];
	for (NSString *name in contents) {
		NSBundle *bundle = [NSBundle bundleWithPath:[kPluginDirectory stringByAppendingPathComponent:name]];
		if (bundle) [bundles addObject:bundle];
	}
	return bundles;
}

- (void)loadBundle:(NSBundle *)bundle {
	NSString *message;
	if (!bundle.infoDictionary[@"DDNotificationExternalProviderAPIVersion"] || [bundle.infoDictionary[@"DDNotificationExternalProviderAPIVersion"] integerValue] != 1) {
		message = @"DDNotificationExternalProviderAPIVersion mismatch.";
	} else if (!bundle.infoDictionary[@"DDNotificationExternalProviderClasses"] || ![bundle.infoDictionary[@"DDNotificationExternalProviderClasses"] isKindOfClass:[NSDictionary class]]) {
		message = @"Your Info.plist did not contain a DDNotificationExternalProviderClasses dictionary.";
	} else {
		NSDictionary *classes = bundle.infoDictionary[@"DDNotificationExternalProviderClasses"];
		if ([bundle load]) {
			[classes enumerateKeysAndObjectsUsingBlock:^(NSString *className, id bundleIdentifiers, BOOL *stop) {
				if ([bundleIdentifiers isKindOfClass:[NSString class]]) {
					[self loadClassNamed:className forBundleIdentifier:bundleIdentifiers fromBundle:bundle];
				} else if ([bundleIdentifiers isKindOfClass:[NSArray class]]) {
					for (NSString *bundleIdentifier in bundleIdentifiers) {
						[self loadClassNamed:className forBundleIdentifier:bundleIdentifier fromBundle:bundle];
					}
				}
			}];
			return;
		}
		message = @"Couldn't load bundle executable into running process.";
	}
	[self logErrorForBundle:bundle withMessage:message];
}

- (void)loadClassNamed:(NSString *)className forBundleIdentifier:(NSString *)bundleIdentifier fromBundle:(NSBundle *)bundle {
	Class providerClass = NSClassFromString(className);
	if (!providerClass) {
		[self logErrorForBundle:bundle withMessage:[NSString stringWithFormat:@"Couldn't find provider class %@", className]];
	} else if (![providerClass conformsToProtocol:@protocol(DDNotificationContactPhotoProviding)]) {
		[self logErrorForBundle:bundle withMessage:[NSString stringWithFormat:@"Provider class %@ does not conform to DDNotificationContactPhotoProviding", className]];
	} else {
		[[DDNotificationContactPhotoProviderManager sharedManager] registerProvider:providerClass forBundleIdentifier:bundleIdentifier];
	}
}

- (void)logErrorForBundle:(NSBundle *)bundle withMessage:(NSString *)message {
	// Intentionally silent (matches the original build).
}

@end
