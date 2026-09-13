#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

%ctor {
    // 只写一行文件，不做任何其他事
    [@"hello" writeToFile:@"/var/mobile/Library/Preferences/tweak_test.txt"
               atomically:YES
                 encoding:NSUTF8StringEncoding
                    error:nil];
}
