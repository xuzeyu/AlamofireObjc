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
    //返回response模型包含jsonString/jsonDictionary/data数据，取其中一个进行解析即可
    // GET 请求示例
    [[AlamofireObjc shared] get:@"https://httpbin.org/get"
                     parameters:nil
                        headers:nil
                     completion:^(AFResponseModel * _Nonnull response) {
        if (response.isSuccess) {
            NSLog(@"GET success: %@", response.jsonString);
        }else {
            NSLog(@"GET failure: %@", response.error);
        }
    }];
    
    // POST 请求示例
    [[AlamofireObjc shared] post:@"https://httpbin.org/post"
                      parameters:@{@"key": @"value"}
                         headers:nil
                      completion:^(AFResponseModel * _Nonnull response) {
        if (response.isSuccess) {
            NSLog(@"POST success: %@", response.jsonString);
        }else {
            NSLog(@"POST failure: %@", response.error);
        }
    }];
}

@end
