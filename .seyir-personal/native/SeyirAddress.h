#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// Converts an address or search phrase into an HTTP(S) URL. Never runs script URLs.
FOUNDATION_EXPORT NSURL * _Nullable SeyirResolveAddress(NSString *input);
NS_ASSUME_NONNULL_END
