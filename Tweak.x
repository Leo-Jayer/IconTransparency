#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString *const kDelayKey  = @"transparencyDelay";
static NSString *const kAlphaKey  = @"iconTransparency";
static const double kDefaultDelay = 3.0;
static const double kDefaultAlpha = 0.3;

@interface SBIconController : NSObject
+ (instancetype)sharedInstance;
@end

@interface IconTransparencyManager : NSObject
@property (nonatomic, assign) BOOL isTransparent;
@property (nonatomic, strong) NSTimer *idleTimer;
+ (instancetype)sharedInstance;
- (void)userDidInteract;
- (void)applyTransparency;
- (void)restoreOpaque;
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

- (void)userDidInteract {
    [self restoreOpaque];
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

    // 从 SBIconController 拿到所有 window，遍历全部
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

- (void)traverseAllWindows:(Class)iconClass alpha:(double)alpha {
    // 方法 1：遍历 connectedScenes 的所有 window
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

// ============ 用触摸事件结束来触发交互 ============
// SBIconView 的 touchesEnded 最可靠，但之前 hook 会崩
// 改成 hook SBIconController 的 iconTapped
@interface SBIconController (Hook)
@end

%hook SBIconController
- (void)iconTapped:(id)arg1 {
    %orig;
    [[IconTransparencyManager sharedInstance] userDidInteract];
}
%end

// 用 scrollView 的 decelerate 结束检测
%hook SBIconScrollView
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    %orig;
    [[IconTransparencyManager sharedInstance] userDidInteract];
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    %orig;
    if (!decelerate) {
        [[IconTransparencyManager sharedInstance] userDidInteract];
    }
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
