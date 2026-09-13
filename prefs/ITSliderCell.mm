#import "ITSliderCell.h"
#import <notify.h>

#define PREFS_PATH @"/var/mobile/Library/Preferences/com.yourname.icontransparency.plist"

@interface ITSliderCell () <UITextFieldDelegate>
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) UITextField *valueField;
@property (nonatomic, copy) NSString *prefsKey;
@property (nonatomic, assign) double minValue;
@property (nonatomic, assign) double maxValue;
@property (nonatomic, assign) double currentValue;
@end

@implementation ITSliderCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        self.prefsKey = [specifier propertyForKey:@"key"];
        self.minValue = [[specifier propertyForKey:@"min"] doubleValue];
        self.maxValue = [[specifier propertyForKey:@"max"] doubleValue];

        // 标题
        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
        self.titleLabel.text = [specifier name];
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:self.titleLabel];

        // 数值输入框
        self.valueField = [[UITextField alloc] init];
        self.valueField.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        self.valueField.textAlignment = NSTextAlignmentRight;
        self.valueField.keyboardType = UIKeyboardTypeDecimalPad;
        self.valueField.delegate = self;
        self.valueField.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:self.valueField];

        // 滑块
        self.slider = [[UISlider alloc] init];
        self.slider.minimumValue = self.minValue;
        self.slider.maximumValue = self.maxValue;
        [self.slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
        self.slider.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:self.slider];

        // 布局：标题左上，数值右上，滑块在下
        [NSLayoutConstraint activateConstraints:@[
            [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
            [self.titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],

            [self.valueField.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
            [self.valueField.centerYAnchor constraintEqualToAnchor:self.titleLabel.centerYAnchor],
            [self.valueField.widthAnchor constraintEqualToConstant:80],

            [self.slider.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
            [self.slider.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
            [self.slider.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:8],
            [self.slider.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],
        ]];

        // 读取当前值
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PREFS_PATH] ?: @{};
        NSNumber *value = dict[self.prefsKey];
        if (!value) {
            value = [specifier propertyForKey:@"default"];
        }
        self.currentValue = [value doubleValue];
        [self updateUI];
    }
    return self;
}

- (void)updateUI {
    self.slider.value = self.currentValue;
    [self updateValueText];
}

- (void)updateValueText {
    if ([self.prefsKey isEqualToString:@"iconTransparency"]) {
        // 透明度显示为百分比
        self.valueField.text = [NSString stringWithFormat:@"%.0f%%", self.currentValue * 100];
    } else {
        // 静止时间显示为秒
        self.valueField.text = [NSString stringWithFormat:@"%.0fs", self.currentValue];
    }
}

- (void)sliderChanged:(UISlider *)sender {
    self.currentValue = sender.value;
    [self updateValueText];
    [self saveValue];
}

- (void)saveValue {
    NSMutableDictionary *dict = [[NSDictionary dictionaryWithContentsOfFile:PREFS_PATH] mutableCopy] ?: [NSMutableDictionary dictionary];
    dict[self.prefsKey] = @(self.currentValue);
    [dict writeToFile:PREFS_PATH atomically:YES];
    notify_post("com.yourname.icontransparency/prefsChanged");
}

// ============ 点击数值编辑 ============
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    // 去掉 % 和 s 后缀，只保留数字
    NSString *text = textField.text;
    text = [text stringByReplacingOccurrencesOfString:@"%" withString:@""];
    text = [text stringByReplacingOccurrencesOfString:@"s" withString:@""];
    textField.text = text;
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self commitValueFromField];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    [self commitValueFromField];
}

- (void)commitValueFromField {
    double entered = [self.valueField.text doubleValue];
    if ([self.prefsKey isEqualToString:@"iconTransparency"]) {
        // 输入的是百分比
        entered = entered / 100.0;
    }
    if (entered < self.minValue) entered = self.minValue;
    if (entered > self.maxValue) entered = self.maxValue;

    self.currentValue = entered;
    [self updateUI];
    [self saveValue];
}

@end
