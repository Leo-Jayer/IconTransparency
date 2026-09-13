#import "ITSliderCell.h"
#import <Preferences/PSSpecifier.h>
#import <notify.h>

#define PREFS_PATH @"/var/mobile/Library/Preferences/com.yourname.icontransparency.plist"

@interface ITSliderCell () <UITextFieldDelegate>
@property (nonatomic, strong) UILabel *customTitleLabel;
@property (nonatomic, strong) UISlider *customSlider;
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

        // 隐藏父类自带的 titleLabel，避免重复显示
        self.titleLabel.hidden = YES;

        // 标题
        self.customTitleLabel = [[UILabel alloc] init];
        self.customTitleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
        self.customTitleLabel.text = [specifier name];
        self.customTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:self.customTitleLabel];

        // 数值输入框
        self.valueField = [[UITextField alloc] init];
        self.valueField.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        self.valueField.textAlignment = NSTextAlignmentRight;
        self.valueField.keyboardType = UIKeyboardTypeDecimalPad;
        self.valueField.delegate = self;
        self.valueField.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:self.valueField];

        // 滑块
        self.customSlider = [[UISlider alloc] init];
        self.customSlider.minimumValue = self.minValue;
        self.customSlider.maximumValue = self.maxValue;
        [self.customSlider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
        self.customSlider.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:self.customSlider];

        // 布局
        [NSLayoutConstraint activateConstraints:@[
            [self.customTitleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
            [self.customTitleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],

            [self.valueField.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
            [self.valueField.centerYAnchor constraintEqualToAnchor:self.customTitleLabel.centerYAnchor],
            [self.valueField.widthAnchor constraintEqualToConstant:80],

            [self.customSlider.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
            [self.customSlider.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
            [self.customSlider.topAnchor constraintEqualToAnchor:self.customTitleLabel.bottomAnchor constant:8],
            [self.customSlider.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],
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
    self.customSlider.value = self.currentValue;
    [self updateValueText];
}

- (void)updateValueText {
    if ([self.prefsKey isEqualToString:@"iconTransparency"]) {
        self.valueField.text = [NSString stringWithFormat:@"%.0f%%", self.currentValue * 100];
    } else {
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

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
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
        entered = entered / 100.0;
    }
    if (entered < self.minValue) entered = self.minValue;
    if (entered > self.maxValue) entered = self.maxValue;

    self.currentValue = entered;
    [self updateUI];
    [self saveValue];
}

@end
