//
//  DatabaseWebServer.m
//  DatabaseDebugDemo
//
//  Created by Silence on 2018/2/28.
//  Copyright © 2018年 Silence. All rights reserved.
//

#import "DatabaseWebServer.h"
#import "DatabaseUtil.h"
#import "Categories.h"
#import <GCDWebServer/GCDWebServerRequest.h>
#import <GCDWebServer/GCDWebServerDataResponse.h>

@interface DatabaseWebServer ()

// 对应 数据库名:数据库路径
@property(nonatomic, strong) NSDictionary *databasePaths;

@end

@implementation DatabaseWebServer

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    static DatabaseWebServer *webServer ;
    dispatch_once(&onceToken, ^{
        webServer = [[[self class]alloc]init];
    });
    return webServer;
}

- (void)startServerOnPort:(NSUInteger)port directories:(NSArray *)directories {
    NSMutableDictionary *paths = [NSMutableDictionary dictionary];
    for (NSString *directory in directories) {
        NSArray *dirList = [[[NSFileManager defaultManager] subpathsAtPath:directory] pathsMatchingExtensions:@[@"sqlite",@"SQLITE",@"db",@"DB"]];
        for (NSString *subPath in dirList) {
            if ([subPath hasSuffix:@"sqlite"] || [subPath hasSuffix:@"SQLITE"]|| [subPath hasSuffix:@"db"]|| [subPath hasSuffix:@"DB"]) {
                [paths setObject:[directory stringByAppendingPathComponent:subPath] forKey:subPath.lastPathComponent];
            }
        }
        
        if ([directory hasSuffix:@"sqlite"] || [directory hasSuffix:@"SQLITE"]|| [directory hasSuffix:@"db"]|| [directory hasSuffix:@"DB"]) {
            [paths setObject:directory forKey:directory.lastPathComponent];
        }
    }
    
    _databasePaths = paths;
    [self startWithPort:port bonjourName:@""];
    NSLog(@"请使用浏览器打开%@", self.serverURL);
}

- (void)startServerOnPort:(NSUInteger)port {
    // 默认只包含Caches和Documents路径
    NSString *cacheDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches"];
    NSString *documentDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    [self startServerOnPort:port directories:@[cacheDir, documentDir]];
}

- (instancetype)init {
    if (self = [super init]) {
        NSURL *bundleURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"Web" withExtension:@"bundle"];
        NSBundle *bundle = [NSBundle bundleWithURL:bundleURL];
        [self addGETHandlerForBasePath:@"/" directoryPath:[bundle resourcePath] indexFilename:@"index.html" cacheAge:0 allowRangeRequests:YES];
        [self setupNormal];
        [self setUpdate];
    }
    return self;
}

