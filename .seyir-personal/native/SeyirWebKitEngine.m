#import "SeyirWebKitEngine.h"
#import <dlfcn.h>

#if !SEYIR_PERSONAL_BUILD
#error The unsupported tvOS WebKit adapter is restricted to an explicit personal build.
#endif

// These are ordinary WebKit selectors, declared locally because the public SDK
// marks their tvOS use unavailable. Their spelling and use are not concealed.
@protocol SeyirWebView <NSObject>
@property(nonatomic,weak) id navigationDelegate;
@property(nonatomic,weak) id UIDelegate;
@property(nonatomic,readonly) NSURL *URL;
@property(nonatomic,readonly) NSString *title;
@property(nonatomic,readonly) BOOL canGoBack;
- (id)initWithFrame:(CGRect)frame configuration:(id)configuration;
- (id)loadRequest:(NSURLRequest *)request;
- (id)goBack;
- (id)reload;
- (void)stopLoading;
- (void)pauseAllMediaPlaybackWithCompletionHandler:(void (^)(void))completion;
- (void)evaluateJavaScript:(NSString *)script completionHandler:(void (^)(id,NSError *))completion;
@end

@interface SeyirContentSurface : UIView
@end
@implementation SeyirContentSurface
- (BOOL)canBecomeFocused { return YES; }
@end
@protocol SeyirConfiguration <NSObject>
@property(nonatomic) NSUInteger mediaTypesRequiringUserActionForPlayback;
@property(nonatomic) BOOL allowsInlineMediaPlayback;
@property(nonatomic,readonly) id userContentController;
@end
@protocol SeyirUserContentController <NSObject>
- (void)addScriptMessageHandler:(id)handler name:(NSString *)name;
- (void)removeScriptMessageHandlerForName:(NSString *)name;
- (void)addUserScript:(id)script;
@end
@protocol SeyirUserScript <NSObject>
- (id)initWithSource:(NSString *)source injectionTime:(NSInteger)time forMainFrameOnly:(BOOL)mainOnly;
@end

@interface SeyirMessageProxy : NSObject
@property(nonatomic,weak) SeyirWebKitEngine *owner;
- (void)userContentController:(id)controller didReceiveScriptMessage:(id)message;
@end
@interface SeyirWebKitEngine ()
@property(nonatomic,strong) UIView *container;
@property(nonatomic,strong) id<SeyirWebView> webView;
@property(nonatomic,strong) SeyirMessageProxy *messageProxy;
@property(nonatomic,strong) id<SeyirUserContentController> userContent;
@property(nonatomic,readwrite) BOOL available;
- (void)receiveMessage:(id)message;
@end

@implementation SeyirMessageProxy
- (void)userContentController:(id)controller didReceiveScriptMessage:(id)message { [self.owner receiveMessage:message]; }
@end

