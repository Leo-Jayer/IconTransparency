#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// ============ 私有类声明 ============
@interface SBIconController : NSObject
- (void)iconTapped:(id)arg1;
@end

@interface SBIconListView : UIView
@end

@interface SpringBoard : UIApplication
- (void)applicationDidFinishLaunching:(id)application;
@end

// ============ 偏好设置键名 ============
static NSString *const kDelayKey  = @"transparencyDelay";
static NSString *const kAlphaKey  = @"iconTransparency";
static const double kDefaultDelay = 3.0;
static const double kDefaultAlpha = 0.3;

@interface IconTransparencyManager : NSObject
@property (nonatomic, assign) BOOL isTransparent;
@property (nonatomic, strong) NSTimer *idleTimer;
+ (instancetype)sharedInstance;
- (void)userDidInteract;
- (void)scheduleTransparency;
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
    [self.idleTimer invalidate];
    self.idleTimer = nil;
    [self restoreOpaque];
    [self scheduleTransparency];
}

- (void)scheduleTransparency {
    [self.idleTimer invalidate];
    double delay = [self configuredDelay];
    self.idleTimer = [NSTimer scheduledTimerWithTimeInterval:delay
                                                      target:self
                                                    selector:@selector(applyTransparency)
                                                    userInfo:nil
                                                     repeats:NO];
}

- (void)applyTransparency {
    double alpha = [self configuredAlpha];
    [self enumerateIconViews:^(UIView *view) {
        [UIView animateWithDuration:0.6
                              delay:0
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            view.alpha = alpha;
        } completion:nil];
    }];
    self.isTransparent = YES;
}

- (void)restoreOpaque {
    if (!self.isTransparent) return;
    [self enumerateIconViews:^(UIView *view) {
        [UIView animateWithDuration:0.3
                              delay:0
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            view.alpha = 1.0;
        } completion:nil];
    }];
    self.isTransparent = NO;
}

- (void)enumerateIconViews:(void (^)(UIView *view))block {
    if (!block) return;

    UIWindow *keyWindow = nil;
    if (@available(iOS 15.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) {
                    keyWindow = window;
                    break;
                }
            }
            if (keyWindow) break;
        }
    } else {
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
    }

    if (!keyWindow) return;
    ...
}
    if (!keyWindow) return;

    Class iconViewClass   = NSClassFromString(@"SBIconView");
    Class widgetViewClass = NSClassFromString(@"SBIconWidgetView");

    [self traverseView:keyWindow iconClass:iconViewClass widgetClass:widgetViewClass block:block];
}

- (void)traverseView:(UIView *)view
           iconClass:(Class)iconClass
         widgetClass:(Class)widgetClass
               block:(void (^)(UIView *view))block {
    if (!view) return;

    if ((iconClass && [view isKindOfClass:iconClass]) ||
        (widgetClass && [view isKindOfClass:widgetClass])) {
        block(view);
    }

    for (UIView *sub in view.subviews) {
        [self traverseView:sub iconClass:iconClass widgetClass:widgetClass block:block];
    }
}

%hook SBIconController
- (void)iconTapped:(id)arg1 {
    %orig;
    [[IconTransparencyManager sharedInstance] userDidInteract];
}
%end

%hook SBIconListView
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    %orig;
    [[IconTransparencyManager sharedInstance] userDidInteract];
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    %orig;
    if (!decelerate) {
        [[IconTransparencyManager sharedInstance] scheduleTransparency];
    }
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    %orig;
    [[IconTransparencyManager sharedInstance] scheduleTransparency];
}
- (void)layoutSubviews {
    %orig;
    IconTransparencyManager *mgr = [IconTransparencyManager sharedInstance];
    if (mgr.isTransparent) {
        double alpha = [mgr configuredAlpha];
        for (UIView *sub in self.subviews) {
            Class iconViewClass   = NSClassFromString(@"SBIconView");
            Class widgetViewClass = NSClassFromString(@"SBIconWidgetView");
            if ((iconViewClass && [sub isKindOfClass:iconViewClass]) ||
                (widgetViewClass && [sub isKindOfClass:widgetViewClass])) {
                sub.alpha = alpha;
            }
        }
    }
}
%end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    [[IconTransparencyManager sharedInstance] scheduleTransparency];
}
%end
