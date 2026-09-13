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

        // ============ 总开关 ============
        PSSpecifier *masterGroup = [PSSpecifier groupSpecifierWithName:@""];
        [specs addObject:masterGroup];

        PSSpecifier *enabledSwitch = [PSSpecifier preferenceSpecifierNamed:@"启用插件"
                                                                    target:self
                                                                       set:@selector(setPreferenceValue:specifier:)
                                                                       get:@selector(readPreferenceValue:)
                                                                    detail:nil
                                                                      cell:PSSwitchCell
                                                                      edit:nil];
        [enabledSwitch setProperty:@"enabled" forKey:@"key"];
        [enabledSwitch setProperty:@YES forKey:@"default"];
        [specs addObject:enabledSwitch];

        // ============ 透明化设置 ============
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
        if ([key isEqualToString:@"enabled"]) return @YES;
    }
    return value;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    NSMutableDictionary *dict = [[self loadPrefsDict] mutableCopy];
    dict[key] = value;
    [self savePrefsDict:dict];
}

@end
