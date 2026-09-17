#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString * const KLHistoryKey = @"com.kayoko.lite.history";
static NSInteger const KLMaxHistory = 100;
static CGFloat const KLSwipeHeight = 80.0;
static CGFloat const KLMinSwipe = 35.0;

@interface KLClipboardManager : NSObject
+ (instancetype)shared;
- (void)check;
- (NSArray<NSString *> *)items;
- (void)copyItem:(NSString *)item;
- (void)deleteItemAtIndex:(NSInteger)index;
- (void)clear;
@end

@interface KLClipboardManager ()
@property(nonatomic,strong) NSMutableArray<NSString *> *history;
@property(nonatomic,copy) NSString *lastChangeToken;
@end

@implementation KLClipboardManager

+ (instancetype)shared {
    static KLClipboardManager *m;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ m = [KLClipboardManager new]; });
    return m;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSArray *saved = [[NSUserDefaults standardUserDefaults] objectForKey:KLHistoryKey];
        _history = saved ? [saved mutableCopy] : [NSMutableArray array];
    }
    return self;
}

- (NSArray<NSString *> *)items {
    return [self.history copy];
}

- (void)save {
    [[NSUserDefaults standardUserDefaults] setObject:self.history forKey:KLHistoryKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)check {
    UIPasteboard *pb = [UIPasteboard generalPasteboard];
    NSString *text = pb.string;
    if (!text.length) return;

    NSString *token = [NSString stringWithFormat:@"%lu-%@", (unsigned long)text.length, text];
    if ([token isEqualToString:self.lastChangeToken]) return;
    self.lastChangeToken = token;

    [self.history removeObject:text];
    [self.history insertObject:text atIndex:0];

    if (self.history.count > KLMaxHistory) {
        [self.history removeObjectsInRange:NSMakeRange(KLMaxHistory, self.history.count - KLMaxHistory)];
    }
    [self save];
}

- (void)copyItem:(NSString *)item {
    if (!item.length) return;
    [UIPasteboard generalPasteboard].string = item;
    self.lastChangeToken = [NSString stringWithFormat:@"%lu-%@", (unsigned long)item.length, item];
}

- (void)deleteItemAtIndex:(NSInteger)index {
    if (index < 0 || index >= self.history.count) return;
    [self.history removeObjectAtIndex:index];
    [self save];
}

- (void)clear {
    [self.history removeAllObjects];
    [self save];
}

@end

@interface KLClipboardController : UIViewController <UITableViewDataSource,UITableViewDelegate>
@property(nonatomic,strong) UITableView *tableView;
@end

@implementation KLClipboardController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.98];

    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0,0,self.view.bounds.size.width,52)];
    bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    bar.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16,0,180,52)];
    title.text = @"粘贴板历史";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont boldSystemFontOfSize:18];
    [bar addSubview:title];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(self.view.bounds.size.width-150,0,68,52);
    close.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [close setTitle:@"关闭" forState:UIControlStateNormal];
    [close setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [close addTarget:self action:@selector(closeView) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:close];

    UIButton *clear = [UIButton buttonWithType:UIButtonTypeSystem];
    clear.frame = CGRectMake(self.view.bounds.size.width-76,0,68,52);
    clear.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [clear setTitle:@"清空" forState:UIControlStateNormal];
    [clear setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [clear addTarget:self action:@selector(clearAll) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:clear];

    [self.view addSubview:bar];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0,52,self.view.bounds.size.width,self.view.bounds.size.height-52) style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorColor = [UIColor colorWithWhite:1 alpha:0.12];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [KLClipboardManager.shared items].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *ID = @"KLCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:ID];
        cell.backgroundColor = UIColor.clearColor;
        cell.textLabel.textColor = UIColor.whiteColor;
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:1 alpha:0.45];
        cell.textLabel.numberOfLines = 2;
    }

    NSString *text = [KLClipboardManager.shared items][indexPath.row];
    cell.textLabel.text = text;
    cell.detailTextLabel.text = @"点击复制";
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *items = [KLClipboardManager.shared items];
    if (indexPath.row < items.count) {
        [KLClipboardManager.shared copyItem:items[indexPath.row]];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (style == UITableViewCellEditingStyleDelete) {
        [KLClipboardManager.shared deleteItemAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (void)closeView {
    KLHide();
}

- (void)clearAll {
    [KLClipboardManager.shared clear];
    [self.tableView reloadData];
}

@end

static UIWindow *KLWindow;
static UIViewController *KLRootController;
static NSMutableSet *KLKeyboardWindows;

static void KLHide(void);

static void KLHide(void) {
    [KLWindow resignKeyWindow];
    KLWindow.hidden = YES;
    KLWindow.rootViewController = nil;
    KLWindow = nil;
    KLRootController = nil;
}

static void KLShow(void) {
    [KLClipboardManager.shared check];

    UIWindowScene *scene = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if ([s isKindOfClass:UIWindowScene.class] &&
            s.activationState == UISceneActivationStateForegroundActive) {
            scene = (UIWindowScene *)s;
            break;
        }
    }
    if (!scene) return;

    if (KLWindow) KLHide();

    KLRootController = [KLClipboardController new];
    KLWindow = [[UIWindow alloc] initWithWindowScene:scene];
    KLWindow.frame = scene.coordinateSpace.bounds;
    KLWindow.windowLevel = UIWindowLevelAlert + 1;
    KLWindow.rootViewController = KLRootController;
    KLWindow.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
    KLWindow.hidden = NO;
    [KLWindow makeKeyAndVisible];
}

@interface KLKeyboardGestureTarget : NSObject <UIGestureRecognizerDelegate>
+ (instancetype)shared;
- (void)handleSwipe:(UISwipeGestureRecognizer *)gr;
@end

@implementation KLKeyboardGestureTarget

+ (instancetype)shared {
    static KLKeyboardGestureTarget *t;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ t = [KLKeyboardGestureTarget new]; });
    return t;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
        shouldReceiveTouch:(UITouch *)touch {
    if (touch.window == KLWindow) return NO;
    if (touch.window.hidden || touch.window.alpha <= 0.01) return NO;

    CGPoint p = [touch locationInView:touch.window];
    return p.y >= touch.window.bounds.size.height - 80.0;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    UISwipeGestureRecognizer *swipe = (UISwipeGestureRecognizer *)gestureRecognizer;
    if (swipe.numberOfTouchesRequired != 1) return NO;
    CGPoint p = [swipe locationInView:swipe.view];
    return p.y >= swipe.view.bounds.size.height - 80.0;
}

- (void)handleSwipe:(UISwipeGestureRecognizer *)gr {
    if (gr.state == UIGestureRecognizerStateRecognized && !KLWindow) {
        KLShow();
    }
}

@end

static BOOL KLWindowLooksLikeKeyboard(UIWindow *window) {
    if (!window || window == KLWindow) return NO;

    NSString *name = NSStringFromClass(window.class);
    if ([name containsString:@"UITextEffectsWindow"] ||
        [name containsString:@"UIRemoteKeyboardWindow"] ||
        [name containsString:@"UIKeyboardWindow"]) {
        return YES;
    }

    __block BOOL found = NO;
    void (^scan)(UIView *) = ^(UIView *view) {
        NSString *n = NSStringFromClass(view.class);
        if ([n containsString:@"UIInputSetContainerView"] ||
            [n containsString:@"UIInputSetHostView"] ||
            [n containsString:@"UIKeyboard"] ||
            [n containsString:@"UIKeyboardImpl"]) {
            found = YES;
            return;
        }
        for (UIView *sub in view.subviews) {
            if (found) break;
            scan(sub);
        }
    };
    scan(window);
    return found;
}

static void KLInstallKeyboardGestures(void) {
    if (!KLKeyboardWindows) KLKeyboardWindows = [NSMutableSet set];

    NSMutableArray<UIWindow *> *windows = [NSMutableArray array];
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            [windows addObject:window];
        }
    }

    for (UIWindow *window in windows) {
        if (!KLWindowLooksLikeKeyboard(window)) continue;
        if ([KLKeyboardWindows containsObject:window]) continue;

        UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc]
                                            initWithTarget:KLKeyboardGestureTarget.shared
                                            action:@selector(handleSwipe:)];
        swipe.direction = UISwipeGestureRecognizerDirectionUp;
        swipe.numberOfTouchesRequired = 1;
        swipe.cancelsTouchesInView = NO;
        swipe.delaysTouchesBegan = NO;
        swipe.delaysTouchesEnded = NO;
        swipe.delegate = KLKeyboardGestureTarget.shared;
        [window addGestureRecognizer:swipe];
        [KLKeyboardWindows addObject:window];
    }
}

%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{
        [KLClipboardManager.shared check];

        [NSTimer scheduledTimerWithTimeInterval:0.5
                                         repeats:YES
                                           block:^(NSTimer *timer) {
            [KLClipboardManager.shared check];
            KLInstallKeyboardGestures();
        }];

        KLInstallKeyboardGestures();
    });
}
