// ShortLook Lite — 头像来源：微信（本地数据库）、QQ（qlogo）、通讯录、通知自带图
#import "SLLAvatar.h"
#import <Contacts/Contacts.h>
#import <objc/runtime.h>
#import <sqlite3.h>

static NSString *const kWeChatBundle = @"com.tencent.xin";
static NSString *const kQQBundle     = @"com.tencent.mqq";
static const NSTimeInterval kDiskCacheTTL = 3 * 24 * 3600;   // 磁盘缓存 3 天后刷新

NSString *SLLPickWeChatURL(NSData *blob);

@implementation SLLAvatarRequest
@end

@implementation SLLAvatarProvider {
    dispatch_queue_t _queue;
    NSCache<NSString *, UIImage *> *_memory;
    NSURLSession *_session;
    NSString *_weChatDBPath;     // 解析到的 WCDB_Contact.sqlite（只在 _queue 上访问）
}

+ (instancetype)shared {
    static SLLAvatarProvider *p;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ p = [self new]; });
    return p;
}

- (instancetype)init {
    if ((self = [super init])) {
        _queue = dispatch_queue_create("com.kokol.shortlooklite.avatar", DISPATCH_QUEUE_SERIAL);
        _memory = [NSCache new];
        _memory.countLimit = 40;
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        cfg.timeoutIntervalForRequest = 8;
        cfg.timeoutIntervalForResource = 12;
        _session = [NSURLSession sessionWithConfiguration:cfg];
    }
    return self;
}

- (void)clearCache {
    dispatch_async(_queue, ^{
        [self->_memory removeAllObjects];
        NSString *dir = [SLLCacheDir() stringByAppendingPathComponent:@"avatars"];
        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSString *f in [fm contentsOfDirectoryAtPath:dir error:nil]) {
            [fm removeItemAtPath:[dir stringByAppendingPathComponent:f] error:nil];
        }
        self->_weChatDBPath = nil;
        SLLLog(@"头像缓存已清除");
    });
}

#pragma mark - 入口

- (void)fetch:(SLLAvatarRequest *)req completion:(SLLAvatarCompletion)completion {
    void (^done)(UIImage *, NSString *) = ^(UIImage *img, NSString *src) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(img, src); });
    };
    dispatch_async(_queue, ^{
        NSString *bid = req.bundleID ?: @"";

        // 1) 微信：userInfo["u"] = 会话 userName（个人 wxid_xxx / 群 xxx@chatroom）
        if ([bid isEqualToString:kWeChatBundle]) {
            NSString *user = SLLStr(req.userInfo[@"u"]);
            if (user.length) {
                NSString *key = [@"wx:" stringByAppendingString:user];
                if ([self cachedImageForKey:key done:done source:@"微信(缓存)"]) return;
                NSString *url = [self weChatAvatarURLForUser:user];
                SLLLog(@"微信 u=%@ url=%@", user, url ?: @"(未找到)");
                if (url) {
                    [self downloadURLs:@[url] key:key source:@"微信" done:done fallback:req];
                    return;
                }
                if ([self staleImageForKey:key done:done source:@"微信(旧缓存)"]) return;
            } else {
                SLLLog(@"微信通知没有 u 字段，userInfo keys=%@", req.userInfo.allKeys);
            }
        }

        // 2) QQ：userInfo["r"] = "c|QQ号" 或 "g|群号"
        if ([bid isEqualToString:kQQBundle]) {
            NSString *r = SLLStr(req.userInfo[@"r"]);
            NSArray *parts = [r componentsSeparatedByString:@"|"];
            if (parts.count >= 2 && [parts[1] length]) {
                NSString *type = parts[0], *num = parts[1];
                NSString *key = [NSString stringWithFormat:@"qq:%@:%@", type, num];
                if ([self cachedImageForKey:key done:done source:@"QQ(缓存)"]) return;
                NSArray *urls = nil;
                if ([type isEqualToString:@"g"]) {
                    urls = @[[NSString stringWithFormat:@"https://p.qlogo.cn/gh/%@/%@/640", num, num],
                             [NSString stringWithFormat:@"https://p.qlogo.cn/gh/%@/%@/140", num, num]];
                } else {
                    urls = @[[NSString stringWithFormat:@"https://q1.qlogo.cn/g?b=qq&s=640&nk=%@", num],
                             [NSString stringWithFormat:@"https://q1.qlogo.cn/g?b=qq&s=140&nk=%@", num]];
                }
                SLLLog(@"QQ r=%@", r);
                [self downloadURLs:urls key:key source:@"QQ" done:done fallback:req];
                return;
            } else {
                SLLLog(@"QQ 通知 r 字段无法解析: %@，userInfo keys=%@", r, req.userInfo.allKeys);
            }
        }

        // 3) 通讯录 / 通知自带图
        [self finishWithContactOrFallback:req done:done];
    });
}

