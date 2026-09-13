#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// 简单的测试函数，写文件
static void writeTestFile(void) {
    NSString *path = @"/var/mobile/Documents/tweak_test.txt";
    NSDate *now = [NSDate date];
    NSString *content = [NSString stringWithFormat:@"Tweak loaded at %@\n", now];
    [content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

%ctor {
    // 插件加载时直接执行，不 hook 任何方法
    writeTestFile();

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[TEST] 15 seconds elapsed, tweak still alive");
        writeTestFile();
    });
}
