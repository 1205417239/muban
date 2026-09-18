#import <objc/runtime.h>
#import <objc/message.h>
#import <objc/NSObjCRuntime.h>
#import <dispatch/dispatch.h>

#ifndef YES
#define YES 1
#define NO 0
#endif

typedef double CGFloat;
typedef unsigned long NSUInteger;
typedef struct { CGFloat a,b,c,d,tx,ty; } CGAffineTransform;
static inline CGAffineTransform DXSAMakeScale(CGFloat s) { return (CGAffineTransform){s,0,0,s,0,0}; }

static id DXSAObjcMsg(id obj, SEL sel) { return ((id (*)(id, SEL))objc_msgSend)(obj, sel); }
static id DXSAObjcMsg1(id obj, SEL sel, id arg) { return ((id (*)(id, SEL, id))objc_msgSend)(obj, sel, arg); }

static id DXSAString(const char *value) {
    Class c = objc_getClass("NSString");
    return ((id (*)(id, SEL, const char *))objc_msgSend)((id)c, sel_registerName("stringWithUTF8String:"), value);
}

static double DXSAGetNumber(const char *key, double fallback) {
    Class cf = objc_getClass("NSUserDefaults");
    id d = DXSAObjcMsg((id)cf, sel_registerName("standardUserDefaults"));
    id k = DXSAString(key);
    id n = DXSAObjcMsg1(d, sel_registerName("objectForKey:"), k);
    if (n) return ((double (*)(id, SEL))objc_msgSend)(n, sel_registerName("doubleValue"));
    Class ns = objc_getClass("NSNumber");
    (void)ns;
    return fallback;
}

static void DXSAApply(id view) {
    if (!view) return;
    double scale = DXSAGetNumber("OverallScalePercent", 100.0) / 100.0;
    double alpha = DXSAGetNumber("OpacityPercent", 100.0) / 100.0;
    if (scale < .6) scale = .6; if (scale > 1.6) scale = 1.6;
    if (alpha < .1) alpha = .1; if (alpha > 1.0) alpha = 1.0;
    ((void (*)(id, SEL, CGAffineTransform))objc_msgSend)(view, sel_registerName("setTransform:"), DXSAMakeScale(scale));
    ((void (*)(id, SEL, double))objc_msgSend)(view, sel_registerName("setAlpha:"), alpha);

    if (DXSAGetNumber("WhiteStyleEnabled", 0.0) != 0.0) {
        Class color = objc_getClass("UIColor");
        id white = DXSAObjcMsg((id)color, sel_registerName("whiteColor"));
        id black = DXSAObjcMsg((id)color, sel_registerName("blackColor"));
        DXSAObjcMsg1(view, sel_registerName("setBackgroundColor:"), white);
        id subs = DXSAObjcMsg(view, sel_registerName("subviews"));
        NSUInteger count = ((NSUInteger (*)(id, SEL))objc_msgSend)(subs, sel_registerName("count"));
        Class label = objc_getClass("UILabel");
        for (NSUInteger i=0; i<count; i++) {
            id sub = ((id (*)(id, SEL, NSUInteger))objc_msgSend)(subs, sel_registerName("objectAtIndex:"), i);
            if (((BOOL (*)(id, SEL, Class))objc_msgSend)(sub, sel_registerName("isKindOfClass:"), label))
                ((void (*)(id, SEL, id))objc_msgSend)(sub, sel_registerName("setTextColor:"), black);
        }
    }
}

static id DXSAFindView(id element) {
    SEL sels[] = { sel_registerName("elementHost"), sel_registerName("layoutHost"), sel_registerName("leadingView"), sel_registerName("trailingView") };
    Class UIViewClass = objc_getClass("UIView");
    for (NSUInteger i=0; i<4; i++) {
        SEL s=sels[i];
        if (!((BOOL (*)(id, SEL, SEL))objc_msgSend)(element, sel_registerName("respondsToSelector:"), s)) continue;
        id v=DXSAObjcMsg(element,s);
        if (v && ((BOOL (*)(id, SEL, Class))objc_msgSend)(v, sel_registerName("isKindOfClass:"), UIViewClass)) return v;
    }
    return nil;
}

static void DXSARefresh(id element) {
    id v=DXSAFindView(element);
    if (!v) return;
    dispatch_async(dispatch_get_main_queue(), ^{ DXSAApply(v); });
}

static void DXSARefreshAll(void) {
    Class cls=objc_getClass("DynamicXNotificationElement");
    if (!cls) return;
    unsigned int n=0; Ivar *iv=class_copyIvarList(cls,&n); (void)iv; if(iv) free(iv);
    // Re-apply through currently visible elements when their layout callbacks run.
}

static void (*DXSAOrigLayout)(id, SEL, id)=NULL;
static void DXSAHookedLayout(id self, SEL cmd, id arg) {
    if (DXSAOrigLayout) DXSAOrigLayout(self,cmd,arg);
    DXSARefresh(self);
}

static void DXSASettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    dispatch_async(dispatch_get_main_queue(), ^{ DXSARefreshAll(); });
}

%ctor {
    @autoreleasepool {
        Class cls=objc_getClass("DynamicXNotificationElement");
        if (cls) {
            SEL sel=sel_registerName("layoutHostContainerViewDidLayoutSubviews:");
            Method m=class_getInstanceMethod(cls,sel);
            if (m) { DXSAOrigLayout=(void(*)(id,SEL,id))method_getImplementation(m); method_setImplementation(m,(IMP)DXSAHookedLayout); }
        }
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, DXSASettingsChanged, CFSTR("com.dynamicx.standardadjust/preferenceschanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    }
}
