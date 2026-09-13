#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static NSString *const kDelayKey  = @"transparencyDelay";
static NSString *const kAlphaKey  = @"iconTransparency";

@interface IconTransparencyManager : NSObject
+ (instancetype)sharedInstance;
- (void)startOnce;
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

- (void)startOnce {
    double delay = 3.0;
    NSNumber *d = [[NSUserDefaults standardUserDefaults] objectForKey:kDelayKey];
    if (d) delay = [d doubleValue];

    double alpha = 0.3;
    NSNumber *a = [[NSUserDefaults standardUserDefaults] objectForKey:kAlphaKey];
    if (a) alpha = [a doubleValue];

    // 延迟到 SpringBoard 完全启动后再操作
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 再等用户设置的延迟时间
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = nil;
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (![scene isKindOfClass:[UIWindowScene class]]) continue;
                UIWindowScene *ws = (UIWindowScene *)scene;
                for (UIWindow *w in ws.windows) {
                    if (w.isKeyWindow) { keyWindow = w; break; }
                }
                if (keyWindow) break;
            }
            if (!keyWindow) return;

            Class iconClass = NSClassFromString(@"SBIconView");
            if (!iconClass) return;

            [self traverse:keyWindow iconClass:iconClass alpha:alpha];
        });
    });
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
    [[IconTransparencyManager sharedInstance] startOnce];
}
%end
