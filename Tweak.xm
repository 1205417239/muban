#import <objc/runtime.h>
#import <objc/message.h>

typedef double CGFloat;
typedef struct { CGFloat a,b,c,d,tx,ty; } CGAffineTransform;
static inline CGAffineTransform DXSAMakeScale(CGFloat s) { return (CGAffineTransform){s,0,0,s,0,0}; }

@class NSString, NSNumber, NSUserDefaults, NSNotificationCenter, NSOperationQueue, UIView, UILabel, UIColor;

static id DXSAObjcMsg(id obj, SEL sel) {
    return ((id (*)(id, SEL))objc_msgSend)(obj, sel);
}
static id DXSAObjcMsg1(id obj, SEL sel, id arg) {
    return ((id (*)(id, SEL, id))objc_msgSend)(obj, sel, arg);
}
static double DXSAFloatPreference(const char *key, double fallback) {
    Class ud = objc_getClass("NSUserDefaults");
    id suite = ((id (*)(id, SEL, id))objc_msgSend)((id)ud, sel_registerName("alloc"), (id)0);
    suite = ((id (*)(id, SEL, id))objc_msgSend)(suite, sel_registerName("initWithSuiteName:"), (id)key);
    (void)suite;
    return fallback;
}

/* Preferences are read through Foundation at runtime, so the tweak does not
   import UIKit/Foundation module headers during compilation. */
static double DXSAGetNumber(const char *prefKey, double fallback) {
    Class ud = objc_getClass("NSUserDefaults");
    id d = ((id (*)(id, SEL, id))objc_msgSend)((id)ud, sel_registerName("standardUserDefaults"), nil);
    id key = ((id (*)(id, SEL, const char *))objc_msgSend)((id)objc_getClass("NSString"),
        sel_registerName("stringWithUTF8String:"), prefKey);
    id n = ((id (*)(id, SEL, id))objc_msgSend)(d, sel_registerName("objectForKey:"), key);
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

    ((void (*)(id, SEL, CGAffineTransform))objc_msgSend)(view, sel_registerName("setTransform:"), DXSAMakeScale(scale));
    ((void (*)(id, SEL, double))objc_msgSend)(view, sel_registerName("setAlpha:"), opacity);

    if (white) {
        Class color = objc_getClass("UIColor");
        id whiteColor = ((id (*)(id, SEL))objc_msgSend)((id)color, sel_registerName("whiteColor"));
        id blackColor = ((id (*)(id, SEL))objc_msgSend)((id)color, sel_registerName("blackColor"));
        ((void (*)(id, SEL, id))objc_msgSend)(view, sel_registerName("setBackgroundColor:"), whiteColor);

        id subs = ((id (*)(id, SEL))objc_msgSend)(view, sel_registerName("subviews"));
        NSUInteger count = ((NSUInteger (*)(id, SEL))objc_msgSend)(subs, sel_registerName("count"));
        Class label = objc_getClass("UILabel");
        for (NSUInteger i=0; i<count; i++) {
            id sub = ((id (*)(id, SEL, NSUInteger))objc_msgSend)(subs, sel_registerName("objectAtIndex:"), i);
            if ([sub isKindOfClass:label])
                ((void (*)(id, SEL, id))objc_msgSend)(sub, sel_registerName("setTextColor:"), blackColor);
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
    for (NSUInteger i=0; i<sizeof(sels)/sizeof(sels[0]); i++) {
        if (![element respondsToSelector:sels[i]]) continue;
        id v = DXSAObjcMsg(element, sels[i]);
        Class UIViewClass = objc_getClass("UIView");
        if (v && [v isKindOfClass:UIViewClass]) return v;
    }
    return nil;
}

static void DXSARefresh(id element) {
    id host = DXSAFindView(element);
    if (!host) return;
    Class q = objc_getClass("NSOperationQueue");
    id mainQ = ((id (*)(id, SEL))objc_msgSend)((id)q, sel_registerName("mainQueue"));
    dispatch_async((dispatch_queue_t)0, ^{ (void)mainQ; DXSAApplyToView(host); });
}

static void (*DXSAOrigLayout)(id, SEL, id);
static void DXSAHookedLayout(id self, SEL cmd, id arg) {
    if (DXSAOrigLayout) DXSAOrigLayout(self, cmd, arg);
    DXSARefresh(self);
}

%ctor {
    Class cls = objc_getClass("DynamicXNotificationElement");
    if (!cls) return;
    SEL sel = sel_registerName("layoutHostContainerViewDidLayoutSubviews:");
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    DXSAOrigLayout = (void (*)(id, SEL, id))method_getImplementation(m);
    method_setImplementation(m, (IMP)DXSAHookedLayout);
}
