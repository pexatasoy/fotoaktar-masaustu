#import "SeyirLibrary.h"

@interface SeyirLibrary ()
@property(nonatomic,strong) NSUserDefaults *defaults;
@end
@implementation SeyirLibrary
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults {
    if ((self=[super init])) _defaults=defaults;
    return self;
}
- (NSArray *)validEntriesForKey:(NSString *)key {
    id saved=[self.defaults objectForKey:key];
    if (![saved isKindOfClass:NSArray.class]) return @[];
    NSMutableArray *valid=[NSMutableArray array];
    for (id item in saved) {
        if (![item isKindOfClass:NSDictionary.class]) continue;
        if (![item[@"url"] isKindOfClass:NSString.class] || ![item[@"title"] isKindOfClass:NSString.class]) continue;
        NSURL *url=[NSURL URLWithString:item[@"url"]];
        if (![@[@"https",@"http"] containsObject:url.scheme.lowercaseString] || !url.host.length || url.user.length || url.password.length) continue;
        [valid addObject:@{@"url":url.absoluteString,@"title":item[@"title"]}];
        if (valid.count==100) break;
    }
    return valid;
}
- (NSArray *)favorites { return [self validEntriesForKey:@"seyir.favorites"]; }
- (NSArray *)history { return [self validEntriesForKey:@"seyir.history"]; }
- (void)recordVisit:(NSURL *)url title:(NSString *)title {
    if (![@[@"http",@"https"] containsObject:url.scheme.lowercaseString] || !url.host.length || url.user.length || url.password.length) return;
    NSMutableArray *items=[self.history mutableCopy];
    NSIndexSet *duplicates=[items indexesOfObjectsPassingTest:^BOOL(NSDictionary *item,NSUInteger index,BOOL *stop) { return [item[@"url"] isEqualToString:url.absoluteString]; }];
    [items removeObjectsAtIndexes:duplicates];
    [items insertObject:@{@"url":url.absoluteString,@"title":title.length ? title : url.host} atIndex:0];
    if (items.count>100) [items removeObjectsInRange:NSMakeRange(100,items.count-100)];
    [self.defaults setObject:items forKey:@"seyir.history"];
}
- (BOOL)isFavorite:(NSURL *)url {
    for (NSDictionary *item in self.favorites) if ([item[@"url"] isEqualToString:url.absoluteString]) return YES;
    return NO;
}
- (void)toggleFavorite:(NSURL *)url title:(NSString *)title {
    if (![@[@"http",@"https"] containsObject:url.scheme.lowercaseString] || !url.host.length || url.user.length || url.password.length) return;
    NSMutableArray *items=[self.favorites mutableCopy];
    NSIndexSet *matches=[items indexesOfObjectsPassingTest:^BOOL(NSDictionary *item,NSUInteger index,BOOL *stop) { return [item[@"url"] isEqualToString:url.absoluteString]; }];
    if (matches.count) [items removeObjectsAtIndexes:matches];
    else if (items.count<100) [items addObject:@{@"url":url.absoluteString,@"title":title.length ? title : url.host}];
    [self.defaults setObject:items forKey:@"seyir.favorites"];
}
- (void)clearHistory { [self.defaults removeObjectForKey:@"seyir.history"]; }
@end
