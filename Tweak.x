#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static void dumpClasses(UIView *view, int depth, NSMutableString *result) {
    if (depth > 10 || !view) return;
    NSString *indent = [@"" stringByPaddingToLength:depth * 2 withString:@" " startingAtIndex:0];
    [result appendFormat:@"%@%@\n", indent, NSStringFromClass([view class])];
    for (UIView *sub in view.subviews) {
        dumpClasses(sub, depth + 1, result);
    }
}

%ctor {
    // 插件加载时先写个标记
    [@"tweak loaded" writeToFile:@"/var/mobile/Library/Preferences/tweak_loaded.txt"
                       atomically:YES
                         encoding:NSUTF8StringEncoding
                            error:nil];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSMutableString *result = [NSMutableString string];
        [result appendString:@"========== DUMP START ==========\n"];

        UIWindow *keyWindow = nil;
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            for (UIWindow *w in ws.windows) {
                if (w.isKeyWindow) { keyWindow = w; break; }
            }
            if (keyWindow) break;
        }

        if (keyWindow) {
            [result appendFormat:@"keyWindow = %@\n", NSStringFromClass([keyWindow class])];
            dumpClasses(keyWindow, 0, result);
        } else {
            [result appendString:@"keyWindow is nil\n"];
            // 列出所有 window
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (![scene isKindOfClass:[UIWindowScene class]]) continue;
                UIWindowScene *ws = (UIWindowScene *)scene;
                for (UIWindow *w in ws.windows) {
                    [result appendFormat:@"window: %@ isKey=%d\n", NSStringFromClass([w class]), w.isKeyWindow];
                }
            }
        }

        [result appendString:@"========== DUMP END ==========\n"];

        // 写入文件
        [result writeToFile:@"/var/mobile/Library/Preferences/icondump.txt"
                 atomically:YES
                   encoding:NSUTF8StringEncoding
                      error:nil];
    });
}
