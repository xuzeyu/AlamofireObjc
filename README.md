# AlamofireObjc


# AlamofireObjc

## 介绍
Alamofire的Objc桥接，支持swift5

## 如何导入
```
pod 'HXSelectTool', :git => 'https://github.com/xuzeyu/HXSelectTool.git'
```

## 如何使用
```
#import "AlamofireObjc-Swift.h"

   // GET 请求示例
    [[AlamofireObjc shared] get:@"https://xxx.com/get"
                     parameters:nil
                        headers:nil
                        success:^(NSData * _Nullable data) {
        NSLog(@"GET success: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    } failure:^(NSError * _Nonnull error) {
        NSLog(@"GET failure: %@", error);
    }];
    
    // POST 请求示例
    [[AlamofireObjc shared] post:@"https://xxx.com/post"
                      parameters:@{@"key": @"value"}
                         headers:nil
                         success:^(NSData * _Nullable data) {
        NSLog(@"POST success: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    } failure:^(NSError * _Nonnull error) {
        NSLog(@"POST failure: %@", error);
    }];

```
