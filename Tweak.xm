#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

static NSString * const DXSAAppID = @"com.dynamicx.standardadjust";
static NSString * const DXSAChangedNotification = @"com.dynamicx.standardadjust/preferenceschanged";

static CGFloat DXSAFloatPreference(NSString *key, CGFloat fallback) {
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:DXSAAppID];
    NSNumber *n = [d objectForKey:key];
    return n ? n.doubleValue : fallback;
}

static BOOL DXSABoolPreference(NSString *key, BOOL fallback) {
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:DXSAAppID];
    id v = [d objectForKey:key];
    return v ? [v boolValue] : fallback;
}

static UIView *DXSAFindViewWithDynamicXObject(id object) {
    if (!object) return nil;

    SEL selectors[] = {
        @selector(elementHost),
        @selector(layoutHost),
        @selector(leadingView),
        @selector(trailingView),
        @selector(minimalView),
        @selector(detachedMinimalView)
    };

    for (NSUInteger i = 0; i < sizeof(selectors) / sizeof(selectors[0]); i++) {
        SEL sel = selectors[i];
        if (![object respondsToSelector:sel]) continue;
        id value = ((id (*)(id, SEL))objc_msgSend)(object, sel);
        if ([value isKindOfClass:[UIView class]]) return value;
    }
    return nil;
}

static void DXSAApplyToView(UIView *view) {
    if (!view) return;

    CGFloat scale = DXSAFloatPreference(@"OverallScalePercent", 100.0) / 100.0;
    CGFloat opacity = DXSAFloatPreference(@"OpacityPercent", 100.0) / 100.0;
    BOOL white = DXSABoolPreference(@"WhiteStyleEnabled", NO);

    if (scale < 0.6) scale = 0.6;
    if (scale > 1.6) scale = 1.6;
    if (opacity < 0.1) opacity = 0.1;
    if (opacity > 1.0) opacity = 1.0;

    view.transform = CGAffineTransformMakeScale(scale, scale);
    view.alpha = opacity;

    if (white) {
        view.backgroundColor = [UIColor whiteColor];
        // Keep child content readable without forcing global colors.
        for (UIView *subview in view.subviews) {
            if ([subview isKindOfClass:[UILabel class]]) {
                ((UILabel *)subview).textColor = [UIColor blackColor];
            }
        }
    }
}

static void DXSARefreshFromElement(id element) {
    UIView *host = DXSAFindViewWithDynamicXObject(element);
    if (!host) return;

    // Only touch the view when DynamicX's standard notification element is alive.
    dispatch_async(dispatch_get_main_queue(), ^{
        DXSAApplyToView(host);
    });
}

static void (*DXSAOrigLayout)(id, SEL, id) = NULL;
static void DXSAHookedLayout(id self, SEL _cmd, id arg) {
    if (DXSAOrigLayout) DXSAOrigLayout(self, _cmd, arg);
    DXSARefreshFromElement(self);
}

static void DXSAInstallElementHook(void) {
    Class cls = NSClassFromString(@"DynamicXNotificationElement");
    if (!cls) return;

    SEL sel = @selector(layoutHostContainerViewDidLayoutSubviews:);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;

    DXSAOrigLayout = (void (*)(id, SEL, id))method_getImplementation(m);
    method_setImplementation(m, (IMP)DXSAHookedLayout);
}

%ctor {
    @autoreleasepool {
        [[NSNotificationCenter defaultCenter] addObserverForName:DXSAChangedNotification
                                                           object:nil
                                                            queue:[NSOperationQueue mainQueue]
                                                       usingBlock:^(NSNotification *note) {
            // New preferences are applied on the next DynamicX layout pass.
        }];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            DXSAInstallElementHook();
        });
    }
}
