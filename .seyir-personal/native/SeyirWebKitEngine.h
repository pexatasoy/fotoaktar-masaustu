#import "SeyirBrowserController.h"

NS_ASSUME_NONNULL_BEGIN
/// Personal-device build only: WebKit is not a public supported tvOS API.
/// This adapter must not be represented as App Store compliant.
@interface SeyirWebKitEngine : NSObject <SeyirBrowserEngine>
@property(nonatomic,weak,nullable) SeyirBrowserController *controller;
@property(nonatomic,readonly) BOOL available;
- (instancetype)initPrivate:(BOOL)privateMode;
- (void)evaluateForTesting:(NSString *)script completion:(void (^)(id _Nullable, NSError * _Nullable))completion;
- (void)loadHTMLForTesting:(NSString *)html;
@end
NS_ASSUME_NONNULL_END
