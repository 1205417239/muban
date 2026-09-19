#import <objc/runtime.h>
#import <objc/message.h>
#import <objc/objc.h>
#import <objc/NSObjCRuntime.h>
#import <dispatch/dispatch.h>

typedef double CGFloat;
typedef struct { CGFloat top; CGFloat left; CGFloat bottom; CGFloat right; } DXSAInsets;
typedef struct { CGFloat a,b,c,d,tx,ty; } DXSATransform;

typedef void (*DXSAUpdateIMP)(id, SEL);
typedef DXSAInsets (*DXSAOutsetsIMP)(id, SEL, NSInteger, DXSAInsets, DXSAInsets);
static DXSAUpdateIMP gOriginalUpdate = NULL;
static DXSAOutsetsIMP gOriginalOutsets = NULL;
static BOOL gHooked = NO;

static id DXSAUserDefaults(void) {
    Class UD = objc_getClass("NSUserDefaults");
    if (!UD) return nil;
    id obj = ((id (*)(id, SEL))objc_msgSend)((id)UD, sel_registerName("standardUserDefaults"));
    if (!obj) return nil;
    id suite = ((id (*)(id, SEL, id))objc_msgSend)((id)UD, sel_registerName("alloc"));
    if (!suite) return obj;
    suite = ((id (*)(id, SEL, id))objc_msgSend)(suite, sel_registerName("initWithSuiteName:"), @"com.dynamicx.standardadjust");
    return suite ?: obj;
}

static NSInteger DXSAInteger(id prefs, id key, NSInteger fallback) {
    if (!prefs) return fallback;
    NSInteger v = ((NSInteger (*)(id, SEL, id))objc_msgSend)(prefs, sel_registerName("integerForKey:"), key);
    return v ? v : fallback;
}

static CGFloat DXSAScale(void) {
    id prefs = DXSAUserDefaults();
    NSInteger p = DXSAInteger(prefs, @"OverallScalePercent", 100);
    if (p < 60) p = 60;
    if (p > 160) p = 160;
    return ((CGFloat)p) / 100.0;
}

static CGFloat DXSAOpacity(void) {
    id prefs = DXSAUserDefaults();
    NSInteger p = DXSAInteger(prefs, @"OpacityPercent", 100);
    if (p < 10) p = 10;
    if (p > 100) p = 100;
    return ((CGFloat)p) / 100.0;
}

static BOOL DXSAWhiteEnabled(void) {
    id prefs = DXSAUserDefaults();
    if (!prefs) return NO;
    return ((BOOL (*)(id, SEL, id))objc_msgSend)(prefs, sel_registerName("boolForKey:"), @"WhiteStyleEnabled");
}

static id DXSAColor(SEL selector) {
    Class C = objc_getClass("UIColor");
    if (!C) return nil;
    return ((id (*)(id, SEL))objc_msgSend)((id)C, selector);
}

static void DXSAApplyToView(id view) {
    if (!view) return;
    SEL setTransform = sel_registerName("setTransform:");
    SEL setAlpha = sel_registerName("setAlpha:");
    CGFloat s = DXSAScale();
    DXSATransform t = {s, 0, 0, s, 0, 0};
    ((void (*)(id, SEL, DXSATransform))objc_msgSend)(view, setTransform, t);
    ((void (*)(id, SEL, CGFloat))objc_msgSend)(view, setAlpha, DXSAOpacity());

    if (DXSAWhiteEnabled()) {
        id white = DXSAColor(sel_registerName("whiteColor"));
        if (white) ((void (*)(id, SEL, id))objc_msgSend)(view, sel_registerName("setBackgroundColor:"), white);
    }
}

static void DXSAUpdateHook(id self, SEL _cmd) {
    if (gOriginalUpdate) gOriginalUpdate(self, _cmd);

    id view = nil;
    SEL leading = sel_registerName("leadingView");
    if (((BOOL (*)(id, SEL, SEL))objc_msgSend)(self, sel_registerName("respondsToSelector:"), leading))
        view = ((id (*)(id, SEL))objc_msgSend)(self, leading);

    if (!view) {
        SEL provider = sel_registerName("viewProvider");
        if (((BOOL (*)(id, SEL, SEL))objc_msgSend)(self, sel_registerName("respondsToSelector:"), provider))
            view = ((id (*)(id, SEL))objc_msgSend)(self, provider);
    }

    DXSAApplyToView(view);
}

static DXSAInsets DXSAOutsetsHook(id self, SEL _cmd, NSInteger mode, DXSAInsets suggested, DXSAInsets maximum) {
    DXSAInsets r = suggested;
    if (gOriginalOutsets) r = gOriginalOutsets(self, _cmd, mode, suggested, maximum);
    CGFloat s = DXSAScale();
    if (s != 1.0) {
        r.top *= s;
        r.left *= s;
        r.bottom *= s;
        r.right *= s;
    }
    return r;
}

static void DXSAInstall(void) {
    if (gHooked) return;
    Class C = objc_getClass("DynamicXNotificationElement");
    if (!C) return;

    Method update = class_getInstanceMethod(C, sel_registerName("updateLayout"));
    if (update) {
        gOriginalUpdate = (DXSAUpdateIMP)method_getImplementation(update);
        method_setImplementation(update, (IMP)DXSAUpdateHook);
    }

    Method outsets = class_getInstanceMethod(C, sel_registerName("preferredEdgeOutsetsForLayoutMode:suggestedOutsets:maximumOutsets:"));
    if (outsets) {
        gOriginalOutsets = (DXSAOutsetsIMP)method_getImplementation(outsets);
        method_setImplementation(outsets, (IMP)DXSAOutsetsHook);
    }

    gHooked = (gOriginalUpdate || gOriginalOutsets);
}

%group DXSA_GainMap
%hook _SBGainMapView
- (void)layoutSubviews {
    %orig;
    if (!DXSAWhiteEnabled()) return;
    id superview = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("superview"));
    Class gain = objc_getClass("_SBSystemApertureGainMapView");
    if (!superview || !gain) return;
    if (!((BOOL (*)(id, SEL, Class))objc_msgSend)(superview, sel_registerName("isKindOfClass:"), gain)) return;
    id white = DXSAColor(sel_registerName("whiteColor"));
    if (white) ((void (*)(id, SEL, id))objc_msgSend)(self, sel_registerName("setBackgroundColor:"), white);
}
%end
%end

%group DXSA_ApertureContainer
%hook SBSystemApertureContainerView
- (void)setBackgroundColor:(id)color {
    id newColor = color;
    if (DXSAWhiteEnabled()) {
        id white = DXSAColor(sel_registerName("whiteColor"));
        if (white) newColor = white;
    }
    %orig(newColor);
}
%end
%end

%ctor {
    @autoreleasepool {
        if (objc_getClass("_SBGainMapView")) %init(DXSA_GainMap);
        if (objc_getClass("SBSystemApertureContainerView")) %init(DXSA_ApertureContainer);

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            DXSAInstall();
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            DXSAInstall();
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            DXSAInstall();
        });
    }
}
