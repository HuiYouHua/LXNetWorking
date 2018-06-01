//
//  LXCommonHelp.h
//  LXNetWorkingSDK
//
//  Created by 华惠友 on 2018/3/21.
//  Copyright © 2018年 华惠友. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface LXCommonHelp : NSObject

/**
 开始发起网络请求, 显示加载视图菊花转
 */
+ (void)showProgressHUD;

/**
 关闭菊花抽取
 */
+ (void)hideProgressHUD;

/**
 图片压缩
 
 @param imaged 压缩的图片
 @param imageWidth 压缩之后的图片宽
 */
+ (UIImage *)compressImg:(UIImage *)imaged andImageWidth:(CGFloat)imageWidth;

@end
