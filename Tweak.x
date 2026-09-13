#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    // 什么都不做
}
%end