#pragma mark - 缓存

- (NSString *)diskPathForKey:(NSString *)key {
    return [[SLLCacheDir() stringByAppendingPathComponent:@"avatars"]
            stringByAppendingPathComponent:[SLLMD5(key) stringByAppendingPathExtension:@"img"]];
}

- (BOOL)cachedImageForKey:(NSString *)key done:(void (^)(UIImage *, NSString *))done source:(NSString *)src {
    UIImage *img = [_memory objectForKey:key];
    if (img) { done(img, src); return YES; }
    NSString *path = [self diskPathForKey:key];
    NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    if (attr && -[attr.fileModificationDate timeIntervalSinceNow] < kDiskCacheTTL) {
        img = [UIImage imageWithContentsOfFile:path];
        if (img) {
            [_memory setObject:img forKey:key];
            done(img, src);
            return YES;
        }
    }
    return NO;
}

- (BOOL)staleImageForKey:(NSString *)key done:(void (^)(UIImage *, NSString *))done source:(NSString *)src {
    UIImage *img = [UIImage imageWithContentsOfFile:[self diskPathForKey:key]];
    if (!img) return NO;
    [_memory setObject:img forKey:key];
    done(img, src);
    return YES;
}

#pragma mark - 下载

// 依次尝试 urls；全部失败时用旧缓存，再退回通讯录/通知自带图
- (void)downloadURLs:(NSArray<NSString *> *)urls key:(NSString *)key source:(NSString *)src
                done:(void (^)(UIImage *, NSString *))done fallback:(SLLAvatarRequest *)req {
    if (urls.count == 0) {
        dispatch_async(_queue, ^{
            if ([self staleImageForKey:key done:done source:[src stringByAppendingString:@"(旧缓存)"]]) return;
            [self finishWithContactOrFallback:req done:done];
        });
        return;
    }
    NSURL *url = [NSURL URLWithString:urls.firstObject];
    NSArray *rest = [urls subarrayWithRange:NSMakeRange(1, urls.count - 1)];
    if (!url) { [self downloadURLs:rest key:key source:src done:done fallback:req]; return; }

    [[_session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        NSInteger code = [resp isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)resp).statusCode : 0;
        UIImage *img = (data.length && code == 200) ? [UIImage imageWithData:data] : nil;
        if (img && img.size.width >= 20) {
            dispatch_async(self->_queue, ^{
                [data writeToFile:[self diskPathForKey:key] atomically:YES];
                [self->_memory setObject:img forKey:key];
                SLLLog(@"%@ 头像下载成功 %.0fx%.0f", src, img.size.width * img.scale, img.size.height * img.scale);
                done(img, src);
            });
        } else {
            SLLLog(@"%@ 头像下载失败 code=%ld err=%@ url=%@", src, (long)code, err.localizedDescription, url);
            [self downloadURLs:rest key:key source:src done:done fallback:req];
        }
    }] resume];
}

#pragma mark - 通讯录

- (void)finishWithContactOrFallback:(SLLAvatarRequest *)req done:(void (^)(UIImage *, NSString *))done {
    UIImage *img = [self contactImageFor:req];
    if (img) { done(img, @"通讯录"); return; }
    if (req.fallbackImage) { done(req.fallbackImage, @"通知自带"); return; }
    done(nil, nil);
}

