#import <objc/runtime.h>
#import <objc/message.h>
#import <objc/NSObjCRuntime.h>
#import <dispatch/dispatch.h>

typedef double CGFloat;
typedef struct { CGFloat a,b,c,d,tx,ty; } CGAffineTransform;
static inline CGAffineTransform DXSAMakeScale(CGFloat s) { return (CGAffineTransform){s,0,0,s,0,0}; }

static id DXSAObjcMsg(id obj, SEL sel) {
    return ((id (*)(id, SEL))objc_msgSend)(obj, sel);
}
static id DXSAObjcMsg1(id obj, SEL sel, id arg) {
    return ((id (*)(id, SEL, id))objc_msgSend)(obj, sel, arg);
}

static id DXSAString(const char *value) {
    Class NSStringClass = objc_getClass("NSString");
    return ((id (*)(id, SEL, const char *))objc_msgSend)(
        (id)NSStringClass, sel_registerName("stringWithUTF8String:"), value);
}

static double DXSAGetNumber(const char *prefKey, double fallback) {
    Class ud = objc_getClass("NSUserDefaults");
    id d = DXSAObjcMsg((id)ud, sel_registerName("standardUserDefaults"));
    id key = DXSAString(prefKey);
    id n = DXSAObjcMsg1(d, sel_registerName("objectForKey:"), key);
    return n ? ((double (*)(id, SEL))objc_msgSend)(n, sel_registerName("doubleValue")) : fallback;
}

static BOOL DXSAGetBool(const char *prefKey, BOOL fallback) {
    return DXSAGetNumber(prefKey, fallback ? 1.0 : 0.0) != 0.0;
}

static void DXSAApplyToView(id view) {
    if (!view) return;

    double scale = DXSAGetNumber("OverallScalePercent", 100.0) / 100.0;
    double opacity = DXSAGetNumber("OpacityPercent", 100.0) / 100.0;
    BOOL white = DXSAGetBool("WhiteStyleEnabled", NO);

    if (scale < .6) scale = .6;
    if (scale > 1.6) scale = 1.6;
    if (opacity < .1) opacity = .1;
    if (opacity > 1.0) opacity = 1.0;

    ((void (*)(id, SEL, CGAffineTransform))objc_msgSend)(
        view, sel_registerName("setTransform:"), DXSAMakeScale(scale));
    ((void (*)(id, SEL, double))objc_msgSend)(
        view, sel_registerName("setAlpha:"), opacity);

    if (white) {
        Class color = objc_getClass("UIColor");
        id whiteColor = DXSAObjcMsg((id)color, sel_registerName("whiteColor"));
        id blackColor = DXSAObjcMsg((id)color, sel_registerName("blackColor"));

        DXSAObjcMsg1(view, sel_registerName("setBackgroundColor:"), whiteColor);

        id subs = DXSAObjcMsg(view, sel_registerName("subviews"));
        NSUInteger count = ((NSUInteger (*)(id, SEL))objc_msgSend)(
            subs, sel_registerName("count"));
        Class label = objc_getClass("UILabel");

        for (NSUInteger i = 0; i < count; i++) {
            id sub = ((id (*)(id, SEL, NSUInteger))objc_msgSend)(
                subs, sel_registerName("objectAtIndex:"), i);
            BOOL isLabel = ((BOOL (*)(id, SEL, Class))objc_msgSend)(
                sub, sel_registerName("isKindOfClass:"), label);
            if (isLabel) {
                ((void (*)(id, SEL, id))objc_msgSend)(
                    sub, sel_registerName("setTextColor:"), blackColor);
            }
        }
    }
}

static id DXSAFindView(id element) {
    SEL sels[] = {
        sel_registerName("elementHost"),
        sel_registerName("layoutHost"),
        sel_registerName("leadingView"),
        sel_registerName("trailingView"),
        sel_registerName("minimalView"),
        sel_registerName("detachedMinimalView")
    };

    Class UIViewClass = objc_getClass("UIView");

    for (NSUInteger i = 0; i < sizeof(sels) / sizeof(sels[0]); i++) {
        SEL sel = sels[i];
        BOOL responds = ((BOOL (*)(id, SEL, SEL))objc_msgSend)(
            element, sel_registerName("respondsToSelector:"), sel);
        if (!responds) continue;

        id v = DXSAObjcMsg(element, sel);
        if (!v) continue;

        BOOL isView = ((BOOL (*)(id, SEL, Class))objc_msgSend)(
            v, sel_registerName("isKindOfClass:"), UIViewClass);
        if (isView) return v;
    }

    return nil;
}

static void DXSARefresh(id element) {
    id host = DXSAFindView(element);
    if (!host) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        DXSAApplyToView(host);
    });
}

static void (*DXSAOrigLayout)(id, SEL, id) = NULL;

static void DXSAHookedLayout(id self, SEL cmd, id arg) {
    if (DXSAOrigLayout) DXSAOrigLayout(self, cmd, arg);
    DXSARefresh(self);
}

%ctor {
    @autoreleasepool {
        Class cls = objc_getClass("DynamicXNotificationElement");
        if (!cls) return;

        SEL sel = sel_registerName("layoutHostContainerViewDidLayoutSubviews:");
        Method m = class_getInstanceMethod(cls, sel);
        if (!m) return;

        DXSAOrigLayout = (void (*)(id, SEL, id))method_getImplementation(m);
        method_setImplementation(m, (IMP)DXSAHookedLayout);
    }
}
