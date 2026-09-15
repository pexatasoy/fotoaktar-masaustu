#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <dlfcn.h>

@interface Probe : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic,strong) id browser;
@end
@implementation Probe
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = UIColor.blackColor;
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    NSLog(@"SEYIR_PROBE OS=%@", UIDevice.currentDevice.systemVersion);
    for (NSString *path in @[@"/System/Library/Frameworks/WebKit.framework/WebKit", @"/System/Library/PrivateFrameworks/WebKit.framework/WebKit", @"/System/Library/PrivateFrameworks/TVBrowser.framework/TVBrowser"]) {
        void *handle = dlopen(path.UTF8String, RTLD_LAZY | RTLD_LOCAL);
        NSLog(@"SEYIR_PROBE library=%@ loaded=%d", path, handle != NULL);
    }
    for (NSString *name in @[@"WKWebView", @"WKWebViewConfiguration", @"UIWebView", @"TVBrowserViewController"]) {
        NSLog(@"SEYIR_PROBE class=%@ available=%d", name, NSClassFromString(name) != Nil);
    }
    NSArray *args = NSProcessInfo.processInfo.arguments;
    if ([args containsObject:@"--wk"]) {
        Class cls = NSClassFromString(@"WKWebView");
        Class configClass = NSClassFromString(@"WKWebViewConfiguration");
        if (cls && configClass) {
            id config = [configClass new];
            id instance = [cls alloc];
            self.browser = ((id (*)(id, SEL, CGRect, id))objc_msgSend)(instance, NSSelectorFromString(@"initWithFrame:configuration:"), vc.view.bounds, config);
            [vc.view addSubview:(UIView *)self.browser];
            ((id (*)(id, SEL, id, id))objc_msgSend)(self.browser, NSSelectorFromString(@"loadHTMLString:baseURL:"), @"<html><body style='background:#151719;color:white;font:48px sans-serif'><h1>Seyir engine check</h1><script>window.seyirMarker=6*7;</script></body></html>", nil);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                void (^completion)(id, NSError *) = ^(id result, NSError *error) { NSLog(@"SEYIR_PROBE javascript=%@ error=%@", result, error); };
                ((void (*)(id, SEL, id, id))objc_msgSend)(self.browser, NSSelectorFromString(@"evaluateJavaScript:completionHandler:"), @"window.seyirMarker", completion);
            });
        }
    }
    return YES;
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(Probe.class)); }
}