- (UIImage *)contactImageFor:(SLLAvatarRequest *)req {
    if (!req.contactIdentifier.length && !req.handle.length) return nil;
    NSString *key = [NSString stringWithFormat:@"ct:%@:%@", req.contactIdentifier ?: @"", req.handle ?: @""];
    UIImage *cached = [_memory objectForKey:key];
    if (cached) return cached;

    CNContactStore *store = [CNContactStore new];
    NSArray *keys = @[CNContactImageDataKey, CNContactThumbnailImageDataKey, CNContactImageDataAvailableKey];
    CNContact *contact = nil;
    NSError *err = nil;
    @try {
        if (req.contactIdentifier.length) {
            contact = [store unifiedContactWithIdentifier:req.contactIdentifier keysToFetch:keys error:&err];
        }
        if (!contact && req.handle.length) {
            NSString *h = req.handle;
            if ([h hasPrefix:@"tel:"]) h = [h substringFromIndex:4];
            if ([h hasPrefix:@"mailto:"]) h = [h substringFromIndex:7];
            NSPredicate *pred = [h containsString:@"@"]
                ? [CNContact predicateForContactsMatchingEmailAddress:h]
                : [CNContact predicateForContactsMatchingPhoneNumber:[CNPhoneNumber phoneNumberWithStringValue:h]];
            contact = [store unifiedContactsMatchingPredicate:pred keysToFetch:keys error:&err].firstObject;
        }
    } @catch (NSException *e) {
        SLLLog(@"通讯录异常 %@", e.reason);
    }
    NSData *data = contact.imageDataAvailable ? (contact.imageData ?: contact.thumbnailImageData) : nil;
    UIImage *img = data ? [UIImage imageWithData:data] : nil;
    SLLLog(@"通讯录 id=%@ handle=%@ -> %@%@", req.contactIdentifier, req.handle,
           img ? @"有头像" : @"无头像", err ? [@" err=" stringByAppendingString:err.localizedDescription] : @"");
    if (img) [_memory setObject:img forKey:key];
    return img;
}

#pragma mark - 微信数据库

- (NSString *)weChatDocuments {
    NSURL *url = nil;
    Class proxyClass = objc_getClass("LSApplicationProxy");
    if ([proxyClass respondsToSelector:@selector(applicationProxyForIdentifier:)]) {
        LSApplicationProxy *proxy = [proxyClass applicationProxyForIdentifier:kWeChatBundle];
        if ([proxy respondsToSelector:@selector(dataContainerURL)]) url = [proxy dataContainerURL];
    }
    if (!url) {
        Class recClass = objc_getClass("LSApplicationRecord");
        if ([recClass instancesRespondToSelector:@selector(initWithBundleIdentifier:allowPlaceholder:error:)]) {
            LSApplicationRecord *rec = [[recClass alloc] initWithBundleIdentifier:kWeChatBundle allowPlaceholder:NO error:nil];
            if ([rec respondsToSelector:@selector(dataContainerURL)]) url = [rec dataContainerURL];
        }
    }
    return url ? [url.path stringByAppendingPathComponent:@"Documents"] : nil;
}

// 候选数据库：优先 LocalInfo.lst 里的当前账号（$objects[2] 的 MD5 目录），其余按修改时间排
- (NSArray<NSString *> *)weChatDBCandidates {
    NSString *docs = [self weChatDocuments];
    if (!docs) { SLLLog(@"找不到微信数据容器"); return @[]; }
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray *out = [NSMutableArray array];

    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[docs stringByAppendingPathComponent:@"LocalInfo.lst"]];
    NSArray *objs = [info[@"$objects"] isKindOfClass:[NSArray class]] ? info[@"$objects"] : nil;
    if (objs.count > 2 && [objs[2] isKindOfClass:[NSString class]]) {
        NSString *p = [NSString stringWithFormat:@"%@/%@/DB/WCDB_Contact.sqlite", docs, SLLMD5(objs[2])];
        if ([fm fileExistsAtPath:p]) [out addObject:p];
    }

    NSMutableArray *others = [NSMutableArray array];
    for (NSString *name in [fm contentsOfDirectoryAtPath:docs error:nil]) {
        if (name.length != 32) continue;
        NSString *p = [NSString stringWithFormat:@"%@/%@/DB/WCDB_Contact.sqlite", docs, name];
        if ([fm fileExistsAtPath:p] && ![out containsObject:p]) [others addObject:p];
    }
    [others sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        NSDate *da = [fm attributesOfItemAtPath:a error:nil].fileModificationDate ?: [NSDate distantPast];
        NSDate *db = [fm attributesOfItemAtPath:b error:nil].fileModificationDate ?: [NSDate distantPast];
        return [db compare:da];
    }];
    [out addObjectsFromArray:others];
    return out;
}

