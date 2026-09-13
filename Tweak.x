#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIApplication *app = [UIApplication sharedApplication];
        NSLog(@"[TEST] app = %@", app);
    });
}
%end
