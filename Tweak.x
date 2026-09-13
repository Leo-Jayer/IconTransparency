#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// 偏好设置路径 (rootless，与你设置面板写入路径保持一致)
#define PREFS_PATH @"/var/mobile/Library/Preferences/com.yourname.icontransparency.plist"

// 默认配置
static CGFloat gDelaySeconds = 3.0;
static CGFloat gTargetAlpha = 0.2;
static BOOL gEnabled = YES;

// 读取偏好设置
static void loadPreferences() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PREFS_PATH];
    if (prefs) {
        gEnabled      = prefs[@"enabled"] ? [prefs[@"enabled"] boolValue] : YES;
        gDelaySeconds = prefs[@"delay"]   ? [prefs[@"delay"]   floatValue] : 3.0;
        gTargetAlpha  = prefs[@"alpha"]   ? [prefs[@"alpha"]   floatValue] : 0.2;
    }
    if (gDelaySeconds < 0.5) gDelaySeconds = 0.5;
    if (gDelaySeconds > 60)  gDelaySeconds = 60;
    if (gTargetAlpha < 0.0)  gTargetAlpha = 0.0;
    if (gTargetAlpha > 1.0)  gTargetAlpha = 1.0;
}

static void prefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    loadPreferences();
}

// 关联对象 key
static const void *kFadeTimerKey = &kFadeTimerKey;

@interface SBIconView : UIView
@end

%hook SBIconView

// 图标出现在窗口时启动定时器
- (void)didMoveToWindow {
    %orig;
    if (!gEnabled) return;

    // 取消旧定时器
    NSTimer *oldTimer = objc_getAssociatedObject(self, kFadeTimerKey);
    if (oldTimer) {
        [oldTimer invalidate];
        objc_setAssociatedObject(self, kFadeTimerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    // 先恢复不透明
    self.alpha = 1.0;

    // 启动新定时器
    __weak SBIconView *weakSelf = self;
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:gDelaySeconds
                                                     repeats:NO
                                                       block:^(NSTimer *t) {
        __strong SBIconView *strongSelf = weakSelf;
        if (!strongSelf || !gEnabled) return;
        [UIView animateWithDuration:0.8
                              delay:0
                            options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            strongSelf.alpha = gTargetAlpha;
        } completion:nil];
    }];
    objc_setAssociatedObject(self, kFadeTimerKey, timer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// 触摸图标：恢复不透明，取消定时器
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    if (!gEnabled) return;

    NSTimer *oldTimer = objc_getAssociatedObject(self, kFadeTimerKey);
    if (oldTimer) {
        [oldTimer invalidate];
        objc_setAssociatedObject(self, kFadeTimerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    [UIView animateWithDuration:0.3
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.alpha = 1.0;
    } completion:nil];
}

// 触摸结束/取消：重新开始计时
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    if (!gEnabled) return;
    [self didMoveToWindow];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    if (!gEnabled) return;
    [self didMoveToWindow];
}

// 从窗口移除时清理定时器
- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig;
    if (!newWindow) {
        NSTimer *oldTimer = objc_getAssociatedObject(self, kFadeTimerKey);
        if (oldTimer) {
            [oldTimer invalidate];
            objc_setAssociatedObject(self, kFadeTimerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}

%end

// ============ 滑动桌面恢复不透明 ============
// 不 hook SBIconListView 的滚动方法，改为监听 SBIconController 的滚动通知方法
// 这个方法是 SpringBoard 内部用来通知图标列表开始滚动的，比直接 hook UIScrollViewDelegate 安全
@interface SBIconController : NSObject
- (void)iconListDidBeginScrolling:(id)arg1;
- (void)iconListDidEndScrolling:(id)arg1;
@end

%hook SBIconController

- (void)iconListDidBeginScrolling:(id)arg1 {
    %orig;
    // 广播：让所有图标恢复不透明
    [[NSNotificationCenter defaultCenter] postNotificationName:@"IconTransparencyRestore" object:nil];
}

- (void)iconListDidEndScrolling:(id)arg1 {
    %orig;
    // 滚动结束后，图标会在 touchesEnded 或 didMoveToWindow 里重新启动计时
    // 这里不需要额外操作
}

%end

// 让每个图标监听恢复通知
%hook SBIconView

- (void)didMoveToWindow_Notification {
    // 占位，实际逻辑在下面的 %ctor 里用通知监听实现
}

%end

// ============ 构造函数 ============
%ctor {
    loadPreferences();

    // 监听设置变化
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        prefsChanged,
        CFSTR("com.yourname.icontransparency/prefsChanged"),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );
}
