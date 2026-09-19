#import <objc/runtime.h>
#import <objc/message.h>
#import <objc/objc.h>
#import <objc/NSObjCRuntime.h>

static BOOL DXSAIsKindOfClass(id obj, Class cls) {
    if (!obj || !cls) return NO;
    return ((BOOL (*)(id, SEL, Class))objc_msgSend)(
        obj, sel_registerName("isKindOfClass:"), cls);
}

static BOOL DXSAWhiteEnabled(void) {
    Class UD = objc_getClass("NSUserDefaults");
    if (!UD) return NO;

    id prefs = ((id (*)(id, SEL))objc_msgSend)(UD, sel_registerName("standardUserDefaults"));
    if (!prefs) return NO;

    return ((BOOL (*)(id, SEL, id))objc_msgSend)(
        prefs, sel_registerName("boolForKey:"), @"WhiteStyleEnabled");
}

static id DXSAWhiteColor(void) {
    Class C = objc_getClass("UIColor");
    if (!C) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(C, sel_registerName("whiteColor"));
}

static id DXSABlackColor(void) {
    Class C = objc_getClass("UIColor");
    if (!C) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(C, sel_registerName("blackColor"));
}

static void DXSASetBackground(id view, id color) {
    if (view && color)
        ((void (*)(id, SEL, id))objc_msgSend)(
            view, sel_registerName("setBackgroundColor:"), color);
}

static void DXSASetTextColor(id view, id color) {
    if (view && color)
        ((void (*)(id, SEL, id))objc_msgSend)(
            view, sel_registerName("setTextColor:"), color);
}

%group DXSA_GainMap

%hook _SBGainMapView

- (void)layoutSubviews {
    %orig;

    if (!DXSAWhiteEnabled()) return;

    id superview = ((id (*)(id, SEL))objc_msgSend)(
        self, sel_registerName("superview"));

    Class gain = objc_getClass("_SBSystemApertureGainMapView");
    if (!DXSAIsKindOfClass(superview, gain)) return;

    id white = DXSAWhiteColor();
    DXSASetBackground(self, white);

    id subviews = ((id (*)(id, SEL))objc_msgSend)(
        self, sel_registerName("subviews"));
    NSUInteger count = ((NSUInteger (*)(id, SEL))objc_msgSend)(
        subviews, sel_registerName("count"));

    Class label = objc_getClass("UILabel");
    id black = DXSABlackColor();

    for (NSUInteger i = 0; i < count; i++) {
        id v = ((id (*)(id, SEL, NSUInteger))objc_msgSend)(
            subviews, sel_registerName("objectAtIndex:"), i);

        if (DXSAIsKindOfClass(v, label))
            DXSASetTextColor(v, black);
    }
}

%end
%end

%group DXSA_ApertureContainer

%hook SBSystemApertureContainerView

- (void)setBackgroundColor:(id)color {
    if (DXSAWhiteEnabled()) {
        id white = DXSAWhiteColor();
        if (white) {
            %orig(white);
            return;
        }
    }
    %orig(color);
}

%end
%end

%ctor {
    @autoreleasepool {
        %init(DXSA_GainMap);
        %init(DXSA_ApertureContainer);
    }
}
