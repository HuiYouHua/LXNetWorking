//
//  LXCommonHelp.m
//  LXNetWorkingSDK
//
//  Created by 华惠友 on 2018/3/21.
//  Copyright © 2018年 华惠友. All rights reserved.
//

#import "LXCommonHelp.h"

#import "MBProgressHUD.h"

@implementation LXCommonHelp

/** 开始发起网络请求, 显示加载视图菊花转 */
+ (void)showProgressHUD {
    //
    [MBProgressHUD showHUDAddedTo:[UIApplication sharedApplication].keyWindow animated:YES];
}

/** 关闭菊花抽取 */
+ (void)hideProgressHUD {
    [MBProgressHUD hideAllHUDsForView:[UIApplication sharedApplication].keyWindow animated:YES];
}

/**
 图片压缩
 
 @param imaged 压缩的图片
 @param imageWidth 压缩之后的图片宽
 */
+ (UIImage *)compressImg:(UIImage *)imaged andImageWidth:(CGFloat)imageWidth {
    //487927   先压，经过这一步后，图片的size其实没有改变的，再缩后才变。
    NSData *imgData = UIImageJPEGRepresentation(imaged, 0.3);
    imaged = [UIImage imageWithData:imgData];
    
    CGFloat height = imageWidth*(imaged.size.height/imaged.size.width);
    
    UIImage *newImage = [self imageByScalingAndCroppingForSize:CGSizeMake(imageWidth, height) withSourceImage:imaged];
    return newImage;
}

+ (UIImage*)imageByScalingAndCroppingForSize:(CGSize)targetSize withSourceImage:(UIImage *)sourceImage {
    UIImage *newImage = nil;
    CGSize imageSize = sourceImage.size;
    CGFloat width = imageSize.width;
    CGFloat height = imageSize.height;
    CGFloat targetWidth = targetSize.width;
    CGFloat targetHeight = targetSize.height;
    CGFloat scaleFactor = 0.0;
    CGFloat scaledWidth = targetWidth;
    CGFloat scaledHeight = targetHeight;
    CGPoint thumbnailPoint = CGPointMake(0.0,0.0);
    if (CGSizeEqualToSize(imageSize, targetSize) == NO)
    {
        //  CGFloat widthFactor = targetWidth / width;
        
        CGFloat widthFactor = targetWidth/ width;
        CGFloat heightFactor  =targetHeight/height;
        
        if (widthFactor>heightFactor) {
            scaleFactor = widthFactor;
        }else{
            scaleFactor = heightFactor;
        }
        
        scaledWidth = width * scaleFactor;
        scaledHeight = height * scaleFactor;
        if (widthFactor > heightFactor) {
            thumbnailPoint.y = (targetHeight-scaledHeight)*0.5;
        }else
        {
            thumbnailPoint.x = (targetWidth -scaledWidth)*0.5;
        }
        
    }
    UIGraphicsBeginImageContext(targetSize); // this will crop
    CGRect thumbnailRect = CGRectZero;
    thumbnailRect.origin = thumbnailPoint;
    thumbnailRect.size.width= scaledWidth;
    thumbnailRect.size.height = scaledHeight;
    [sourceImage drawInRect:thumbnailRect];
    newImage = UIGraphicsGetImageFromCurrentImageContext();
    if(newImage == nil)
    {
        NSLog(@"image error");
    }
    UIGraphicsEndImageContext();
    
    return newImage;
}


@end
