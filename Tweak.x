#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// C 函数递归，不用 block
static void setIconAlpha(UIView *view, Class iconClass, double alpha) {
    if (!view) return;
    if ([view isKindOfClass:iconClass]) {
        view.alpha = alpha;
    }
    for (UIView *sub in view.subviews) {
        setIconAlpha(sub, iconClass, alpha);
    }
}

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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

        Class iconClass = objc_getClass("SBIconView");
        if (!iconClass) return;

        setIconAlpha(keyWindow, iconClass, 0.3);

        [@"done" writeToFile:@"/var/mobile/Library/Preferences/alpha_done.txt"
                   atomically:YES
                     encoding:NSUTF8StringEncoding
                        error:nil];
    });
}
