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

static id DXSASettings(void) {
    Class ud = objc_getClass("NSUserDefaults");
    if (!ud) return nil;

    id instance = DXMsg((id)ud, sel_registerName("alloc"));
    if (!instance) return nil;

    return DXMsg1(instance, sel_registerName("initWithSuiteName:"),
                  DXString("com.dynamicx.standardadjust"));
}

static BOOL DXWhiteEnabled(void) {
    id settings = DXSASettings();
    if (!settings) return NO;

    id value = DXMsg1(settings, sel_registerName("objectForKey:"),
                      DXString("WhiteStyleEnabled"));
    if (!value) return NO;

    return ((BOOL (*)(id, SEL))objc_msgSend)
        (value, sel_registerName("boolValue"));
}

static void DXApplyWhite(id view) {
    if (!view || !DXWhiteEnabled()) return;

    Class UIView = objc_getClass("UIView");
    Class UILabel = objc_getClass("UILabel");
    Class UIColor = objc_getClass("UIColor");
    if (!UIView || !UIColor) return;

    BOOL isView = ((BOOL (*)(id, SEL, Class))objc_msgSend)
        (view, sel_registerName("isKindOfClass:"), UIView);
    if (!isView) return;

    id white = DXMsg((id)UIColor, sel_registerName("whiteColor"));
    id black = DXMsg((id)UIColor, sel_registerName("blackColor"));

    ((void (*)(id, SEL, id))objc_msgSend)
        (view, sel_registerName("setBackgroundColor:"), white);

    if (UILabel &&
        ((BOOL (*)(id, SEL, Class))objc_msgSend)
        (view, sel_registerName("isKindOfClass:"), UILabel)) {
        ((void (*)(id, SEL, id))objc_msgSend)
            (view, sel_registerName("setTextColor:"), black);
    }

    id subs = DXMsg(view, sel_registerName("subviews"));
    if (!subs) return;

    NSUInteger count = ((NSUInteger (*)(id, SEL))objc_msgSend)
        (subs, sel_registerName("count"));

    for (NSUInteger i = 0; i < count; i++) {
        id sub = ((id (*)(id, SEL, NSUInteger))objc_msgSend)
            (subs, sel_registerName("objectAtIndex:"), i);
        DXApplyWhite(sub);
    }
}

static void DXApplyToElement(id element) {
    if (!element || !DXWhiteEnabled()) return;

    SEL leading = sel_registerName("leadingView");
    SEL trailing = sel_registerName("trailingView");

    if (((BOOL (*)(id, SEL, SEL))objc_msgSend)
        (element, sel_registerName("respondsToSelector:"), leading)) {
        DXApplyWhite(DXMsg(element, leading));
    }

    if (((BOOL (*)(id, SEL, SEL))objc_msgSend)
        (element, sel_registerName("respondsToSelector:"), trailing)) {
        DXApplyWhite(DXMsg(element, trailing));
    }
}

static void (*DXOrigLayout)(id, SEL, id) = NULL;

static void DXHookedLayout(id self, SEL cmd, id host) {
    if (DXOrigLayout) DXOrigLayout(self, cmd, host);

    DXApplyToElement(self);

    /* The argument is the actual aperture host used by DynamicX's
       layoutHostContainerViewDidLayoutSubviews: implementation. */
    if (DXWhiteEnabled()) {
        DXApplyWhite(host);
    }
}

%ctor {
    @autoreleasepool {
        Class cls = objc_getClass("DynamicXNotificationElement");
        if (!cls) return;

        SEL sel = sel_registerName("layoutHostContainerViewDidLayoutSubviews:");
        Method method = class_getInstanceMethod(cls, sel);
        if (!method) return;

        DXOrigLayout = (void (*)(id, SEL, id))method_getImplementation(method);
        method_setImplementation(method, (IMP)DXHookedLayout);
    }
}
