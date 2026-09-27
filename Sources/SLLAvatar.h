// ShortLook Lite — 头像来源
#import "SLLCommon.h"

typedef void (^SLLAvatarCompletion)(UIImage *image, NSString *source);

@interface SLLAvatarRequest : NSObject
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSDictionary *userInfo;          // 通知 userInfo（合并后）
@property (nonatomic, copy) NSString *contactIdentifier;     // 通讯录联系人 ID（iOS 通讯类通知）
@property (nonatomic, copy) NSString *handle;                // 电话 / 邮箱
@property (nonatomic, strong) UIImage *fallbackImage;        // 通知自带的发送者图（通讯类通知）
@end

@interface SLLAvatarProvider : NSObject
+ (instancetype)shared;
// 结果在主线程回调；image 为 nil 表示没找到（调用方用 App 图标兜底）
- (void)fetch:(SLLAvatarRequest *)request completion:(SLLAvatarCompletion)completion;
- (void)clearCache;
@end
