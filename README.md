# AlamofireObjc

## 介绍

Alamofire的Objc桥接，支持swift5

## 如何pod导入

```pod
pod 'HXSelectTool', :git => 'https://github.com/xuzeyu/HXSelectTool.git'
```

## 如何使用

```objective-c
    //导入#import "AlamofireObjc-Swift.h"

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
```

