#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface SeyirLibrary : NSObject
@property(nonatomic,readonly) NSArray<NSDictionary<NSString *,NSString *> *> *favorites;
@property(nonatomic,readonly) NSArray<NSDictionary<NSString *,NSString *> *> *history;
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults;
- (void)recordVisit:(NSURL *)url title:(NSString *)title;
- (BOOL)isFavorite:(NSURL *)url;
- (void)toggleFavorite:(NSURL *)url title:(NSString *)title;
- (void)clearHistory;
@end
NS_ASSUME_NONNULL_END
