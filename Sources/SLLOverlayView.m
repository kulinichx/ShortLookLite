// ShortLook Lite — 全屏大头像视图：黑底、大圆头像、App 小角标、名字、消息、时间
#import "SLLOverlayView.h"

static const CGFloat kBottomPassThrough = 110;   // 底部留给系统上滑解锁手势

@implementation SLLOverlayView {
    UIImageView *_avatarView;
    UIImageView *_badgeView;
    UILabel *_nameLabel;
    UILabel *_messageLabel;
    UILabel *_clockLabel;
    NSString *_message;
    BOOL _messageHidden;
    BOOL _avatarIsAppIcon;
    NSDateFormatter *_clockFormatter;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor blackColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _showsClock = YES;

        _avatarView = [UIImageView new];
        _avatarView.contentMode = UIViewContentModeScaleAspectFill;
        _avatarView.clipsToBounds = YES;
        _avatarView.backgroundColor = [UIColor colorWithWhite:0.16 alpha:1];
        [self addSubview:_avatarView];

        _badgeView = [UIImageView new];
        _badgeView.contentMode = UIViewContentModeScaleAspectFill;
        _badgeView.clipsToBounds = YES;
        _badgeView.layer.borderColor = [UIColor blackColor].CGColor;
        _badgeView.layer.borderWidth = 3;
        [self addSubview:_badgeView];

        _nameLabel = [UILabel new];
        _nameLabel.font = [UIFont systemFontOfSize:30 weight:UIFontWeightBold];
        _nameLabel.textColor = [UIColor whiteColor];
        _nameLabel.textAlignment = NSTextAlignmentCenter;
        _nameLabel.adjustsFontSizeToFitWidth = YES;
        _nameLabel.minimumScaleFactor = 0.6;
        [self addSubview:_nameLabel];

        _messageLabel = [UILabel new];
        _messageLabel.font = [UIFont systemFontOfSize:18];
        _messageLabel.textColor = [UIColor colorWithWhite:0.78 alpha:1];
        _messageLabel.textAlignment = NSTextAlignmentCenter;
        _messageLabel.numberOfLines = 5;
        [self addSubview:_messageLabel];

        _clockLabel = [UILabel new];
        _clockLabel.font = [UIFont monospacedDigitSystemFontOfSize:22 weight:UIFontWeightSemibold];
        _clockLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1];
        _clockLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_clockLabel];

        _clockFormatter = [NSDateFormatter new];
        _clockFormatter.dateFormat = @"HH:mm";

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_tapped)];
        [self addGestureRecognizer:tap];
        UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(_swiped)];
        swipe.direction = UISwipeGestureRecognizerDirectionUp | UISwipeGestureRecognizerDirectionDown |
                          UISwipeGestureRecognizerDirectionLeft | UISwipeGestureRecognizerDirectionRight;
        [self addGestureRecognizer:swipe];
        [self refreshClock];
    }
    return self;
}

- (void)_tapped { if (self.onDismissRequest) self.onDismissRequest(@"点击"); }
- (void)_swiped { if (self.onDismissRequest) self.onDismissRequest(@"滑动"); }

// 底部一条让给系统（上滑解锁 / 主屏手势）
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (point.y > self.bounds.size.height - kBottomPassThrough) return NO;
    return [super pointInside:point withEvent:event];
}

- (void)setShowsClock:(BOOL)showsClock {
    _showsClock = showsClock;
    _clockLabel.hidden = !showsClock;
}

- (void)refreshClock {
    _clockLabel.text = [_clockFormatter stringFromDate:[NSDate date]];
}

- (void)setName:(NSString *)name message:(NSString *)message appIcon:(UIImage *)appIcon {
    _nameLabel.text = name;
    _message = [message copy];
    _messageLabel.text = _messageHidden ? nil : _message;
    _badgeView.image = appIcon;
    _badgeView.hidden = (appIcon == nil) || _avatarIsAppIcon;
    [self setNeedsLayout];
}

- (void)setMessageHidden:(BOOL)hidden {
    if (_messageHidden == hidden && _messageLabel.text) return;
    _messageHidden = hidden;
    _messageLabel.text = hidden ? nil : _message;
    [self setNeedsLayout];
}

- (void)setAvatar:(UIImage *)avatar isAppIcon:(BOOL)isAppIcon animated:(BOOL)animated {
    _avatarIsAppIcon = isAppIcon;
    _badgeView.hidden = isAppIcon || _badgeView.image == nil;
    if (animated && _avatarView.image) {
        [UIView transitionWithView:_avatarView duration:0.25
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{ self->_avatarView.image = avatar; } completion:nil];
    } else {
        _avatarView.image = avatar;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height;
    UIEdgeInsets safe = self.safeAreaInsets;

    CGFloat A = floor(MIN(W * 0.62, MIN(H * 0.36, 300)));
    CGFloat cy = floor(H * 0.40);
    _avatarView.frame = CGRectMake(floor((W - A) / 2), floor(cy - A / 2), A, A);
    _avatarView.layer.cornerRadius = A / 2;

    CGFloat bs = floor(A * 0.26);
    CGFloat off = A / 2 * 0.7071;
    _badgeView.frame = CGRectMake(floor(W / 2 + off - bs / 2), floor(cy + off - bs / 2), bs, bs);
    _badgeView.layer.cornerRadius = bs * 0.225;

    CGFloat y = CGRectGetMaxY(_avatarView.frame) + 30;
    _nameLabel.frame = CGRectMake(24, y, W - 48, 38);
    y += 38 + 10;
    CGFloat maxH = MAX(0, H - kBottomPassThrough - 10 - y);
    CGSize ms = [_messageLabel sizeThatFits:CGSizeMake(W - 56, CGFLOAT_MAX)];
    _messageLabel.frame = CGRectMake(28, y, W - 56, MIN(ceil(ms.height), maxH));

    _clockLabel.frame = CGRectMake(0, MAX(safe.top, 20) + 6, W, 28);
}

@end
