//
//  DatabaseUtil.m
//  DatabaseDebug
//
//  Created by Silence on 2018/2/27.
//  Copyright © 2018年 Silence. All rights reserved.
//

#import "DatabaseUtil.h"

#ifdef COCOAPODS
#import "FMDB.h"
#else
#import <FMDB/FMDB.h>
#endif

@implementation NSMutableArray (safe)

- (void)safe_addObject:(id)anObject {
    if (anObject) {
        [self addObject:anObject];
    }
}

@end

@implementation NSMutableDictionary (safe)

- (void)safe_setObject:(id)anObject forKey:(id<NSCopying>)aKey {
    if (aKey) {
        if (!anObject) {
            [self removeObjectForKey:aKey];
        }
        else {
            [self setObject:anObject forKey:aKey];
        }
    }
}

@end

@implementation NSString (AppInfo)

+ (NSString *)appVersion{
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString *app_Version = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
    return app_Version;
}

+ (NSString *)build{
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString *app_build = [infoDictionary objectForKey:@"CFBundleVersion"];
    return app_build ;
}

+ (NSString *)identifier{
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString * bundleIdentifier = [infoDictionary objectForKey:@"CFBundleIdentifier"];
    return bundleIdentifier;
}

+ (NSString *)displayName{
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString * bundleIdentifier = [infoDictionary objectForKey:@"CFBundleDisplayName"];
    return bundleIdentifier;
}

@end


@interface DatabaseUtil()

@property(nonatomic, copy) NSString *dbPath;
@property(nonatomic, copy) NSString *dbName;

@property (nonatomic, strong) FMDatabase *fmdb;

@end

@implementation DatabaseUtil

+ (instancetype)shared {
    static DatabaseUtil *dbUtil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dbUtil = [[[self class]alloc]init];
    });
    return dbUtil;
}

- (BOOL)openDatabase:(NSString *)path {
    // 关闭已打开的
    if (self.dbPath && ![path isEqualToString:self.dbPath]) {
        [self closedDatabase];
    }
    
    _dbPath = path;
    _dbName = [_dbPath lastPathComponent];
    NSString *dbDir = [_dbPath stringByDeletingLastPathComponent];
    if (![[NSFileManager defaultManager] fileExistsAtPath:dbDir]) return NO;
    self.fmdb = [FMDatabase databaseWithPath:path];
    if (![self.fmdb open]) {
        NSLog(@"打开数据库%@失败",path);
        return NO;
    }
    
    return YES;
}

- (BOOL)closedDatabase {
    if (self.fmdb) {
        return [self.fmdb close];
    }
    return YES;
}

- (NSArray *)allTables {
    NSString *sql = @"SELECT tbl_name FROM sqlite_master WHERE type = 'table'";
    FMResultSet *rs = [self.fmdb executeQuery:sql];
    NSMutableArray *tables = [NSMutableArray array];
    
    while ([rs next]) {
        [tables safe_addObject:[rs stringForColumn:@"tbl_name"]];
    }
    
    return tables;
}

- (NSArray *)tableInfo:(NSString *)tableName {
    FMResultSet *rs = [self.fmdb getTableSchema:tableName];
    NSMutableArray *infos = [NSMutableArray array];
    
    while ([rs next]) {
        [infos safe_addObject:rs.resultDictionary];
    }
    
    return infos;
}

