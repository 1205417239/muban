#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

static NSString *DXSA38LogPath(void) {
    return @"/var/mobile/DynamicXStandardAdjust.log";
}

static void DXSA38Log(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);

    NSString *line = [NSString stringWithFormat:@"[DXSA38SCAN] %@\n", s];
    NSString *path = DXSA38LogPath();

    @try {
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!fh) {
            [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
            fh = [NSFileHandle fileHandleForWritingAtPath:path];
        }
        [fh seekToEndOfFile];
        [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    } @catch (__unused id e) {}
}

static BOOL DXSA38Match(NSString *name) {
    NSString *s = [name lowercaseString];
    NSArray *keys = @[
        @"dynamicx",
        @"dynamic",
        @"notification",
        @"aperture",
        @"element",
        @"island"
    ];

    for (NSString *k in keys) {
        if ([s containsString:k]) return YES;
    }
    return NO;
}

static BOOL DXSA38InterestingMethod(NSString *name) {
    NSString *s = [name lowercaseString];
    NSArray *keys = @[
        @"layout",
        @"frame",
        @"bounds",
        @"alpha",
        @"opacity",
        @"background",
        @"update",
        @"notification",
        @"view",
        @"outset"
    ];

    for (NSString *k in keys) {
        if ([s containsString:k]) return YES;
    }
    return NO;
}

static void DXSA38ScanRuntime(void) {
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);

    DXSA38Log(@"========== RUNTIME SCAN START ==========");
    DXSA38Log(@"classCount=%u", count);

    unsigned int matched = 0;

    for (unsigned int i = 0; i < count; i++) {
        Class cls = classes[i];
        if (!cls) continue;

        const char *cn = class_getName(cls);
        if (!cn) continue;

        NSString *name = [NSString stringWithUTF8String:cn];
        if (!DXSA38Match(name)) continue;

        matched++;
        DXSA38Log(@"CLASS[%u] %@", matched, name);

        unsigned int mc = 0;
        Method *methods = class_copyMethodList(cls, &mc);

        NSMutableArray *interesting = [NSMutableArray array];

        for (unsigned int j = 0; j < mc; j++) {
            SEL sel = method_getName(methods[j]);
            if (!sel) continue;

            NSString *mn = NSStringFromSelector(sel);
            if (DXSA38InterestingMethod(mn)) {
                [interesting addObject:mn];
            }
        }

        free(methods);

        if (interesting.count) {
            [interesting sortUsingSelector:@selector(compare:)];
            DXSA38Log(@"  METHODS %@", [interesting componentsJoinedByString:@" | "]);
        }
    }

    free(classes);

    DXSA38Log(@"matchedClasses=%u", matched);
    DXSA38Log(@"========== RUNTIME SCAN END ==========");
}

%ctor {
    @autoreleasepool {
        DXSA38Log(@"scanner loaded");

        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
            dispatch_get_main_queue(),
            ^{
                DXSA38ScanRuntime();
            }
        );
    }
}
