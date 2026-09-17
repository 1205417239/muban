#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSMutableArray<NSString *> *KLHistory;
static UIWindow *KLWindow;
static BOOL KLTracking;
static CGPoint KLStart;

static void KLLoad(void) {
    if (!KLHistory) {
        NSArray *saved = [[NSUserDefaults standardUserDefaults] objectForKey:@"KLHistory"];
        KLHistory = saved ? [saved mutableCopy] : [NSMutableArray array];
    }
}

static void KLSave(void) {
    [[NSUserDefaults standardUserDefaults] setObject:KLHistory forKey:@"KLHistory"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static void KLRecord(NSString *text) {
    if (!text.length) return;
    KLLoad();

    [KLHistory removeObject:text];
    [KLHistory insertObject:text atIndex:0];

    if (KLHistory.count > 50)
        [KLHistory removeObjectsInRange:NSMakeRange(50, KLHistory.count - 50)];

    KLSave();
}

static void KLCheckClipboard(void) {
    UIPasteboard *pb = UIPasteboard.generalPasteboard;
    NSString *text = pb.string;
    if (text.length)
        KLRecord(text);
}

static void KLClose(void) {
    [KLWindow removeFromSuperview];
    KLWindow = nil;
}

@interface KLTableDelegate : NSObject <UITableViewDataSource, UITableViewDelegate>
@end

static KLTableDelegate *KLDelegate;

static void KLShow(void) {
    KLLoad();

    UIWindowScene *scene = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if ([s isKindOfClass:UIWindowScene.class] &&
            s.activationState == UISceneActivationStateForegroundActive) {
            scene = (UIWindowScene *)s;
            break;
        }
    }
    if (!scene) return;

    CGRect screen = scene.screen.bounds;

    KLWindow = [[UIWindow alloc] initWithWindowScene:scene];
    KLWindow.frame = CGRectMake(12, screen.size.height - 330, screen.size.width - 24, 300);
    KLWindow.windowLevel = UIWindowLevelAlert + 1;
    KLWindow.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.97];
    KLWindow.layer.cornerRadius = 16;
    KLWindow.clipsToBounds = YES;

    UITableView *table = [[UITableView alloc] initWithFrame:KLWindow.bounds style:UITableViewStylePlain];
    table.backgroundColor = UIColor.clearColor;
    table.separatorStyle = UITableViewCellSeparatorStyleSingleLine;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, table.bounds.size.width - 32, 44)];
    title.text = @"粘贴板历史";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont boldSystemFontOfSize:17];
    [table addSubview:title];

    table.contentInset = UIEdgeInsetsMake(44, 0, 0, 0);
    table.tag = 58131;

    [table registerClass:UITableViewCell.class forCellReuseIdentifier:@"cell"];

    __weak UITableView *weakTable = table;

    table.dataSource = KLDelegate;
    table.delegate = KLDelegate;

    [KLWindow addSubview:table];
    [KLWindow makeKeyAndVisible];

    [table reloadData];
}

@implementation KLTableDelegate
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return KLHistory.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    c.backgroundColor = UIColor.clearColor;
    c.textLabel.textColor = UIColor.whiteColor;
    c.textLabel.numberOfLines = 2;
    c.textLabel.text = KLHistory[indexPath.row];
    return c;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < KLHistory.count)
        UIPasteboard.generalPasteboard.string = KLHistory[indexPath.row];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}
@end

static void KLInstallTimer(void) {
    KLLoad();
    [NSTimer scheduledTimerWithTimeInterval:0.8
                                     target:[NSBlockOperation blockOperationWithBlock:^{
        KLCheckClipboard();
    }]
                                   selector:@selector(main)
                                   userInfo:nil
                                    repeats:YES];
}

%hook UIKeyboardImpl

- (void)insertText:(id)text {
    KLCheckClipboard();
    %orig;
}

%end

%hook UIView

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *t = touches.anyObject;
    CGPoint p = [t locationInView:self];

    if (self.window && self.window.rootViewController &&
        self.bounds.size.height > 300 && p.y > self.bounds.size.height - 70) {
        KLTracking = YES;
        KLStart = p;
    }

    %orig;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (KLTracking) {
        UITouch *t = touches.anyObject;
        CGPoint p = [t locationInView:self];

        if (KLStart.y - p.y > 35) {
            if (!KLDelegate)
                KLDelegate = [KLTableDelegate new];
            KLShow();
        }
        KLTracking = NO;
    }

    %orig;
}

%end

%ctor {
    KLLoad();

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        KLInstallTimer();
    });
}
