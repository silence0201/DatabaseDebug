//
//  Categories.m
//  DatabaseDebugDemo
//
//  Created by Silence on 2018/2/28.
//  Copyright © 2018年 Silence. All rights reserved.
//

#import "Categories.h"

@implementation NSURL (scheme)

+(NSURL *)urlWith:(NSString *)schemeStr queryParams:(NSDictionary *)params {
    NSURL *url = [NSURL URLWithString:schemeStr];
    NSString *prefix = url.query ? @"&" : @"?";
    
    NSMutableArray* keyValuePairs = [NSMutableArray array];
    for (NSString* key in [params allKeys]) {
        id value = [params objectForKey:key];
        if(![value isKindOfClass:[NSString class]]) {
            NSLog(@"warning: %@ is not NSString Class", value);
            return nil;
        }
        
        NSCharacterSet *allowedCharacters = [NSCharacterSet characterSetWithCharactersInString:@"!*'();:@&=+$,/?%#[]"];
        NSString *escapedStr = [value stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
        [keyValuePairs addObject:[NSString stringWithFormat:@"%@=%@", key, escapedStr]];
    }
    NSString *queryStr = [keyValuePairs componentsJoinedByString:@"&"];
    
    NSString *urlString = [NSString stringWithFormat:@"%@%@%@", schemeStr, prefix, queryStr];
    return [NSURL URLWithString:urlString];
}

-(NSDictionary *)queryParams {
    if(!self.query) return  nil;
    
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    NSArray *keyValuePairs = [self.query componentsSeparatedByString:@"&"];
    for(id kv in keyValuePairs) {
        NSArray *kvPair = [kv componentsSeparatedByString:@"="];
        NSString *key = [kvPair objectAtIndex:0];
        NSString *value = [kvPair objectAtIndex:1];
        
        NSString *origStr = [value stringByRemovingPercentEncoding];
        [ret setValue:origStr forKey:key];
    }
    
    return ret;
}
@end

@implementation NSString (json)

-(id)JSONObject{
    NSError *errorJson;
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:[self dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&errorJson];
    if (errorJson != nil) {
        NSLog(@"fail to get dictioanry from JSON: %@, error: %@", self, errorJson);
    }
    return jsonDict;
}

@end

@implementation NSString (URLEncode)

- (NSString *)urlEncode {
    NSCharacterSet *allowedCharacters = [NSCharacterSet characterSetWithCharactersInString:@"!*'();:@&=+$,/?%#[]"];
    NSString *encodedString = [self stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
    return encodedString;
}

- (NSString *)URLDecode {
    NSString *result = [self stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    result = [result stringByRemovingPercentEncoding];
    return result;
}


@end
