#import "SeyirAddress.h"

NSURL *SeyirResolveAddress(NSString *input) {
    NSString *value = [input stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (value.length == 0 || value.length > 8192) return nil;
    NSURLComponents *parts = [NSURLComponents componentsWithString:value];
    NSString *scheme = parts.scheme.lowercaseString;
    if (scheme.length) {
        if (![@[@"http", @"https"] containsObject:scheme] || !parts.host.length || parts.user.length || parts.password.length) return nil;
        return parts.URL;
    }
    BOOL hasSpace = [value rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location != NSNotFound;
    if (!hasSpace && [value containsString:@"."]) {
        NSURLComponents *address = [NSURLComponents componentsWithString:[@"https://" stringByAppendingString:value]];
        if (address.host.length && !address.user.length && !address.password.length) return address.URL;
    }
    NSURLComponents *search = [NSURLComponents componentsWithString:@"https://www.google.com/search"];
    search.queryItems = @[[NSURLQueryItem queryItemWithName:@"q" value:value]];
    // Search endpoints commonly parse queries as form data, where '+' is a space.
    search.percentEncodedQuery = [search.percentEncodedQuery stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"];
    return search.URL;
}
