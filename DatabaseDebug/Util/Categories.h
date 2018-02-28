//
//  Categories.h
//  DatabaseDebugDemo
//
//  Created by Silence on 2018/2/28.
//  Copyright © 2018年 Silence. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURL (scheme)

+ (NSURL *)urlWith:(NSString *)schemeStr queryParams:(NSDictionary *)params;
- (NSDictionary *)queryParams;

@end

@interface NSString (json)

- (id)JSONObject;

@end

@interface NSString (URLEncode)
- (NSString *)urlEncode;
- (NSString *)URLDecode;
@end
