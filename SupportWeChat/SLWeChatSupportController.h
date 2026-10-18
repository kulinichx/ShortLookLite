#import <UIKit/UIKit.h>

// Directly request WeChat's native appreciation flow on its existing navigation stack.
// No custom support/QR view controller is presented.
void SLOpenWeChatNativeAppreciation(UIViewController *presenter);
NSBundle *SLWeChatSupportResources(void);
