#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static void testOneIcon(void) {
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

        Class iconClass = NSClassFromString(@"SBIconView");
        if (!iconClass) return;

        UIView *firstIcon = [self findFirst:keyWindow iconClass:iconClass];
        if (firstIcon) {
            firstIcon.alpha = 0.3;
        }
    });
}

static UIView *findFirst(UIView *view, Class iconClass) {
    if ([view isKindOfClass:iconClass]) return view;
    for (UIView *sub in view.subviews) {
        UIView *found = findFirst(sub, iconClass);
        if (found) return found;
    }
    return nil;
}

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    testOneIcon();
}
%end
