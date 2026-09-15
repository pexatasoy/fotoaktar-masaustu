#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@class SeyirBrowserController;
@protocol SeyirBrowserEngine <NSObject>
@property(nonatomic,readonly) UIView *contentView;
@property(nonatomic,weak,nullable) SeyirBrowserController *controller;
@property(nonatomic,readonly) BOOL canGoForward;
@property(nonatomic,readonly) BOOL canGoBack;
- (id<SeyirBrowserEngine>)newEnginePrivate:(BOOL)privateMode;
- (void)navigate:(NSURL *)url;
- (void)goBack;
- (void)goForward;
- (void)reload;
- (void)stop;
- (void)togglePlayback;
- (void)moveFocusX:(NSInteger)x y:(NSInteger)y;
- (void)activateFocusedElement;
- (void)setFocusedText:(NSString *)text;
- (void)enterVideoFullscreen;
- (void)exitVideoFullscreen;
- (void)setInputLocked:(BOOL)locked;
- (void)pauseMedia;
- (void)pointerMoveX:(double)x y:(double)y;
- (void)pointerClickX:(double)x y:(double)y;
- (void)setPageZoom:(double)zoom;
- (void)findText:(NSString *)text completion:(void (^)(BOOL))completion;
- (void)clearWebsiteData:(void (^)(void))completion;
- (void)scrollPageX:(double)x y:(double)y;
@end

@interface SeyirBrowserController : UIViewController
- (instancetype)initWithEngine:(id<SeyirBrowserEngine>)engine;
- (void)didNavigateToURL:(NSURL *)url title:(NSString *)title canGoBack:(BOOL)canGoBack;
- (void)setPageLoading:(BOOL)loading;
- (void)setPageFullscreen:(BOOL)fullscreen;
- (void)showPageError:(NSString *)message;
- (void)requestTextInput:(NSString *)value secure:(BOOL)secure;
- (void)playMediaURL:(NSURL *)url;
- (NSDictionary *)mediaDiagnostics;
- (void)prepareDiagnosticPage;
- (NSDictionary *)privacyDiagnostics;
- (NSDictionary *)sessionDiagnostics;
@end
NS_ASSUME_NONNULL_END
