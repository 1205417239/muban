#import <objc/runtime.h>
#import <objc/message.h>
#import <objc/objc.h>
#import <objc/NSObjCRuntime.h>
#import <UIKit/UIKit.h>

static id DXSAUserDefaults(void) {
    Class UD = objc_getClass("NSUserDefaults");
    if (!UD) return nil;

    id obj = ((id (*)(id, SEL))objc_msgSend)(
        (id)UD, sel_registerName("standardUserDefaults"));
    if (!obj) return nil;

    Class objectClass = objc_getClass("NSUserDefaults");
    id suite = ((id (*)(id, SEL, id))objc_msgSend)(
        (id)objectClass, sel_registerName("alloc"));
    if (!suite) return obj;

    suite = ((id (*)(id, SEL, id))objc_msgSend)(
        suite, sel_registerName("initWithSuiteName:"),
        @"com.dynamicx.standardadjust");
    return suite ?: obj;
}

static NSInteger DXSAInteger(id prefs, id key, NSInteger fallback) {
    if (!prefs) return fallback;
    NSInteger v = ((NSInteger (*)(id, SEL, id))objc_msgSend)(
        prefs, sel_registerName("integerForKey:"), key);
    return v ? v : fallback;
}

static BOOL DXSAWhiteEnabled(void) {
    id prefs = DXSAUserDefaults();
    if (!prefs) return NO;
    return ((BOOL (*)(id, SEL, id))objc_msgSend)(
        prefs, sel_registerName("boolForKey:"), @"WhiteStyleEnabled");
}

static CGFloat DXSAScale(void) {
    id prefs = DXSAUserDefaults();
    NSInteger p = DXSAInteger(prefs, @"OverallScalePercent", 100);
    if (p < 60) p = 60;
    if (p > 160) p = 160;
    return ((CGFloat)p) / 100.0;
}

static BOOL DXSAIsKindOfClass(id obj, Class cls) {
    if (!obj || !cls) return NO;
    return ((BOOL (*)(id, SEL, Class))objc_msgSend)(
        obj, sel_registerName("isKindOfClass:"), cls);
}

static id DXSAColor(SEL selector) {
    Class C = objc_getClass("UIColor");
    if (!C) return nil;
    return ((id (*)(id, SEL))objc_msgSend)((id)C, selector);
}

static void DXSASetColor(id view, SEL setter, id color) {
    if (view && color)
        ((void (*)(id, SEL, id))objc_msgSend)(view, setter, color);
}

/*
 * Color path: DynamicX uses the system aperture gain-map view for the
 * visual surface. Keep the hook at the system layer, but only when the
 * DynamicX preference is enabled.
 */
%group DXSA_GainMap
%hook _SBGainMapView

- (void)layoutSubviews {
    %orig;
    if (!DXSAWhiteEnabled()) return;

    id superview = ((id (*)(id, SEL))objc_msgSend)(
        self, sel_registerName("superview"));
    Class gain = objc_getClass("_SBSystemApertureGainMapView");
    if (!DXSAIsKindOfClass(superview, gain)) return;

    id white = DXSAColor(sel_registerName("whiteColor"));
    DXSASetColor(self, sel_registerName("setBackgroundColor:"), white);

    id subviews = ((id (*)(id, SEL))objc_msgSend)(
        self, sel_registerName("subviews"));
    NSUInteger count = ((NSUInteger (*)(id, SEL))objc_msgSend)(
        subviews, sel_registerName("count"));

    Class label = objc_getClass("UILabel");
    id black = DXSAColor(sel_registerName("blackColor"));

    for (NSUInteger i = 0; i < count; i++) {
        id v = ((id (*)(id, SEL, NSUInteger))objc_msgSend)(
            subviews, sel_registerName("objectAtIndex:"), i);
        if (DXSAIsKindOfClass(v, label))
            DXSASetColor(v, sel_registerName("setTextColor:"), black);
    }
}
%end
%end

%group DXSA_ApertureContainer
%hook SBSystemApertureContainerView

- (void)setBackgroundColor:(id)color {
    if (DXSAWhiteEnabled()) {
        id white = DXSAColor(sel_registerName("whiteColor"));
        if (white) {
            %orig(white);
            return;
        }
    }
    %orig(color);
}
%end
%end

/*
 * Size path: hook DynamicX's own geometry setters instead of forcing the
 * final SBSystemApertureContainerView frame. This lets DynamicX remain in
 * control of its layout chain.
 */
%group DXSA_NotificationElement

%hook DynamicXNotificationElement

- (void)setExpwidth:(CGFloat)value {
    CGFloat s = DXSAScale();
    %orig(value * s);
}

- (void)setMiniwidth:(CGFloat)value {
    CGFloat s = DXSAScale();
    %orig(value * s);
}

- (void)setMiniheight:(CGFloat)value {
    CGFloat s = DXSAScale();
    %orig(value * s);
}

- (void)updateLayout {
    %orig;
}

%end
%end

%ctor {
    @autoreleasepool {
        if (objc_getClass("_SBGainMapView"))
            %init(DXSA_GainMap);

        if (objc_getClass("SBSystemApertureContainerView"))
            %init(DXSA_ApertureContainer);

        if (objc_getClass("DynamicXNotificationElement"))
            %init(DXSA_NotificationElement);
    }
}