@implementation SeyirWebKitEngine
- (instancetype)init {
    if ((self=[super init])) {
        _container=[SeyirContentSurface new];_container.backgroundColor=UIColor.blackColor;
        dlopen("/System/Library/Frameworks/WebKit.framework/WebKit",RTLD_LAZY|RTLD_LOCAL);
        Class cls=NSClassFromString(@"WKWebView");
        Class configClass=NSClassFromString(@"WKWebViewConfiguration");
        if (!cls || !configClass) return self;
        id<SeyirConfiguration> config=[configClass new];
        config.mediaTypesRequiringUserActionForPlayback=0;
        config.allowsInlineMediaPlayback=YES;
        _userContent=config.userContentController;
        _messageProxy=[SeyirMessageProxy new];_messageProxy.owner=self;
        [_userContent addScriptMessageHandler:_messageProxy name:@"seyirInput"];
        NSString *path=[NSBundle.mainBundle pathForResource:@"remote" ofType:@"js"];
        NSString *script=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        if(script.length) {
            id<SeyirUserScript> userScript=[NSClassFromString(@"WKUserScript") alloc];
            userScript=[userScript initWithSource:script injectionTime:1 forMainFrameOnly:YES];
            [_userContent addUserScript:userScript];
        }
        _webView=[(id<SeyirWebView>)[cls alloc] initWithFrame:CGRectZero configuration:config];
        _webView.navigationDelegate=self;_webView.UIDelegate=self;
        UIView *view=(UIView *)_webView;view.translatesAutoresizingMaskIntoConstraints=NO;
        [_container addSubview:view];
        [NSLayoutConstraint activateConstraints:@[[view.topAnchor constraintEqualToAnchor:_container.topAnchor],[view.leadingAnchor constraintEqualToAnchor:_container.leadingAnchor],[view.trailingAnchor constraintEqualToAnchor:_container.trailingAnchor],[view.bottomAnchor constraintEqualToAnchor:_container.bottomAnchor]]];
        _available=YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(suspend) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}
- (UIView *)contentView { return self.container; }
- (void)dealloc { [self.userContent removeScriptMessageHandlerForName:@"seyirInput"];[[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)navigate:(NSURL *)url {
    if(!self.available) { [self.controller showPageError:@"Bu tvOS sürümünde yerel tarayıcı motoru kullanılamıyor."];return; }
    if(![@[@"http",@"https"] containsObject:url.scheme.lowercaseString] || !url.host.length) return;
    [self.webView loadRequest:[NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30]];
}
- (void)goBack { [self.webView goBack]; }
- (void)reload { [self.webView reload]; }
- (void)stop { [self.webView stopLoading];[self.controller setPageLoading:NO]; }
- (void)run:(NSString *)script { [self.webView evaluateJavaScript:script completionHandler:nil]; }
- (void)pauseMedia {
    if([self.webView respondsToSelector:@selector(pauseAllMediaPlaybackWithCompletionHandler:)]) [self.webView pauseAllMediaPlaybackWithCompletionHandler:nil];
    else [self run:@"document.querySelectorAll('video,audio').forEach(m=>m.pause())"];
}
- (void)suspend { [self stop];[self pauseMedia]; }
- (void)togglePlayback { [self run:@"window.__seyirRemote?.togglePlayback()"]; }
- (void)enterVideoFullscreen { [self run:@"(()=>{const v=[...document.querySelectorAll('video')].sort((a,b)=>b.clientWidth*b.clientHeight-a.clientWidth*a.clientHeight)[0]; if(v){if(v.webkitEnterFullscreen)v.webkitEnterFullscreen();else if(v.requestFullscreen)v.requestFullscreen().catch(()=>{});}})()"]; }
- (void)moveFocusX:(NSInteger)x y:(NSInteger)y { [self run:[NSString stringWithFormat:@"window.__seyirRemote?.move(%ld,%ld)",(long)x,(long)y]]; }
- (void)activateFocusedElement { [self run:@"window.__seyirRemote?.activate()"]; }
- (void)setFocusedText:(NSString *)text {
    NSData *data=[NSJSONSerialization dataWithJSONObject:@[text] options:0 error:nil];
    NSString *json=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [self run:[NSString stringWithFormat:@"window.__seyirRemote?.setText((%@)[0])",json]];
}
- (void)receiveMessage:(id)message {
    id body=[message valueForKey:@"body"];
    if(![body isKindOfClass:NSDictionary.class]) return;
    NSString *value=[body[@"value"] isKindOfClass:NSString.class] ? body[@"value"] : @"";
    if(value.length>8192) value=[value substringToIndex:8192];
    [self.controller requestTextInput:value secure:[body[@"secure"] boolValue]];
}
- (void)webView:(id<SeyirWebView>)view didStartProvisionalNavigation:(id)navigation { [self.controller setPageLoading:YES]; }
- (void)webView:(id<SeyirWebView>)view didFinishNavigation:(id)navigation {
    [self.controller setPageLoading:NO];
    if(view.URL) [self.controller didNavigateToURL:view.URL title:view.title ?: view.URL.host canGoBack:view.canGoBack];
}
- (void)webView:(id)view didFailProvisionalNavigation:(id)navigation withError:(NSError *)error {
    if(error.code==NSURLErrorCancelled) return;
    // WebKit's 204 is a media plug-in handoff, not a failed page.
    if([error.domain isEqualToString:@"WebKitErrorDomain"] && error.code==204) { [self.controller setPageLoading:NO];return; }
    [self.controller showPageError:error.localizedDescription];
}
- (void)webView:(id)view didFailNavigation:(id)navigation withError:(NSError *)error { [self webView:view didFailProvisionalNavigation:navigation withError:error]; }
- (void)webViewWebContentProcessDidTerminate:(id)view { [self.controller showPageError:@"Sayfanın işlemi kapandı. Yenile tuşuyla tekrar açabilirsin."]; }
- (void)webView:(id)view decidePolicyForNavigationAction:(id)action decisionHandler:(void (^)(NSInteger))handler {
    NSURLRequest *request=[action valueForKey:@"request"];
    NSString *scheme=request.URL.scheme.lowercaseString;
    handler([@[@"http",@"https",@"about"] containsObject:scheme] ? 1 : 0);
}
- (void)webView:(id)view decidePolicyForNavigationResponse:(id)navigationResponse decisionHandler:(void (^)(NSInteger))handler {
    NSURLResponse *response=[navigationResponse valueForKey:@"response"];
    NSString *mime=response.MIMEType.lowercaseString;
    BOOL mainFrame=[[navigationResponse valueForKey:@"forMainFrame"] boolValue];
    BOOL media=[mime hasPrefix:@"video/"] || [mime hasPrefix:@"audio/"] || [@[@"application/vnd.apple.mpegurl",@"application/x-mpegurl"] containsObject:mime];
    if(mainFrame && media) {
        handler(0);
        NSURL *url=response.URL;
        [self.controller didNavigateToURL:url title:url.lastPathComponent canGoBack:self.webView.canGoBack];
        dispatch_async(dispatch_get_main_queue(),^{[self.controller playMediaURL:url];});
    } else handler(1);
}
- (id)webView:(id)view createWebViewWithConfiguration:(id)configuration forNavigationAction:(id)action windowFeatures:(id)features {
    // One page at a time: open a user-activated new-window link in this page.
    if([[action valueForKey:@"navigationType"] integerValue]==0) {
        NSURLRequest *request=[action valueForKey:@"request"];
        [self navigate:request.URL];
    }
    return nil;
}
- (void)evaluateForTesting:(NSString *)script completion:(void (^)(id,NSError *))completion { [self.webView evaluateJavaScript:script completionHandler:completion]; }
@end