- (void)setupNormal {
    __weak typeof(self)weakSelf = self;
    
    // 获取数据库列表
    [self addHandlerForMethod:@"GET"
                         path:@"/databaseList"
                 requestClass:[GCDWebServerRequest class]
                 processBlock:^GCDWebServerResponse*(GCDWebServerRequest* request) {
                     return [GCDWebServerDataResponse responseWithJSONObject:@{@"rows" : weakSelf.databasePaths.allKeys ?: [NSNull null]}];
                 }];
    
    [self addHandlerForMethod:@"GET"
                         path:@"/tableList"
                 requestClass:[GCDWebServerRequest class]
                 processBlock:^GCDWebServerResponse*(GCDWebServerRequest* request) {
                     NSDictionary *params = request.URL.queryParams;
                     NSString *dbName = [params objectForKey:@"database"];
                     [[DatabaseUtil shared] openDatabase:[weakSelf.databasePaths objectForKey:dbName]];
                     NSArray *array = [[DatabaseUtil shared] allTables];
                     [[DatabaseUtil shared] closedDatabase];
                     return [GCDWebServerDataResponse responseWithJSONObject:@{@"rows" : array?:[NSNull null]}];
                 }];
    
    [self addHandlerForMethod:@"GET"
                         path:@"/allTableRecords"
                 requestClass:[GCDWebServerRequest class]
                 processBlock:^GCDWebServerResponse*(GCDWebServerRequest* request) {
                     
                     NSDictionary *params = request.URL.queryParams;
                     NSString *dbName = [params objectForKey:@"database"];
                     NSString *tableName = [params objectForKey:@"tableName"];
                     
                     [[DatabaseUtil shared] openDatabase:[weakSelf.databasePaths objectForKey:dbName]];
                     NSDictionary *rows = [[DatabaseUtil shared] rowsInTable:tableName];
                     [[DatabaseUtil shared] closedDatabase];
                     return [GCDWebServerDataResponse responseWithJSONObject:rows?:[NSNull null]];
                 }];
    
    [self addHandlerForMethod:@"GET"
                         path:@"/downloadDb"
                 requestClass:[GCDWebServerRequest class]
                 processBlock:^GCDWebServerResponse*(GCDWebServerRequest* request) {
                     NSString *dbName = [request.URL.queryParams objectForKey:@"database"];
                     NSString *dbPath = [weakSelf.databasePaths objectForKey:dbName] ?: @"";
                     return [GCDWebServerDataResponse responseWithData:[NSData dataWithContentsOfFile:dbPath] contentType:@"application/octet-stream"];
                 }];
    
    [self addHandlerForMethod:@"GET"
                         path:@"/getUserDefault"
                 requestClass:[GCDWebServerRequest class]
                 processBlock:^GCDWebServerResponse*(GCDWebServerRequest* request) {
                     NSMutableDictionary *userData = [[DatabaseUtil shared] userDefaultData].mutableCopy;
                     [userData setObject:@YES forKey:@"userDefault"];
                     return [GCDWebServerDataResponse responseWithJSONObject:userData];
                 }];
    
    [self addHandlerForMethod:@"GET"
                         path:@"/getAppInfo"
                 requestClass:[GCDWebServerRequest class]
                 processBlock:^GCDWebServerResponse*(GCDWebServerRequest* request) {
                     NSDictionary *appInfo = [[DatabaseUtil shared] getAppInfoData];
                     return [GCDWebServerDataResponse responseWithJSONObject:appInfo];
                 }];
}
- (void)setUpdate {
    
    __weak typeof(self)weakSelf = self;
    
    [self addHandlerForMethod:@"GET"
                         path:@"/updateRecord"
                 requestClass:[GCDWebServerRequest class]
                 processBlock:^GCDWebServerResponse*(GCDWebServerRequest* request) {
                     
                     NSDictionary *params = request.URL.queryParams;
                     NSString *dbName = [params objectForKey:@"database"];
                     NSString *tableName = [params objectForKey:@"tableName"];
                     
                     id value = [params objectForKey:@"updatedData"];
                     NSString *result = [NSString stringWithFormat:@"%@",value];
                     NSDictionary *updateData =[[result URLDecode] JSONObject];
                     
                     BOOL isSuccess;
                     
                     if (updateData.count == 0 || dbName.length == 0 || tableName.length == 0) {
                         isSuccess = NO;
                     }else {
                         NSMutableDictionary *contentValues = [NSMutableDictionary dictionary];
                         NSMutableDictionary *where = [NSMutableDictionary dictionary];
                         for (NSDictionary *columnDic in updateData) {
                             NSString *key = [columnDic objectForKey:@"title"] ?: @"" ;
                             
                             BOOL isPrimary = [[columnDic objectForKey:@"isPrimary"] boolValue];
                             
                             if (isPrimary) {
                                 [where setObject:[columnDic objectForKey:@"value"]?:[NSNull null] forKey:key];
                             } else {
                                 [contentValues setObject:[columnDic objectForKey:@"value"]?:[NSNull null] forKey:[columnDic objectForKey:@"title"]];
                             }
                         }
                         
                         NSString *dbPath = [weakSelf.databasePaths objectForKey:dbName];
                         [[DatabaseUtil shared] openDatabase:dbPath];
                         isSuccess = [[DatabaseUtil shared] updateRecordInTableName:tableName data:contentValues condition:where];
                         [[DatabaseUtil shared] closedDatabase];
                         
                     }
                     return [GCDWebServerDataResponse responseWithJSONObject:@{@"isSuccessful" : @(isSuccess)}];
                 }];
    
    [self addHandlerForMethod:@"GET"
                         path:@"/deleteRecord"
                 requestClass:[GCDWebServerRequest class]
                 processBlock:^GCDWebServerResponse*(GCDWebServerRequest* request) {
                     
                     NSDictionary *params = request.URL.queryParams;
                     NSString *dbName = [params objectForKey:@"database"];
                     NSString *tableName = [params objectForKey:@"tableName"];
                     
                     id value = [params objectForKey:@"deleteData"];
                     NSString *result = [NSString stringWithFormat:@"%@",value];
                     NSDictionary *deleteData =[[result URLDecode] JSONObject];
                     BOOL isSuccess;
                     
                     if (deleteData.count == 0 || dbName.length == 0 || tableName.length == 0) {
                         isSuccess = NO;
                     }else {
                         NSMutableDictionary *where = [NSMutableDictionary dictionary];
                         for (NSDictionary *columnDic in deleteData) {
                             BOOL isPrimary = [[columnDic objectForKey:@"isPrimary"] boolValue];
                             NSString *key = [columnDic objectForKey:@"title"] ?: @"" ;
                             if (isPrimary) {
                                 [where setObject:[columnDic objectForKey:@"value"]?:[NSNull null] forKey:key];
                             }
                         }
                         
                         NSString *dbPath = [weakSelf.databasePaths objectForKey:dbName];
                         [[DatabaseUtil shared] openDatabase:dbPath];
                         isSuccess = [[DatabaseUtil shared] deleteRecordInTableName:tableName condition:where limit:nil];
                         [[DatabaseUtil shared] closedDatabase];
                         
                     }
                     return [GCDWebServerDataResponse responseWithJSONObject:@{@"isSuccessful" : @(isSuccess)}];
                 }];
    
    [self addHandlerForMethod:@"GET"
                         path:@"/query"
                 requestClass:[GCDWebServerRequest class]
                 processBlock:^GCDWebServerResponse*(GCDWebServerRequest* request) {
                     
                     NSDictionary *params = request.URL.queryParams;
                     NSString *dbName = [params objectForKey:@"database"];
                     
                     id value = [params objectForKey:@"query"];
                     NSString *query = [value URLDecode];
                     NSString *tableName = [weakSelf getTableNameFromQuery:query];
                     NSArray *words = [query  componentsSeparatedByString:@" "];
                     NSString *operator = [[words firstObject] lowercaseString];
                     
                     NSString *dbPath = [weakSelf.databasePaths objectForKey:dbName];
                     [[DatabaseUtil shared] openDatabase:dbPath];
                     
                     NSDictionary *resultData = [[DatabaseUtil shared] executeQueryTableName:tableName operator:operator query:query];
                     [[DatabaseUtil shared] closedDatabase];
                     return [GCDWebServerDataResponse responseWithJSONObject:resultData?:[NSNull null]];
                 }];
}

- (NSString*)getTableNameFromQuery:(NSString*)query {
    NSArray *words = [query  componentsSeparatedByString:@" "];
    NSString *operator = [[words firstObject] lowercaseString];
    NSInteger fromIndex = 0;
    NSString *table;
    
    for (int i =0;i<[words count];i++) {
        NSString *word = [words objectAtIndex:i];
        if ([operator isEqualToString:@"select"] || [operator isEqualToString:@"delete"]) {
            if ([word isEqualToString:@"from"]) {
                fromIndex = i;
            }
            if (i == fromIndex+1) {
                if([word stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length==0){
                    fromIndex ++;
                }else{
                    table = word;
                }
            }
        }else if ([operator isEqualToString:@"update"]) {
            if ([word isEqualToString:@"update"]) {
                fromIndex = i;
            }
            if (i == fromIndex+1) {
                if([word stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length==0){
                    fromIndex ++;
                }else{
                    table = word;
                }
            }
        }
    }
    return table;
}

@end
