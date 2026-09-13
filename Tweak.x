#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString *const kPrefsPath = @"/var/mobile/Library/Preferences/com.yourname.icontransparency.plist";
static const double kDefaultDelay = 3.0;
static const double kDefaultAlpha = 0.9;
static const BOOL kDefaultEnabled = YES;

@interface IconTransparencyManager : NSObject
@property (nonatomic, assign) BOOL isTransparent;
@property (nonatomic, assign) NSTimeInterval lastTouchTime;
@property (nonatomic, strong) NSTimer *checkTimer;
+ (instancetype)sharedInstance;
- (void)start;
- (void)recordTouch;
- (void)applyTransparency;
- (void)restoreOpaque;
- (BOOL)isEnabled;
- (double)configuredAlpha;
- (void)traverseAllWindows:(Class)iconClass alpha:(double)alpha animated:(BOOL)animated;
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

- (NSDictionary *)loadPrefsDict {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    return dict ?: @{};
}

- (BOOL)isEnabled {
    NSDictionary *dict = [self loadPrefsDict];
    NSNumber *value = dict[@"enabled"];
    if (!value) return kDefaultEnabled;
    return [value boolValue];
}

- (double)configuredDelay {
    NSDictionary *dict = [self loadPrefsDict];
    NSNumber *value = dict[@"transparencyDelay"];
    if (!value) return kDefaultDelay;
    double d = [value doubleValue];
    if (d < 1.0) d = 1.0;
    if (d > 10.0) d = 10.0;
    return d;
}

- (double)configuredAlpha {
    NSDictionary *dict = [self loadPrefsDict];
    NSNumber *value = dict[@"iconTransparency"];
    if (!value) return kDefaultAlpha;
    double a = [value doubleValue];
    if (a < 0.0) a = 0.0;
    if (a > 1.0) a = 1.0;
    return 1.0 - a;
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
    if (![self isEnabled]) {
        [self restoreOpaque];
        return;
    }

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

static void prefsChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[IconTransparencyManager sharedInstance] recordTouch];
}

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

// 新增：图标出现在窗口时，如果当前是透明状态，立刻应用
- (void)didMoveToWindow {
    %orig;
    IconTransparencyManager *mgr = [IconTransparencyManager sharedInstance];
    if (![mgr isEnabled]) return;
    if (!mgr.isTransparent) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.alpha = [mgr configuredAlpha];
    });
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

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[IconTransparencyManager sharedInstance] start];
    });
}
%end

%ctor {
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        prefsChangedCallback,
        CFSTR("com.yourname.icontransparency/prefsChanged"),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );
}