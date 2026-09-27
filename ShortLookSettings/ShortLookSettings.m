#import <Foundation/Foundation.h>

// The original ShortLookSettings binary contains no classes: its principal class, DDSettingsController,
// comes from FloraSettings. Its only code is this constructor.
__attribute__((constructor)) static void init(void) {
	NSLog(@"Hi!");
}
