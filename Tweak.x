#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString *const kDelayKey  = @"transparencyDelay";
static NSString *const kAlphaKey  = @"iconTransparency";
static const double kDefaultDelay = 3.0;
static const double kDefaultAlpha = 0.3;

@interface IconTransparencyManager : NSObject
@property (nonatomic, assign) BOOL isTransparent;
@property (nonatomic, strong) NSTimer *idleTimer;
@property (nonatomic, assign) NSTimeInterval lastInteractTime;
+ (instancetype)sharedInstance;
- (void)userDidInteract;
- (void)applyTransparency;
- (void)restoreOpaque;
- (void)restartTimer;
@end

@implementation IconTransparencyManager

+ (instancetype)sharedInstance {
    static IconTransparencyManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[IconTransparencyManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isTransparent = NO;
        _lastInteractTime = 0;
    }
    return self;
}

- (double)configuredDelay {
    NSNumber *value = [[NSUserDefaults standardUserDefaults] objectForKey:kDelayKey];
    if (!value) return kDefaultDelay;
    double d = [value doubleValue];
    return d > 0 ? d : kDefaultDelay;
}

- (double)configuredAlpha {
    NSNumber *value = [[NSUserDefaults standardUserDefaults] objectForKey:kAlphaKey];
    if (!value) return kDefaultAlpha;
    double a = [value doubleValue];
    if (a < 0.0) a = 0.0;
    if (a > 1.0) a = 1.0;
    return a;
}

// 用户操作：恢复不透明 + 重置计时器
// 加 0.1 秒防抖，避免 scrollViewDidScroll 被自身触发导致死循环
- (void)userDidInteract {
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    if (now - self.lastInteractTime < 0.1) {
        return;
    }
    self.lastInteractTime = now;

    [self restoreOpaque];
    [self restartTimer];
}

// 只重置计时器，不动 alpha
- (void)restartTimer {
    [self.idleTimer invalidate];
    double delay = [self configuredDelay];
    self.idleTimer = [NSTimer scheduledTimerWithTimeInterval:delay
                                                      target:self
                                                    selector:@selector(applyTransparency)
                                                    userInfo:nil
                                                     repeats:NO];
}

- (void)applyTransparency {
    if (self.isTransparent) return;
    double alpha = [self configuredAlpha];
    Class iconClass = objc_getClass("SBIconView");
    if (!iconClass) return;

    [self traverseAllWindows:iconClass alpha:alpha];
    self.isTransparent = YES;
}

- (void)restoreOpaque {
    if (!self.isTransparent) return;
    Class iconClass = objc_getClass("SBIconView");
    if (!iconClass) return;

    [self traverseAllWindows:iconClass alpha:1.0];
    self.isTransparent = NO;
}

// 遍历所有 window（包括隐藏的、非 key 的），确保覆盖 Dock
- (void)traverseAllWindows:(Class)iconClass alpha:(double)alpha {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        for (UIWindow *w in ws.windows) {
            [self traverseSetAlpha:w iconClass:iconClass alpha:alpha];
        }
    }
}

- (void)traverseSetAlpha:(UIView *)view iconClass:(Class)iconClass alpha:(double)alpha {
    if (!view) return;
    if ([view isKindOfClass:iconClass]) {
        view.alpha = alpha;
    }
    for (UIView *sub in view.subviews) {
        [self traverseSetAlpha:sub iconClass:iconClass alpha:alpha];
    }
}

@end

// ============ Hook SBIconScrollView 检测滚动 ============
%hook SBIconScrollView
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    %orig;
    [[IconTransparencyManager sharedInstance] userDidInteract];
}
%end

// ============ SpringBoard 启动后启动计时 ============
%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[IconTransparencyManager sharedInstance] userDidInteract];
    });
}
%end
