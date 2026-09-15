#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@protocol SeyirBrowserEngine <NSObject>
@property(nonatomic,readonly) UIView *contentView;
- (void)navigate:(NSURL *)url;
- (void)goBack;
- (void)reload;
- (void)stop;
- (void)togglePlayback;
- (void)moveFocusX:(NSInteger)x y:(NSInteger)y;
- (void)activateFocusedElement;
- (void)setFocusedText:(NSString *)text;
- (void)enterVideoFullscreen;
@end

@interface SeyirBrowserController : UIViewController
- (instancetype)initWithEngine:(id<SeyirBrowserEngine>)engine;
- (void)didNavigateToURL:(NSURL *)url title:(NSString *)title canGoBack:(BOOL)canGoBack;
- (void)setPageLoading:(BOOL)loading;
- (void)setPageFullscreen:(BOOL)fullscreen;
- (void)showPageError:(NSString *)message;
- (void)requestTextInput:(NSString *)value secure:(BOOL)secure;
@end
NS_ASSUME_NONNULL_END