- (NSDictionary *)rowsInTable:(NSString *)tableName {
    NSMutableDictionary *tableData = [NSMutableDictionary dictionary];
    [tableData safe_setObject:@(1) forKey:@"isSelectQuery"];
    [tableData safe_setObject:@(1) forKey:@"isSuccessful"];
    
    //标题
    FMResultSet *infors = [self.fmdb getTableSchema:tableName];
    NSMutableArray *tableInfoResult = [NSMutableArray array];
    
    while ([infors next]) {
        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        [info safe_setObject:@([infors boolForColumn:@"pk"]) forKey:@"isPrimary"];
        [info safe_setObject:[infors stringForColumn:@"name"]?:@"" forKey:@"title"];
        [info safe_setObject:[infors stringForColumn:@"type"] forKey:@"dataType"];
        [tableInfoResult safe_addObject:info];
    }
    
    [tableData safe_setObject:tableInfoResult forKey:@"tableInfos"];
    
    BOOL isEditable = tableName != nil && [tableData objectForKey:@"tableInfos"] != nil;
    [tableData safe_setObject:@(isEditable) forKey:@"isEditable"];
    
    //数据
    NSString *sql = [NSString stringWithFormat:@"select * from %@",tableName];
    FMResultSet *rs = [self.fmdb executeQuery:sql];
    NSMutableArray *rows = [NSMutableArray array];
    
    while ([rs next]) {
        NSMutableArray *row = [NSMutableArray array];
        
        for ( int i = 0; i < tableInfoResult.count; i++) {
            NSMutableDictionary *columnData = [NSMutableDictionary dictionaryWithCapacity:10];
            NSString *columName = [[tableInfoResult objectAtIndex:i] objectForKey:@"title"];
            NSString *type = [[tableInfoResult objectAtIndex:i] objectForKey:@"dataType"];
            
            if ([[type lowercaseString] isEqualToString:@"integer"]) {
                [columnData safe_setObject:@"integer" forKey:@"dataType"];
                [columnData safe_setObject:@([rs intForColumn:columName]) forKey:@"value"];
            }else if ([[type lowercaseString] isEqualToString:@"real"]) {
                [columnData safe_setObject:@"float" forKey:@"dataType"];
                [columnData safe_setObject:@([rs doubleForColumn:columName]) forKey:@"value"];
            }else if ([[type lowercaseString] isEqualToString:@"text"]) {
                [columnData safe_setObject:@"text" forKey:@"dataType"];
                [columnData safe_setObject:[rs stringForColumn:columName]?:@"" forKey:@"value"];
            }else if ([[type lowercaseString] isEqualToString:@"blob"]) {
                [columnData safe_setObject:@"blob" forKey:@"dataType"];
                [columnData safe_setObject:@"blob" forKey:@"value"];
            }else if ([[type lowercaseString] isEqualToString:@"null"]) {
                [columnData safe_setObject:@"null" forKey:@"dataType"];
                [columnData safe_setObject:[NSNull null] forKey:@"value"];
            }else {
                [columnData safe_setObject:@"text" forKey:@"dataType"];
                [columnData safe_setObject:[rs stringForColumn:columName] forKey:@"value"];
            }
            
            [row safe_addObject:columnData];
        }
        
        [rows safe_addObject:row];
    }
    
    [tableData safe_setObject:rows forKey:@"rows"];
    
    return tableData;
}

- (BOOL)updateRecordInTableName:(NSString *)tableName
                           data:(NSDictionary *)data
                      condition:(NSDictionary *)condition {
    NSMutableArray *fields = [NSMutableArray array];
    
    for (NSString *key in data.allKeys) {
        [fields safe_addObject:[NSString stringWithFormat:@"%@ = '%@'", key, [data objectForKey:key]]];
    }
    NSString *values = [fields componentsJoinedByString:@","];
    
    NSString *where = @"1";
    
    if ([condition isKindOfClass:[NSDictionary class]] && condition.count > 0) {
        NSMutableArray *conArray = [NSMutableArray array];
        
        for (NSString *key in condition.allKeys) {
            [conArray safe_addObject:[NSString stringWithFormat:@"%@ = '%@'", key, [condition objectForKey:key]]];
        }
        
        where = [conArray componentsJoinedByString:@" AND "];
    }
    
    NSString *sqlString = [NSString stringWithFormat:@"UPDATE \"%@\" SET %@ WHERE %@",tableName,values,where];
    NSLog(@"Update SQL:%@",sqlString);
    return [self.fmdb executeQuery:sqlString];
}

- (BOOL)deleteRecordInTableName:(NSString *)tableName
                      condition:(NSDictionary *)condition
                          limit:(NSString *)limit {
    NSString *where = @"1";
    NSString *limitString =@"";
    if (limit.length > 0) {
        limitString = [NSString stringWithFormat:@"LIMIT %@",limit];
    }
    
    if ([condition isKindOfClass:[NSDictionary class]] && condition.count > 0) {
        NSMutableArray *conArray = @[].mutableCopy;
        
        for (NSString *key in condition.allKeys) {
            [conArray safe_addObject:[NSString stringWithFormat:@"%@ = '%@'", key, [condition objectForKey:key]]];
        }
        
        where = [conArray componentsJoinedByString:@" AND "];
    }
    
    NSString *sqlString =[NSString stringWithFormat:@"DELETE FROM \"%@\" WHERE %@ %@",tableName,where,limitString];
    NSLog(@"Delete SQL:%@",sqlString);
    return [self.fmdb executeUpdate:sqlString];
}

