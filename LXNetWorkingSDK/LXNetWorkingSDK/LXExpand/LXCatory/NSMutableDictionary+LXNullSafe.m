//
//  NSMutableDictionary+LXNullSafe.m
//  LXNetWorkingSDK
//
//  Created by 华惠友 on 2018/3/22.
//  Copyright © 2018年 华惠友. All rights reserved.
//

#import "NSMutableDictionary+LXNullSafe.h"
#import <objc/runtime.h>

@implementation NSMutableDictionary (LXNullSafe)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        id obj = [[self alloc] init];
        
        [obj swizzeMethod:@selector(removeObject:) withMethod:@selector(safe_removeObjectForKey:)];
        
        [obj swizzeMethod:@selector(setObject:forKey:) withMethod:@selector(safe_setObject:forKey:)];
    });
}

/**
 交换方法

 @param origSelector 系统方法
 @param newSelector 替换的方法
 */
- (void)swizzeMethod:(SEL)origSelector withMethod:(SEL)newSelector {
    Class class = [self class];
    
    // 两个方法的Method
    Method swizzledMethod = class_getInstanceMethod(class, newSelector);
    Method systemMethod = class_getInstanceMethod(class, origSelector);
    
    // 首先动态添加方法，实现是被交换的方法，返回值表示添加成功还是失败
    BOOL didAddMethod = class_addMethod(class, origSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        //如果成功，说明类中不存在这个方法的实现
        //将被交换方法的实现替换到这个并不存在的实现
        class_replaceMethod(class, newSelector, method_getImplementation(systemMethod), method_getTypeEncoding(systemMethod));
        
    } else {
        method_exchangeImplementations(systemMethod, swizzledMethod);
    }
}

- (void)safe_setObject:(id)value forKey:(NSString *)key {
    if (value) {
        [self safe_setObject:value forKey:key];
    } else {
        NSLog(@"[NSMutableDictionary setObject: forKey:%@] value值不能为空;",key);
    }
}

- (void)safe_removeObjectForKey:(NSString *)key {
    if ([self objectForKey:key]) {
        [self safe_removeObjectForKey:key];
    } else {
        NSLog(@"[NSMutableDictionary removeObjectForKey:%@]值不能为空;",key);
    }    
}



@end









