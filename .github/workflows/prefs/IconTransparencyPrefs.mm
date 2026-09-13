#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface IconTransparencyPrefsListController : PSListController
@end

@implementation IconTransparencyPrefsListController

- (id)specifiers {
    if (_specifiers == nil) {
        NSMutableArray *specs = [NSMutableArray array];

        PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"透明化设置"];
        [group setProperty:@"桌面静止数秒后图标与小组件将渐变透明。" forKey:@"footerText"];
        [specs addObject:group];

        PSSpecifier *delay = [PSSpecifier preferenceSpecifierNamed:@"静止延迟（秒）"
                                                            target:self
                                                               set:@selector(setPreferenceValue:specifier:)
                                                               get:@selector(readPreferenceValue:)
                                                            detail:nil
                                                              cell:PSSliderCell
                                                              edit:nil];
        [delay setProperty:@"transparencyDelay" forKey:@"key"];
        [delay setProperty:@0 forKey:@"min"];
        [delay setProperty:@10 forKey:@"max"];
        [specs addObject:delay];

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
        [specs addObject:alpha];

        _specifiers = specs;
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    NSNumber *value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (!value) {
        if ([key isEqualToString:@"transparencyDelay"]) return @3.0;
        if ([key isEqualToString:@"iconTransparency"]) return @0.3;
    }
    return value;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];

    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.yourname.icontransparency/settingschanged"),
        NULL, NULL, YES
    );
}

@end
