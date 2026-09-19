#import <objc/runtime.h>
#import <objc/message.h>
#import <objc/objc.h>
#import <objc/NSObjCRuntime.h>
#import <dispatch/dispatch.h>
#include <stdarg.h>
#include <stdio.h>
#include <time.h>

// DynamicXStandardAdjust 1.0.38 — runtime diagnostic build.
// Diagnostic only: no size, alpha, color, transform, or frame changes.
// Logs are written to /var/mobile/DynamicXStandardAdjust.log.

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
static FILE *gLog = NULL;

static void DXSALog(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);

    time_t now = time(NULL);
    struct tm tmv;
    localtime_r(&now, &tmv);
    char stamp[32];
    strftime(stamp, sizeof(stamp), "%Y-%m-%d %H:%M:%S", &tmv);

    if (!gLog) {
        gLog = fopen("/var/mobile/DynamicXStandardAdjust.log", "a");
    }

    if (gLog) {
        fprintf(gLog, "[%s] [DXSA38] ", stamp);
        vfprintf(gLog, fmt, ap);
        fprintf(gLog, "\n");
        fflush(gLog);
    }

    va_end(ap);
}

static void DXSAInitLog(void) {
    if (!gLog) gLog = fopen("/var/mobile/DynamicXStandardAdjust.log", "a");
    DXSALog("===== DynamicXStandardAdjust 1.0.38 DIAGNOSTIC START =====");
    DXSALog("LOG_PATH=/var/mobile/DynamicXStandardAdjust.log");
}

static id DXSAUserDefaults(void) {
    Class UD = objc_getClass("NSUserDefaults");
    if (!UD) { DXSALog("NSUserDefaults class missing"); return nil; }
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
    DXSALog("PREFS scale=%ld opacity=%ld white=%d", (long)scale, (long)opacity, white);
}

static void DXSAReportClass(void) {
    Class c = objc_getClass("DynamicXNotificationElement");
    if (!c) {
        DXSALog("CLASS DynamicXNotificationElement=MISSING");
        return;
    }
    DXSALog("CLASS DynamicXNotificationElement=%p", c);
    SEL update = sel_registerName("updateLayout");
    SEL outsets = sel_registerName("preferredEdgeOutsetsForLayoutMode:suggestedOutsets:maximumOutsets:");
    SEL leading = sel_registerName("leadingView");
    SEL provider = sel_registerName("viewProvider");
    DXSALog("METHODS update=%d outsets=%d leading=%d provider=%d",
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
        DXSALog("updateLayout HIT #%d self=%p leading=%d provider=%d view=%p viewClass=%s",
                gUpdateHits, self, leading, provider, view, view ? class_getName(object_getClass(view)) : "nil");
        DXSAReportPrefs();
    }
    if (gOriginalUpdate) gOriginalUpdate(self, _cmd);
}

static DXSAInsets DXSAOutsetsHook(id self, SEL _cmd, NSInteger mode, DXSAInsets suggested, DXSAInsets maximum) {
    gOutsetsHits++;
    if (gOutsetsHits <= 5 || (gOutsetsHits % 50) == 0) {
        DXSALog("OUTSETS HIT #%d self=%p mode=%ld suggested=(%.2f %.2f %.2f %.2f) maximum=(%.2f %.2f %.2f %.2f)",
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
        if (gInstallAttempts <= 20) DXSALog("INSTALL attempt #%d: class missing", gInstallAttempts);
        return;
    }
    DXSAReportClass();

    if (!gHookedUpdate) {
        Method m = class_getInstanceMethod(C, sel_registerName("updateLayout"));
        if (m) {
            gOriginalUpdate = (DXSAUpdateIMP)method_getImplementation(m);
            method_setImplementation(m, (IMP)DXSAUpdateHook);
            gHookedUpdate = YES;
            DXSALog("HOOKED updateLayout original=%p", gOriginalUpdate);
        } else {
            DXSALog("updateLayout Method=MISSING");
        }
    }

    if (!gHookedOutsets) {
        Method m = class_getInstanceMethod(C, sel_registerName("preferredEdgeOutsetsForLayoutMode:suggestedOutsets:maximumOutsets:"));
        if (m) {
            gOriginalOutsets = (DXSAOutsetsIMP)method_getImplementation(m);
            method_setImplementation(m, (IMP)DXSAOutsetsHook);
            gHookedOutsets = YES;
            DXSALog("HOOKED preferredEdgeOutsets original=%p", gOriginalOutsets);
        } else {
            DXSALog("preferredEdgeOutsets Method=MISSING");
        }
    }
}

%ctor {
    @autoreleasepool {
        DXSAInitLog();
        DXSAReportPrefs();
        DXSAReportClass();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ DXSAInstall(); });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ DXSAInstall(); });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ DXSAInstall(); });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            DXSALog("FINAL STATUS hookedUpdate=%d hookedOutsets=%d updateHits=%d outsetsHits=%d installAttempts=%d",
                    gHookedUpdate, gHookedOutsets, gUpdateHits, gOutsetsHits, gInstallAttempts);
        });
    }
}
