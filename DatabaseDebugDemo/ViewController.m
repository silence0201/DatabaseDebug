//
//  ViewController.m
//  DatabaseDebugDemo
//
//  Created by Silence on 2018/2/27.
//  Copyright © 2018年 Silence. All rights reserved.
//

#import "ViewController.h"
#import "DatabaseWebServer.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSFileManager*fileManager =[NSFileManager defaultManager];
    NSError*error;
    NSString *documentDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *cacheDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Cache"];
    
    NSString *contactPath = [documentDirectory stringByAppendingPathComponent:@"Contact.db"];
    NSString *cachePath = [cacheDirectory stringByAppendingPathComponent:@"Cache.db"];
    
    
    if([fileManager fileExistsAtPath:contactPath]== NO){
        NSString *resourcePath =[[NSBundle mainBundle] pathForResource:@"Contact" ofType:@"db"];
        [fileManager copyItemAtPath:resourcePath toPath:contactPath error:&error];
        NSLog(@"%@", error);
    }
    
    if([fileManager fileExistsAtPath:cachePath]== NO){
        NSString *resourcePath =[[NSBundle mainBundle] pathForResource:@"Cache" ofType:@"db"];
        [fileManager copyItemAtPath:resourcePath toPath:cachePath error:&error];
        NSLog(@"%@", error);
    }

    [[DatabaseWebServer shared] startServerOnPort:9002];
}



@end
