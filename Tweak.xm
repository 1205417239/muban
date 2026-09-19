#import <UIKit/UIKit.h>

@interface _SBGainMapView : UIView
@end

@interface _SBSystemApertureGainMapView : UIView
@end

@interface SBSystemApertureContainerView : UIView
@end

static BOOL DXSAWhiteEnabled(void) {
    NSUserDefaults *prefs =
        [[NSUserDefaults alloc] initWithSuiteName:@"com.dynamicx.standardadjust"];

    if (!prefs) return YES;

    if ([prefs objectForKey:@"WhiteStyleEnabled"] == nil)
        return YES;

    return [prefs boolForKey:@"WhiteStyleEnabled"];
}

static void DXSAApplyWhiteToView(UIView *view) {
    if (!view || !DXSAWhiteEnabled()) return;

    view.backgroundColor = UIColor.whiteColor;

    for (UIView *subview in view.subviews) {
        DXSAApplyWhiteToView(subview);
    }
}

/*
 * This patch follows the public DynamicNotLand approach:
 * the real System Aperture gain-map view is captured from
 * _SBSystemApertureGainMapView -> _SBGainMapView.
 *
 * We intentionally patch the real SpringBoard Aperture view instead
 * of DynamicXNotificationElement.
 */
%hook _SBGainMapView

- (void)layoutSubviews {
    %orig;

    if ([self.superview isMemberOfClass:%c(_SBSystemApertureGainMapView)]) {
        if (DXSAWhiteEnabled()) {
            self.backgroundColor = UIColor.whiteColor;
        }
    }
}

%end

/*
 * Also patch the real Aperture container after DynamicX has laid it out.
 * This is deliberately limited to the white-background option.
 */
%hook SBSystemApertureContainerView

- (void)setBackgroundColor:(UIColor *)color {
    if (DXSAWhiteEnabled()) {
        %orig(UIColor.whiteColor);
    } else {
        %orig(color);
    }
}

%end

%ctor {
    @autoreleasepool {
        %init(_SBGainMapView);
        %init(SBSystemApertureContainerView);
    }
}
