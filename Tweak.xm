#import <objc/runtime.h>
#import <objc/message.h>
#import <objc/objc.h>
#import <objc/NSObjCRuntime.h>
#import <dispatch/dispatch.h>
#include <stdarg.h>
#include <stdio.h>

// DynamicXStandardAdjust 1.0.37 — runtime diagnostic build.
// This version intentionally DOES NOT change size, alpha, color, transform, or frame.
// It only proves whether the DynamicX classes/methods are present and being called.

typedef double CGFloat;
typedef struct { CGFloat top; CGFloat left; CGFloat bottom; CGFloat right; } DXSAInsets;
typedef DXSAInsets (*DXSAOutsetsIMP)(id, SEL, NSInteger, DXSAInsets, DXSAInsets);
typedef void (*DXSAUpdateIMP)(id, SEL);

static DXSAUpdateIMP gOriginalUpdate = NULL;
static DXSAOutsetsIMP gOriginalOutsets = NULL;
static BOOL gHookedUpdate = NO;
static BOOL gHookedOutsets = NO;
static int gUpdateHits = 0;
static int gOutsetsHits = 0;
static int gInstallAttempts = 0;

static void DXSALog(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    fprintf(stderr, "[DXSA37] ");
    vfprintf(stderr, fmt, ap);
    fprintf(stderr, "\n");
    fflush(stderr);
    va_end(ap);
}

static id DXSAUserDefaults(void) {
    Class UD = objc_getClass("NSUserDefaults");
    if (!UD) { DXSALog("[DXSA36] NSUserDefaults class missing"); return nil; }
    id standard = ((id (*)(id, SEL))objc_msgSend)((id)UD, sel_registerName("standardUserDefaults"));
    id suite = ((id (*)(id, SEL))objc_msgSend)((id)UD, sel_registerName("alloc"));
    if (!suite) return standard;
    suite = ((id (*)(id, SEL, id))objc_msgSend)(suite, sel_registerName("initWithSuiteName:"), @"com.dynamicx.standardadjust");
    return suite ?: standard;
}

static NSInteger DXSAInteger(id prefs, id key, NSInteger fallback) {
    if (!prefs) return fallback;
    NSInteger v = ((NSInteger (*)(id, SEL, id))objc_msgSend)(prefs, sel_registerName("integerForKey:"), key);
    return v ? v : fallback;
}

static void DXSAReportPrefs(void) {
    id p = DXSAUserDefaults();
    NSInteger scale = DXSAInteger(p, @"OverallScalePercent", 100);
    NSInteger opacity = DXSAInteger(p, @"OpacityPercent", 100);
    BOOL white = p ? ((BOOL (*)(id, SEL, id))objc_msgSend)(p, sel_registerName("boolForKey:"), @"WhiteStyleEnabled") : NO;
    DXSALog("[DXSA36] PREFS scale=%ld opacity=%ld white=%d", (long)scale, (long)opacity, white);
}

static void DXSAReportClass(void) {
    Class c = objc_getClass("DynamicXNotificationElement");
    if (!c) {
        DXSALog("[DXSA36] CLASS DynamicXNotificationElement = MISSING");
        return;
    }
    DXSALog("[DXSA36] CLASS DynamicXNotificationElement = %p", c);
    SEL update = sel_registerName("updateLayout");
    SEL outsets = sel_registerName("preferredEdgeOutsetsForLayoutMode:suggestedOutsets:maximumOutsets:");
    SEL leading = sel_registerName("leadingView");
    SEL provider = sel_registerName("viewProvider");
    DXSALog("[DXSA36] METHODS update=%d outsets=%d leading=%d provider=%d",
            class_getInstanceMethod(c, update) != NULL,
            class_getInstanceMethod(c, outsets) != NULL,
            class_getInstanceMethod(c, leading) != NULL,
            class_getInstanceMethod(c, provider) != NULL);
}

static void DXSAUpdateHook(id self, SEL _cmd) {
    gUpdateHits++;
    if (gUpdateHits <= 5 || (gUpdateHits % 50) == 0) {
        BOOL leading = ((BOOL (*)(id, SEL, SEL))objc_msgSend)(self, sel_registerName("respondsToSelector:"), sel_registerName("leadingView"));
        BOOL provider = ((BOOL (*)(id, SEL, SEL))objc_msgSend)(self, sel_registerName("respondsToSelector:"), sel_registerName("viewProvider"));
        id v1 = leading ? ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("leadingView")) : nil;
        id v2 = (!v1 && provider) ? ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("viewProvider")) : nil;
        id view = v1 ?: v2;
        DXSALog("[DXSA36] updateLayout HIT #%d self=%p leading=%d provider=%d view=%p viewClass=%s",
                gUpdateHits, self, leading, provider, view, view ? class_getName(object_getClass(view)) : "nil");
        DXSAReportPrefs();
    }
    if (gOriginalUpdate) gOriginalUpdate(self, _cmd);
}

static DXSAInsets DXSAOutsetsHook(id self, SEL _cmd, NSInteger mode, DXSAInsets suggested, DXSAInsets maximum) {
    gOutsetsHits++;
    if (gOutsetsHits <= 5 || (gOutsetsHits % 50) == 0) {
        DXSALog("[DXSA36] OUTSETS HIT #%d self=%p mode=%ld suggested=(%.2f %.2f %.2f %.2f) maximum=(%.2f %.2f %.2f %.2f)",
                gOutsetsHits, self, (long)mode,
                suggested.top, suggested.left, suggested.bottom, suggested.right,
                maximum.top, maximum.left, maximum.bottom, maximum.right);
    }
    if (gOriginalOutsets) return gOriginalOutsets(self, _cmd, mode, suggested, maximum);
    return suggested;
}

static void DXSAInstall(void) {
    gInstallAttempts++;
    Class C = objc_getClass("DynamicXNotificationElement");
    if (!C) {
        if (gInstallAttempts <= 8) DXSALog("[DXSA36] INSTALL attempt #%d: class missing", gInstallAttempts);
        return;
    }
    DXSAReportClass();

    if (!gHookedUpdate) {
        Method m = class_getInstanceMethod(C, sel_registerName("updateLayout"));
        if (m) {
            gOriginalUpdate = (DXSAUpdateIMP)method_getImplementation(m);
            method_setImplementation(m, (IMP)DXSAUpdateHook);
            gHookedUpdate = YES;
            DXSALog("[DXSA36] HOOKED updateLayout original=%p", gOriginalUpdate);
        }
    }
    if (!gHookedOutsets) {
        Method m = class_getInstanceMethod(C, sel_registerName("preferredEdgeOutsetsForLayoutMode:suggestedOutsets:maximumOutsets:"));
        if (m) {
            gOriginalOutsets = (DXSAOutsetsIMP)method_getImplementation(m);
            method_setImplementation(m, (IMP)DXSAOutsetsHook);
            gHookedOutsets = YES;
            DXSALog("[DXSA36] HOOKED preferredEdgeOutsets original=%p", gOriginalOutsets);
        }
    }
}

%ctor {
    @autoreleasepool {
        DXSALog("[DXSA36] ===== DynamicXStandardAdjust 1.0.37 DIAGNOSTIC START =====");
        DXSAReportPrefs();
        DXSAReportClass();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ DXSAInstall(); });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ DXSAInstall(); });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ DXSAInstall(); });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            DXSALog("[DXSA36] FINAL STATUS hookedUpdate=%d hookedOutsets=%d updateHits=%d outsetsHits=%d", gHookedUpdate, gHookedOutsets, gUpdateHits, gOutsetsHits);
        });
    }
}
