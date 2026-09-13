#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static void modifyIconAlpha(UIView *view, double alpha) {
    if (!view) return;

    // 判断是不是 SBIconView
    Class iconClass = objc_getClass("SBIconView");
    if (iconClass && [view isKindOfClass:iconClass]) {
        view.alpha = alpha;
    }

    // 递归子视图
    for (UIView *sub in view.subviews) {
        modifyIconAlpha(sub, alpha);
    }
}

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 获取 keyWindow
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

        // 修改所有 SBIconView 的 alpha
        modifyIconAlpha(keyWindow, 0.3);

        // 写标记文件
        [@"alpha modified" writeToFile:@"/var/mobile/Library/Preferences/alpha_done.txt"
                           atomically:YES
                             encoding:NSUTF8StringEncoding
                                error:nil];
    });
}
