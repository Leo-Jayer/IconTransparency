#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <notify.h>

#define PREFS_PATH @"/var/mobile/Library/Preferences/com.yourname.icontransparency.plist"

@interface IconTransparencyPrefsListController : PSListController
@end

@implementation IconTransparencyPrefsListController

- (id)specifiers {
    if (_specifiers == nil) {
        NSMutableArray *specs = [NSMutableArray array];

        PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"透明化设置"];
        [group setProperty:@"桌面静止指定秒数后，图标渐变透明。" forKey:@"footerText"];
        [specs addObject:group];

        // 透明度滑块：0% 不透明，100% 全透明
        PSSpecifier *alpha = [PSSpecifier preferenceSpecifierNamed:@"透明度"
                                                            target:self
                                                               set:@selector(setPreferenceValue:specifier:)
                                                               get:@selector(readPreferenceValue:)
                                                            detail:nil
                                                              cell:PSSliderCell
                                                              edit:nil];
        [alpha setProperty:@"iconTransparency" forKey:@"key"];
        [alpha setProperty:@0.0 forKey:@"min"];
        [alpha setProperty:@1.0 forKey:@"max"];
        [alpha setProperty:@0.9 forKey:@"default"];
        [alpha setProperty:@YES forKey:@"showValue"];
        [specs addObject:alpha];

        // 静止延迟滑块：1~10 秒
        PSSpecifier *delay = [PSSpecifier preferenceSpecifierNamed:@"静止时间"
                                                            target:self
                                                               set:@selector(setPreferenceValue:specifier:)
                                                               get:@selector(readPreferenceValue:)
                                                            detail:nil
                                                              cell:PSSliderCell
                                                              edit:nil];
        [delay setProperty:@"transparencyDelay" forKey:@"key"];
        [delay setProperty:@1 forKey:@"min"];
        [delay setProperty:@10 forKey:@"max"];
        [delay setProperty:@3 forKey:@"default"];
        [delay setProperty:@YES forKey:@"showValue"];
        [specs addObject:delay];

        // 注销按钮
        PSSpecifier *group2 = [PSSpecifier groupSpecifierWithName:@"应用设置"];
        [group2 setProperty:@"修改设置后需注销 SpringBoard 才能生效。" forKey:@"footerText"];
        [specs addObject:group2];

        PSSpecifier *respringBtn = [PSSpecifier preferenceSpecifierNamed:@"注销生效"
                                                                   target:self
                                                                      set:nil
                                                                      get:nil
                                                                   detail:nil
                                                                     cell:PSButtonCell
                                                                     edit:nil];
        [respringBtn setProperty:@"respring" forKey:@"action"];
        [respringBtn setProperty:@YES forKey:@"enabled"];
        [specs addObject:respringBtn];

        _specifiers = specs;
    }
    return _specifiers;
}

- (NSDictionary *)loadPrefsDict {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PREFS_PATH];
    return dict ?: @{};
}

- (void)savePrefsDict:(NSDictionary *)dict {
    [dict writeToFile:PREFS_PATH atomically:YES];
    notify_post("com.yourname.icontransparency/prefsChanged");
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    NSDictionary *dict = [self loadPrefsDict];
    id value = dict[key];
    if (!value) {
        if ([key isEqualToString:@"transparencyDelay"]) return @3;
        if ([key isEqualToString:@"iconTransparency"]) return @0.9;
    }
    return value;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    NSMutableDictionary *dict = [[self loadPrefsDict] mutableCopy];
    dict[key] = value;
    [self savePrefsDict:dict];
}

- (void)respring {
    // 方式 1：通过 SBUIController 注销
    Class sbuic = NSClassFromString(@"SBUIController");
    if (sbuic) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id controller = [sbuic performSelector:NSSelectorFromString(@"sharedInstance")];
        if (controller && [controller respondsToSelector:NSSelectorFromString(@"rebootApplication:withReason:")]) {
            [controller performSelector:NSSelectorFromString(@"rebootApplication:withReason:")
                             withObject:nil
                             withObject:@"IconTransparency respring"];
        }
        #pragma clang diagnostic pop
    }
}

@end
