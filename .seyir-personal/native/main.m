#import "SeyirBrowserController.h"
#import "SeyirWebKitEngine.h"

@interface SeyirAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic,strong) SeyirWebKitEngine *engine;
@property(nonatomic,strong) SeyirBrowserController *browser;
@end
@implementation SeyirAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.engine=[SeyirWebKitEngine new];
    self.browser=[[SeyirBrowserController alloc] initWithEngine:self.engine];
    self.engine.controller=self.browser;
    self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController=self.browser;
    [self.window makeKeyAndVisible];
#if SEYIR_DIAGNOSTICS
    NSArray *args=NSProcessInfo.processInfo.arguments;
    NSString *url=nil;
    if([args containsObject:@"--test-google"]) url=@"https://www.google.com/search?q=Apple+TV";
    if([args containsObject:@"--test-youtube"]) url=@"https://www.youtube.com/watch?v=aqz-KE-bpKQ";
    if([args containsObject:@"--test-video"]) url=@"https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4";
    if(url) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{
            [self.browser performSelector:NSSelectorFromString(@"openURL:") withObject:[NSURL URLWithString:url]];
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,15*NSEC_PER_SEC),dispatch_get_main_queue(),^{
            [self.engine evaluateForTesting:@"(()=>{const buttons=[...document.querySelectorAll('button')];const reject=buttons.find(b=>/^(Reject all|Tümünü reddet)$/.test(b.innerText.trim()));if(reject)reject.click();const v=document.querySelector('video');if(v){v.muted=true;v.play().catch(()=>{});}return JSON.stringify({title:document.title,video:!!v})})()" completion:^(id value,NSError *error){NSLog(@"SEYIR_TEST initial=%@ error=%@",value,error);}];
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,25*NSEC_PER_SEC),dispatch_get_main_queue(),^{
            [self.engine evaluateForTesting:@"JSON.stringify({title:document.title,ready:document.readyState,video:(()=>{const v=document.querySelector('video');return v?{time:v.currentTime,paused:v.paused,ready:v.readyState,error:v.error?.code,width:v.videoWidth}:null})(),remote:!!window.__seyirRemote})" completion:^(id value,NSError *error){NSLog(@"SEYIR_TEST result=%@ error=%@",value,error);}];
        });
    }
#endif
    return YES;
}
@end
int main(int argc,char *argv[]) { @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(SeyirAppDelegate.class)); } }
