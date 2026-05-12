//
//  ViewController.m
//  Example
//
//  Created by XUZY on 2022/10/24.
//

#import "ViewController.h"
#import "AlamofireObjc-Swift.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self test];
}

- (void)test {
    // GET 请求示例
    [[AlamofireObjc shared] get:@"https://httpbin.org/get"
                     parameters:nil
                        headers:nil
                        success:^(NSData * _Nullable data) {
        NSLog(@"GET success: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    } failure:^(NSError * _Nonnull error) {
        NSLog(@"GET failure: %@", error);
    }];
    
    // POST 请求示例
    [[AlamofireObjc shared] post:@"https://httpbin.org/post"
                      parameters:@{@"key": @"value"}
                         headers:nil
                         success:^(NSData * _Nullable data) {
        NSLog(@"POST success: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    } failure:^(NSError * _Nonnull error) {
        NSLog(@"POST failure: %@", error);
    }];
}

@end