- (NSDictionary *)executeQueryTableName:(NSString *)tableName
                               operator:(NSString *)oper
                                  query:(NSString *)query {
    if ([oper isEqualToString:@"select"]) {
        NSMutableDictionary *tableData = [NSMutableDictionary dictionary];
        [tableData safe_setObject:@(1) forKey:@"isSelectQuery"];
        [tableData safe_setObject:@(1) forKey:@"isSuccessful"];
        
        //数据
        NSString *sql = query;
        FMResultSet *rs = [self.fmdb executeQuery:sql];
        NSMutableArray *rows = @[].mutableCopy;
        
        //标题
        FMResultSet *infors = [self.fmdb getTableSchema:tableName];
        
        NSMutableArray *tableInfoResult = [NSMutableArray array];
        
        while ([infors next]) {
            NSMutableDictionary *info = [NSMutableDictionary dictionary];
            
            NSString *columnName = [infors stringForColumn:@"name"];
            
            if ([rs.columnNameToIndexMap.allKeys containsObject:columnName]) {
                [info safe_setObject:@([infors boolForColumn:@"pk"]) forKey:@"isPrimary"];
                [info safe_setObject:[infors stringForColumn:@"name"]?:@"" forKey:@"title"];
                [info safe_setObject:[infors stringForColumn:@"type"] forKey:@"dataType"];
                [tableInfoResult safe_addObject:info];
            }
        }
        [tableData safe_setObject:tableInfoResult forKey:@"tableInfos"];
        
        BOOL isEditable = tableName != nil && [tableData objectForKey:@"tableInfos"] != nil;
        [tableData safe_setObject:@(isEditable) forKey:@"isEditable"];
        
        while ([rs next]) {
            NSMutableArray *row = @[].mutableCopy;
            
            for ( int i = 0; i < tableInfoResult.count; i++) {
                NSMutableDictionary *columnData = [NSMutableDictionary dictionaryWithCapacity:10];
                NSString *columName = [[tableInfoResult objectAtIndex:i] objectForKey:@"title"];
                NSString *type = [[tableInfoResult objectAtIndex:i] objectForKey:@"dataType"];
                
                if ([[type lowercaseString] isEqualToString:@"integer"]) {
                    [columnData safe_setObject:@"integer" forKey:@"dataType"];
                    [columnData safe_setObject:@([rs intForColumn:columName]) forKey:@"value"];
                }else if ([[type lowercaseString] isEqualToString:@"real"]) {
                    [columnData safe_setObject:@"float" forKey:@"dataType"];
                    [columnData safe_setObject:@([rs doubleForColumn:columName]) forKey:@"value"];
                }else if ([[type lowercaseString] isEqualToString:@"text"]) {
                    [columnData safe_setObject:@"text" forKey:@"dataType"];
                    [columnData safe_setObject:[rs stringForColumn:columName]?:@"" forKey:@"value"];
                }else if ([[type lowercaseString] isEqualToString:@"blob"]) {
                    [columnData safe_setObject:@"blob" forKey:@"dataType"];
                    [columnData safe_setObject:@"blob" forKey:@"value"];
                }else if ([[type lowercaseString] isEqualToString:@"null"]) {
                    [columnData safe_setObject:@"null" forKey:@"dataType"];
                    [columnData safe_setObject:[NSNull null] forKey:@"value"];
                }else {
                    [columnData safe_setObject:@"text" forKey:@"dataType"];
                    [columnData safe_setObject:[rs stringForColumn:columName] forKey:@"value"];
                }
                
                [row safe_addObject:columnData];
            }
            
            [rows safe_addObject:row];
        }
        
        [tableData safe_setObject:rows forKey:@"rows"];
        return tableData;
        
    }else {
        BOOL result =  [self.fmdb executeUpdate:query];
        NSDictionary *respone;
        if (result) {
            respone = @{@"isSelectQuery":@(true),@"isSuccessful":@(true)};
        }else{
            respone = @{@"isSelectQuery":@(true),@"isSuccessful":@(false),@"errorMessage":@"Database Opration faild!"};
        }
        
        return respone;
    }
}

