#import "../native/SeyirAddress.h"
#import "../native/SeyirLibrary.h"
static void require(BOOL condition, NSString *message) { if(!condition){NSLog(@"FAIL: %@",message);exit(1);} }
int main(void) { @autoreleasepool {
    require(SeyirResolveAddress(@" \n")==nil,@"Empty input");
    require(SeyirResolveAddress(@"javascript:alert(1)")==nil,@"No script URL");
    require(SeyirResolveAddress(@"file:///etc/passwd")==nil,@"No local file URL");
    require(SeyirResolveAddress(@"https://user:secret@example.com")==nil,@"No URL credentials");
    require([SeyirResolveAddress(@"youtube.com").host isEqualToString:@"youtube.com"],@"Bare host");
    NSURL *query=SeyirResolveAddress(@"maç & özet + canlı");
    NSURLComponents *parts=[NSURLComponents componentsWithURL:query resolvingAgainstBaseURL:NO];
    require([parts.queryItems.firstObject.value isEqualToString:@"maç & özet + canlı"],@"Turkish query preserved");
    require([parts.percentEncodedQuery containsString:@"%2B"],@"Literal plus is not form whitespace");
    NSString *suite=[@"seyir-test-" stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *defaults=[[NSUserDefaults alloc] initWithSuiteName:suite];
    SeyirLibrary *lib=[[SeyirLibrary alloc] initWithDefaults:defaults];
    [defaults setObject:@[@42,@{@"url":@"javascript:alert(1)",@"title":@"bad"},@{@"url":@42,@"title":@"wrong type"}] forKey:@"seyir.history"];
    require(lib.history.count==0,@"Corrupt state recovery");
    NSURL *url=[NSURL URLWithString:@"https://www.youtube.com"];
    [lib recordVisit:url title:@"YouTube"];[lib recordVisit:url title:@"YouTube updated"];
    require(lib.history.count==1,@"History deduplication");
    [lib toggleFavorite:url title:@"YouTube"];require([lib isFavorite:url],@"Favorite saved");
    [lib clearHistory];require(lib.history.count==0 && lib.favorites.count==1,@"Clear history preserves favorites");
    [lib toggleFavorite:url title:@"YouTube"];require(![lib isFavorite:url],@"Favorite removed");
    [defaults removePersistentDomainForName:suite];
    NSLog(@"SEYIR_TEST Foundation tests passed");
}return 0;}
