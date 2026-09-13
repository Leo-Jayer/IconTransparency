#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static NSString *const kDelayKey  = @"transparencyDelay";
static NSString *const kAlphaKey  = @"iconTransparency";
static const double kDefaultDelay = 3.0;
static const double kDefaultAlpha = 0.3;

@interface IconTransparencyManager : NSObject
@property (nonatomic, assign) BOOL isTransparent;
@property (nonatomic, assign) NSTimeInterval lastInteractionTime;
@property (nonatomic, strong) NSTimer *globalTimer;
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
        _lastInteractionTime = 0;
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

// 用户操作时调用：恢复不透明，更新交互时间，重启全局定时器
- (void)userDidInteract {
    self.lastInteractionTime = [NSDate date].timeIntervalSince1970;
    [self restoreOpaque];

    [self.globalTimer invalidate];
    double delay = [self configuredDelay];
    self.globalTimer = [NSTimer scheduledTimerWithTimeInterval:delay
                                                         target:self
                                                       selector:@selector(onTimerFire)
                                                       userInfo:nil
                                                        repeats:NO];
}

- (void)onTimerFire {
    // 检查是否真的静止了足够久
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    double delay = [self configuredDelay];
    if (now - self.lastInteractionTime < delay - 0.5) {
        // 还没到时间，重新排一个短定时器
        [self.globalTimer invalidate];
        self.globalTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                             target:self
                                                           selector:@selector(onTimerFire)
                                                           userInfo:nil
                                                            repeats:NO];
        return;
    }
    [self applyTransparency];
}

- (void)applyTransparency {
    if (self.isTransparent) return;
    double alpha = [self configuredAlpha];

    // 只遍历当前 keyWindow 下的图标，不遍历整个视图树
    UIWindow *keyWindow = [self currentKeyWindow];
    if (!keyWindow) return;

    Class iconClass = NSClassFromString(@"SBIconView");
    if (iconClass) {
        [self traverse:keyWindow iconClass:iconClass alpha:alpha];
    }
    self.isTransparent = YES;
}

- (void)restoreOpaque {
    if (!self.isTransparent) return;
    UIWindow *keyWindow = [self currentKeyWindow];
    if (!keyWindow) return;

    Class iconClass = NSClassFromString(@"SBIconView");
    if (iconClass) {
        [self traverse:keyWindow iconClass:iconClass alpha:1.0];
    }
    self.isTransparent = NO;
}

- (UIWindow *)currentKeyWindow {
    if (@available(iOS 15.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            for (UIWindow *w in ws.windows) {
                if (w.isKeyWindow) return w;
            }
        }
    }
    return nil;
}

- (void)traverse:(UIView *)view iconClass:(Class)iconClass alpha:(double)alpha {
    if ([view isKindOfClass:iconClass]) {
        view.alpha = alpha;
    }
    for (UIView *sub in view.subviews) {
        [self traverse:sub iconClass:iconClass alpha:alpha];
    }
}

@end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[IconTransparencyManager sharedInstance] userDidInteract];
    });
}
%end
