#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static void dumpClasses(UIView *view, int depth) {
    if (depth > 8) return;
    NSString *indent = [@"" stringByPaddingToLength:depth * 2 withString:@" " startingAtIndex:0];
    NSLog(@"[IconDump] %@%@", indent, NSStringFromClass([view class]));
    for (UIView *sub in view.subviews) {
        dumpClasses(sub, depth + 1);
    }
}

static void dumpIconTree(void) {
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
        if (!keyWindow) {
            NSLog(@"[IconDump] keyWindow is nil");
            return;
        }
        NSLog(@"[IconDump] keyWindow = %@", NSStringFromClass([keyWindow class]));
        dumpClasses(keyWindow, 0);
    });
}

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    dumpIconTree();
}
%end
