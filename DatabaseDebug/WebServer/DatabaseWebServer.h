//
//  DatabaseWebServer.h
//  DatabaseDebugDemo
//
//  Created by Silence on 2018/2/28.
//  Copyright © 2018年 Silence. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GCDWebServer/GCDWebServer.h>

@interface DatabaseWebServer : GCDWebServer

+ (instancetype)shared;

- (void)startServerOnPort:(NSUInteger)port directories:(NSArray*)directories;

- (void)startServerOnPort:(NSUInteger)port;

@end