- (NSData *)headImageBlobForUser:(NSString *)user inDB:(NSString *)path {
    sqlite3 *db = NULL;
    NSData *result = nil;
    if (sqlite3_open_v2(path.fileSystemRepresentation, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, NULL) != SQLITE_OK) {
        SLLLog(@"打开微信数据库失败: %s", db ? sqlite3_errmsg(db) : "?");
        if (db) sqlite3_close(db);
        return nil;
    }
    sqlite3_busy_timeout(db, 300);
    sqlite3_stmt *stmt = NULL;
    const char *sql = "SELECT dbContactHeadImage FROM Friend WHERE userName = ?1 LIMIT 1";
    if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, user.UTF8String, -1, SQLITE_TRANSIENT);
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            const void *bytes = sqlite3_column_blob(stmt, 0);
            int len = sqlite3_column_bytes(stmt, 0);
            if (bytes && len > 0) result = [NSData dataWithBytes:bytes length:(NSUInteger)len];
            else result = [NSData data];   // 找到行但没头像
        }
    } else {
        SLLLog(@"微信数据库查询准备失败: %s", sqlite3_errmsg(db));
    }
    sqlite3_finalize(stmt);
    sqlite3_close(db);
    return result;
}

- (NSString *)weChatAvatarURLForUser:(NSString *)user {
    NSMutableArray *dbs = [NSMutableArray array];
    if (_weChatDBPath) [dbs addObject:_weChatDBPath];
    for (NSString *p in [self weChatDBCandidates]) if (![dbs containsObject:p]) [dbs addObject:p];

    for (NSString *path in dbs) {
        NSData *blob = [self headImageBlobForUser:user inDB:path];
        if (!blob) continue;               // 这个库里没有此人
        _weChatDBPath = path;
        NSString *url = SLLPickWeChatURL(blob);
        if (!url) SLLLog(@"微信头像字段里没有 URL（长度 %lu）", (unsigned long)blob.length);
        return url;
    }
    SLLLog(@"微信数据库里找不到 %@（候选库 %lu 个）", user, (unsigned long)dbs.count);
    return nil;
}

#pragma mark - 从头像 blob 里取 URL

static BOOL SLLIsURLChar(unsigned char c) {
    if (c < 0x21 || c > 0x7e) return NO;
    return strchr("\"*<>\\^`{|}", c) == NULL;
}

// blob 是 protobuf：字符串前面是 varint 长度。先按长度取，不行再按可见字符截取。
static NSArray<NSString *> *SLLExtractURLs(NSData *data) {
    const unsigned char *b = data.bytes;
    NSUInteger n = data.length;
    NSMutableArray *out = [NSMutableArray array];
    for (NSUInteger i = 0; i + 8 < n; i++) {
        if (memcmp(b + i, "http", 4) != 0) continue;
        NSUInteger len = 0;
        if (i >= 2 && (b[i - 2] & 0x80) && b[i - 1] < 0x80) len = (b[i - 2] & 0x7f) | ((NSUInteger)b[i - 1] << 7);
        if ((len == 0 || i + len > n) && i >= 1 && b[i - 1] < 0x80) len = b[i - 1];
        BOOL ok = len > 8 && i + len <= n;
        for (NSUInteger k = 0; ok && k < len; k++) if (!SLLIsURLChar(b[i + k])) ok = NO;
        if (!ok) {
            len = 0;
            while (i + len < n && SLLIsURLChar(b[i + len])) len++;
        }
        NSString *s = [[NSString alloc] initWithBytes:b + i length:len encoding:NSASCIIStringEncoding];
        if (s.length > 10) [out addObject:s];
        i += len ? len - 1 : 0;
    }
    return out;
}

NSString *SLLPickWeChatURL(NSData *blob) {
    NSArray *urls = SLLExtractURLs(blob);
    if (urls.count == 0) return nil;
    NSString *pick = nil;
    for (NSString *u in urls) if ([u hasSuffix:@"/0"]) { pick = u; break; }   // 原图
    if (!pick) pick = urls.firstObject;
    if ([pick hasSuffix:@"/132"]) pick = [[pick substringToIndex:pick.length - 4] stringByAppendingString:@"/0"];
    if ([pick hasPrefix:@"http://"]) pick = [@"https://" stringByAppendingString:[pick substringFromIndex:7]];
    return pick;
}

@end
