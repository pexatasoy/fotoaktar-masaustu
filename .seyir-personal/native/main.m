#import "SeyirBrowserController.h"
#import "SeyirWebKitEngine.h"
#import "SeyirTennisView.h"

@interface SeyirAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic,weak) SeyirWebKitEngine *engine;
@property(nonatomic,strong) SeyirBrowserController *browser;
@end
@implementation SeyirAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    SeyirWebKitEngine *engine=[SeyirWebKitEngine new];self.engine=engine;
    self.browser=[[SeyirBrowserController alloc] initWithEngine:engine];
    self.engine.controller=self.browser;
    self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController=self.browser;
    [self.window makeKeyAndVisible];
#if SEYIR_DIAGNOSTICS
    NSArray *args=NSProcessInfo.processInfo.arguments;
    if([args containsObject:@"--test-tennis"] || [args containsObject:@"--test-tennis-court"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC),dispatch_get_main_queue(),^{
            [self.browser performSelector:NSSelectorFromString(@"showTennis")];
            SeyirTennisView *tennis=[self.browser valueForKey:@"tennis"];
            tennis.courtBackground=[args containsObject:@"--test-tennis-court"];
            [tennis swing];
            NSLog(@"SEYIR_TEST tennis attached=%d court=%d",tennis.window!=nil,tennis.courtBackground);
        });
    }
    if([args containsObject:@"--test-controls"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{
            [self.browser prepareDiagnosticPage];
            NSString *html=[NSString stringWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"controls" ofType:@"html"] encoding:NSUTF8StringEncoding error:nil];
            [self.engine loadHTMLForTesting:html];
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,7*NSEC_PER_SEC),dispatch_get_main_queue(),^{
            [self.engine evaluateForTesting:@"(()=>{const r=document.querySelector('#text').getBoundingClientRect();__seyirRemote.pointerClick((r.x+r.width/2)/innerWidth,(r.y+r.height/2)/innerHeight);return true})()" completion:^(id value,NSError *error){}];
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,9*NSEC_PER_SEC),dispatch_get_main_queue(),^{
            [self.engine setFocusedText:@"tenis & maç"];
            [self.browser.presentedViewController dismissViewControllerAnimated:NO completion:nil];
            [self.engine evaluateForTesting:@"(()=>{const r=document.querySelector('#counter').getBoundingClientRect();__seyirRemote.pointerClick((r.x+r.width/2)/innerWidth,(r.y+r.height/2)/innerHeight);return true})()" completion:^(id value,NSError *error){}];
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,12*NSEC_PER_SEC),dispatch_get_main_queue(),^{
            [self.engine evaluateForTesting:@"JSON.stringify({text:document.querySelector('#text').value,hits:window.hits||0,remote:!!window.__seyirRemote})" completion:^(id value,NSError *error){NSLog(@"SEYIR_TEST controls=%@ error=%@",value,error);}];
            NSData *data=[NSJSONSerialization dataWithJSONObject:[self.browser privacyDiagnostics] options:0 error:nil];
            NSLog(@"SEYIR_TEST privacy=%@",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            [self.browser prepareDiagnosticPage];[self.browser performSelector:NSSelectorFromString(@"toggleCursor")];
        });
    }
    NSString *url=nil;
    if([args containsObject:@"--test-google"]) url=@"https://www.google.com/search?q=Apple+TV";
    if([args containsObject:@"--test-youtube"]) url=@"https://www.youtube.com/watch?v=aqz-KE-bpKQ";
    if([args containsObject:@"--test-video"]) url=@"https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4";
    if([args containsObject:@"--test-tennis"] || [args containsObject:@"--test-tennis-court"]) url=@"https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4";
    if(url) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{
            [self.browser performSelector:NSSelectorFromString(@"openURL:") withObject:[NSURL URLWithString:url]];
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,15*NSEC_PER_SEC),dispatch_get_main_queue(),^{
            [self.engine evaluateForTesting:@"(()=>{const buttons=[...document.querySelectorAll('button')];const reject=buttons.find(b=>/^(Reject all|Tümünü reddet)$/.test(b.innerText.trim()));if(reject)reject.click();const v=document.querySelector('video');if(v){v.muted=true;v.play().catch(()=>{});}return JSON.stringify({title:document.title,video:!!v})})()" completion:^(id value,NSError *error){NSLog(@"SEYIR_TEST initial=%@ error=%@",value,error);}];
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,25*NSEC_PER_SEC),dispatch_get_main_queue(),^{
            NSData *data=[NSJSONSerialization dataWithJSONObject:[self.browser mediaDiagnostics] options:0 error:nil];
            NSLog(@"SEYIR_TEST nativeMedia=%@",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            [self.engine evaluateForTesting:@"JSON.stringify({title:document.title,ready:document.readyState,video:(()=>{const v=document.querySelector('video');return v?{time:v.currentTime,paused:v.paused,ready:v.readyState,error:v.error?.code,width:v.videoWidth}:null})(),remote:!!window.__seyirRemote})" completion:^(id value,NSError *error){NSLog(@"SEYIR_TEST result=%@ error=%@",value,error);}];
        });
    }
#endif
    return YES;
}
@end
int main(int argc,char *argv[]) { @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(SeyirAppDelegate.class)); } }
