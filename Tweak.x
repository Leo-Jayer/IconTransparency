#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString *const kDelayKey  = @"transparencyDelay";
static NSString *const kAlphaKey  = @"iconTransparency";
static const double kDefaultDelay = 3.0;
static const double kDefaultAlpha = 0.3;

@interface IconTransparencyManager : NSObject
@property (nonatomic, assign) BOOL isTransparent;
@property (nonatomic, assign) NSTimeInterval lastTouchTime;
@property (nonatomic, strong) NSTimer *checkTimer;
+ (instancetype)sharedInstance;
- (void)start;
- (void)recordTouch;
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
        _lastTouchTime = [NSDate date].timeIntervalSince1970;
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

- (void)start {
    self.checkTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                       target:self
                                                     selector:@selector(check)
                                                     userInfo:nil
                                                      repeats:YES];
}

- (void)recordTouch {
    self.lastTouchTime = [NSDate date].timeIntervalSince1970;
    [self restoreOpaque];
}

- (void)check {
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    double delay = [self configuredDelay];

    if (now - self.lastTouchTime >= delay) {
        [self applyTransparency];
    } else {
        [self restoreOpaque];
    }
}

- (void)applyTransparency {
    if (self.isTransparent) return;
    double alpha = [self configuredAlpha];
    Class iconClass = objc_getClass("SBIconView");
    if (!iconClass) return;

    [self traverseAllWindows:iconClass alpha:alpha animated:YES];
    self.isTransparent = YES;
}

- (void)restoreOpaque {
    if (!self.isTransparent) return;
    Class iconClass = objc_getClass("SBIconView");
    if (!iconClass) return;

    [self traverseAllWindows:iconClass alpha:1.0 animated:NO];
    self.isTransparent = NO;
}

- (void)traverseAllWindows:(Class)iconClass alpha:(double)alpha animated:(BOOL)animated {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        for (UIWindow *w in ws.windows) {
            [self traverseSetAlpha:w iconClass:iconClass alpha:alpha animated:animated];
        }
    }
}

- (void)traverseSetAlpha:(UIView *)view iconClass:(Class)iconClass alpha:(double)alpha animated:(BOOL)animated {
    if (!view) return;
    if ([view isKindOfClass:iconClass]) {
        if (animated) {
            [UIView animateWithDuration:0.8
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                view.alpha = alpha;
            } completion:nil];
        } else {
            view.alpha = alpha;
        }
    }
    for (UIView *sub in view.subviews) {
        [self traverseSetAlpha:sub iconClass:iconClass alpha:alpha animated:animated];
    }
}

@end

// ============ 用触摸事件记录交互 ============
%hook SBIconView
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    [[IconTransparencyManager sharedInstance] recordTouch];
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    [[IconTransparencyManager sharedInstance] recordTouch];
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    [[IconTransparencyManager sharedInstance] recordTouch];
}
%end

%hook SBIconScrollView
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    %orig;
    [[IconTransparencyManager sharedInstance] recordTouch];
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    [[IconTransparencyManager sharedInstance] recordTouch];
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    [[IconTransparencyManager sharedInstance] recordTouch];
}
%end

// ============ 启动 ============
%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[IconTransparencyManager sharedInstance] start];
    });
}
%end
