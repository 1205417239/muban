#import <UIKit/UIKit.h>

static BOOL DXSAWhiteEnabled(void) {
    NSUserDefaults *p = [[NSUserDefaults alloc] initWithSuiteName:@"com.dynamicx.standardadjust"];
    return p ? [p boolForKey:@"WhiteStyleEnabled"] : NO;
}

%group DXSA_GainMap
%hook _SBGainMapView
- (void)layoutSubviews {
    %orig;
    if (!DXSAWhiteEnabled()) return;
    UIView *sv = self.superview;
    if (sv && [sv isKindOfClass:%c(_SBSystemApertureGainMapView)]) {
        self.backgroundColor = [UIColor whiteColor];
        for (UIView *v in self.subviews)
            if ([v isKindOfClass:[UILabel class]])
                ((UILabel *)v).textColor = [UIColor blackColor];
    }
}
%end
%end

%group DXSA_ApertureContainer
%hook SBSystemApertureContainerView
- (void)setBackgroundColor:(UIColor *)color {
    if (DXSAWhiteEnabled()) %orig([UIColor whiteColor]);
    else %orig(color);
}
%end
%end

%ctor {
    @autoreleasepool {
        %init(DXSA_GainMap);
        %init(DXSA_ApertureContainer);
    }
}