- (NSDictionary *)userDefaultData {
    NSMutableDictionary *tableData = [NSMutableDictionary dictionary];
    [tableData safe_setObject:@(1) forKey:@"isSelectQuery"];
    [tableData safe_setObject:@(1) forKey:@"isSuccessful"];
    
    NSMutableArray *tableInfoResult = [NSMutableArray array];
    [tableInfoResult safe_addObject:@{@"title": @"key", @"isPrimary" : @(1), @"dataType" : @"text"}];
    [tableInfoResult safe_addObject:@{@"title": @"value", @"isPrimary" : @(0), @"dataType" : @"text"}];
    
    [tableData safe_setObject:tableInfoResult forKey:@"tableInfos"];
    
    [tableData safe_setObject:@(NO) forKey:@"isEditable"];
    
    NSMutableArray *rows = [NSMutableArray array];
    
    NSDictionary *userData = [[NSUserDefaults standardUserDefaults]dictionaryRepresentation];
    
    for (NSString *key in userData.allKeys) {
        NSMutableArray *row = [NSMutableArray array];
        
        [row safe_addObject:@{@"dataType" : @"text", @"value" : key?key:@""}];
        
        id value = [userData objectForKey:key];
        
        if ([value isKindOfClass:[NSString class]]) {
            [row safe_addObject:@{@"dataType" : @"text", @"value" : value}];
        }else if([value isKindOfClass:[NSNumber class]]){
            [row safe_addObject:@{@"dataType" : @"text", @"value" : [NSString stringWithFormat:@"%@",value]}];
        }else{
            [row safe_addObject:@{@"dataType" : @"text", @"value" : [value description]?:@""}];
        }
        
        [rows addObject:row];
    }
    [tableData safe_setObject:rows forKey:@"rows"];
    
    return tableData;
}

- (NSDictionary*)getAppInfoData {
    NSMutableDictionary *tableData = [NSMutableDictionary dictionary];
    [tableData safe_setObject:@(1) forKey:@"isSelectQuery"];
    [tableData safe_setObject:@(1) forKey:@"isSuccessful"];
    
    NSMutableArray *tableInfoResult = [NSMutableArray array];
    [tableInfoResult safe_addObject:@{@"title": @"property name", @"isPrimary" : @(1), @"dataType" : @"text"}];
    [tableInfoResult safe_addObject:@{@"title": @"property value", @"isPrimary" : @(0), @"dataType" : @"text"}];
    
    [tableData safe_setObject:tableInfoResult forKey:@"tableInfos"];
    
    [tableData safe_setObject:@(NO) forKey:@"isEditable"];
    
    NSMutableArray *rows = [NSMutableArray array];
    
    //app name
    NSString *displayName = [NSString displayName];
    NSMutableArray *displayRow = [NSMutableArray array];
    [displayRow safe_addObject:@{@"dataType": @"text", @"value": @"Display Name"}];
    [displayRow safe_addObject:@{@"dataType": @"text", @"value": displayName ?:@""}];
    [rows safe_addObject:displayRow];
    
    //app bundle identifier
    NSString *bundleIdentifer = [NSString identifier];
    NSMutableArray *bundleRow = [NSMutableArray array];
    [bundleRow safe_addObject:@{@"dataType": @"text", @"value": @"Bundle Identifer"}];
    [bundleRow safe_addObject:@{@"dataType": @"text", @"value": bundleIdentifer}];
    [rows safe_addObject:bundleRow];
    
    //app version
    NSString *version = [NSString appVersion];
    NSMutableArray *versionRow = @[].mutableCopy;
    [versionRow safe_addObject:@{@"dataType": @"text", @"value": @"Version"}];
    [versionRow safe_addObject:@{@"dataType": @"text", @"value": version}];
    [rows safe_addObject:versionRow];
    
    //app build number
    NSString *build = [NSString build];
    NSMutableArray *buildRow = [NSMutableArray array];
    [buildRow safe_addObject:@{@"dataType": @"text", @"value": @"Build"}];
    [buildRow safe_addObject:@{@"dataType": @"text", @"value": build}];
    [rows safe_addObject:buildRow];
    
    //document path
    NSArray *pathSearch = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsPath = [pathSearch objectAtIndex:0];
    NSMutableArray *documentRow = [NSMutableArray array];
    [documentRow safe_addObject:@{@"dataType": @"text", @"value": @"Documents"}];
    [documentRow safe_addObject:@{@"dataType": @"text", @"value": documentsPath?documentsPath:@""}];
    [rows safe_addObject:documentRow];
    
    //cache path
    NSArray *pathSearchCache = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachePath = [pathSearchCache objectAtIndex:0];
    NSMutableArray *cacheRow = [NSMutableArray array];
    [cacheRow safe_addObject:@{@"dataType": @"text", @"value": @"Cache"}];
    [cacheRow safe_addObject:@{@"dataType": @"text", @"value": cachePath?cachePath:@""}];
    [rows safe_addObject:cacheRow];
    
    [tableData safe_setObject:rows forKey:@"rows"];
    
    return tableData;
}

@end
