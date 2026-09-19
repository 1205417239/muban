#import <objc/runtime.h>
#import <objc/message.h>
#import <objc/NSObjCRuntime.h>

typedef unsigned long NSUInteger;

static id DXMsg(id obj, SEL sel) {
    return ((id (*)(id, SEL))objc_msgSend)(obj, sel);
}
static id DXMsg1(id obj, SEL sel, id arg) {
    return ((id (*)(id, SEL, id))objc_msgSend)(obj, sel, arg);
}
static id DXString(const char *s) {
    Class c = objc_getClass("NSString");
    return ((id (*)(id, SEL, const char *))objc_msgSend)
        ((id)c, sel_registerName("stringWithUTF8String:"), s);
}
static BOOL DXWhiteEnabled(void) {
    Class ud = objc_getClass("NSUserDefaults");
    id suite = DXString("com.dynamicx.standardadjust");
    id settings = ((id (*)(id, SEL, id))objc_msgSend)
        ((id)ud, sel_registerName("alloc"), suite);
    settings = ((id (*)(id, SEL, id))objc_msgSend)
        (settings, sel_registerName("initWithSuiteName:"), suite);
    if (!settings) return NO;
    id value = DXMsg1(settings, sel_registerName("objectForKey:"), DXString("WhiteStyleEnabled"));
    return value ? ((BOOL (*)(id, SEL))objc_msgSend)(value, sel_registerName("boolValue")) : NO;
}

static void DXApplyWhiteRecursive(id view) {
    if (!view) return;

    Class UIView = objc_getClass("UIView");
    Class UILabel = objc_getClass("UILabel");
    Class UIColor = objc_getClass("UIColor");

    if (((BOOL (*)(id, SEL, Class))objc_msgSend)(view, sel_registerName("isKindOfClass:"), UIView)) {
        id white = DXMsg((id)UIColor, sel_registerName("whiteColor"));
        id black = DXMsg((id)UIColor, sel_registerName("blackColor"));

        ((void (*)(id, SEL, id))objc_msgSend)
            (view, sel_registerName("setBackgroundColor:"), white);

        if (((BOOL (*)(id, SEL, Class))objc_msgSend)(view, sel_registerName("isKindOfClass:"), UILabel)) {
            ((void (*)(id, SEL, id))objc_msgSend)
                (view, sel_registerName("setTextColor:"), black);
        }

        id subs = DXMsg(view, sel_registerName("subviews"));
        NSUInteger count = ((NSUInteger (*)(id, SEL))objc_msgSend)
            (subs, sel_registerName("count"));

        for (NSUInteger i = 0; i < count; i++) {
            id sub = ((id (*)(id, SEL, NSUInteger))objc_msgSend)
                (subs, sel_registerName("objectAtIndex:"), i);
            DXApplyWhiteRecursive(sub);
        }
    }
}

static void DXRefresh(id element) {
    if (!DXWhiteEnabled()) return;

    Class UIView = objc_getClass("UIView");
    SEL sels[] = {
        sel_registerName("elementHost"),
        sel_registerName("layoutHost"),
        sel_registerName("leadingView"),
        sel_registerName("trailingView"),
        sel_registerName("minimalView"),
        sel_registerName("detachedMinimalView")
    };

    for (NSUInteger i = 0; i < 6; i++) {
        SEL s = sels[i];
        if (!((BOOL (*)(id, SEL, SEL))objc_msgSend)
            (element, sel_registerName("respondsToSelector:"), s)) continue;

        id v = DXMsg(element, s);
        if (v && ((BOOL (*)(id, SEL, Class))objc_msgSend)
            (v, sel_registerName("isKindOfClass:"), UIView)) {
            DXApplyWhiteRecursive(v);
            return;
        }
    }
}

static void (*DXOrigLayout)(id, SEL, id) = NULL;
static void DXHookedLayout(id self, SEL cmd, id arg) {
    if (DXOrigLayout) DXOrigLayout(self, cmd, arg);
    DXRefresh(self);
}

%ctor {
    @autoreleasepool {
        Class cls = objc_getClass("DynamicXNotificationElement");
        if (!cls) return;

        SEL sel = sel_registerName("layoutHostContainerViewDidLayoutSubviews:");
        Method m = class_getInstanceMethod(cls, sel);
        if (!m) return;

        DXOrigLayout = (void (*)(id, SEL, id))method_getImplementation(m);
        method_setImplementation(m, (IMP)DXHookedLayout);
    }
}
