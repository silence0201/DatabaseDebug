//
//  DatabaseUtil.h
//  DatabaseDebug
//
//  Created by Silence on 2018/2/27.
//  Copyright © 2018年 Silence. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DatabaseUtil : NSObject

+ (instancetype)shared;

- (BOOL)openDatabase:(NSString *)path;
- (BOOL)closedDatabase;

- (NSArray *)allTables;
- (NSArray *)tableInfo:(NSString *)tableName;
- (NSDictionary *)rowsInTable:(NSString *)tableName;

- (BOOL)updateRecordInTableName:(NSString *)tableName
                           data:(NSDictionary *)data
                      condition:(NSDictionary *)condition;
- (BOOL)deleteRecordInTableName:(NSString *)tableName
                      condition:(NSDictionary *)condition
                          limit:(NSString *)limit;
- (NSDictionary*)executeQueryTableName:(NSString *)tableName
                              operator:(NSString *)oper
                                 query:(NSString*)query;

- (NSDictionary *)userDefaultData;
- (NSDictionary *)getAppInfoData;

@end
