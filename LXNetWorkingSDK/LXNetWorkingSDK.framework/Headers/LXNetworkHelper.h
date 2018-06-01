//
//  LXNetworkHelper.h
//  LXNetWorkingSDK
//
//  Created by 华惠友 on 2018/3/21.
//  Copyright © 2018年 华惠友. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/*！定义请求类型的枚举 */
typedef NS_ENUM(NSUInteger, LXHttpRequestType) {
    LXHttpRequestTypeGet         = 0,
    LXHttpRequestTypePost
    
};

/**
 *  网络状态
 */
typedef NS_ENUM(NSInteger, LXNetworkStatus) {
    /**
     *  未知网络
     */
    LXNetworkStatusUnknown             = 1 << 0,
    /**
     *  无法连接
     */
    LXNetworkStatusNotReachable        = 1 << 1,
    /**
     *  WWAN网络
     */
    LXNetworkStatusReachableViaWWAN    = 1 << 2,
    /**
     *  WiFi网络
     */
    LXNetworkStatusReachableViaWiFi    = 1 << 3
};

/**
 *  成功回调
 *
 *  @param response 成功后返回的数据
 */
typedef void(^LXResponseSuccess)(id response);

/**
 *  失败回调
 *
 *  @param error 失败后返回的错误信息
 */
typedef void(^LXResponseFail)(NSError *error);

/**
 *  上传/下载进度
 *
 *  @param progress              下载的进度
 *         - progress.completedUnitCount:当前大小
 *         - progress.totalUnitCount:总大小
 */
typedef void (^LXHttpProgress)(NSProgress *progress);

/**
 网络状态回调

 @param status 网络状态
 */
typedef void(^NetworkStatusbBlock)(LXNetworkStatus status);

/**
 *  重命名请求任务
 */
typedef NSURLSessionTask LXURLSessionTask;

@interface LXNetworkHelper : NSObject

/**
 开始监听网络状态(此方法在整个项目中只需要调用一次)
 */
+ (void)startMonitoringNetwork;

/**
 通过Block回调实时获取网络状态

 @param status 网络变化时的回调
 */
+ (void)checkNetworkStatusWithBlock:(NetworkStatusbBlock)status;

/**
 获取当前网络状态,

 @return 有网YES,无网:NO
 */
+ (BOOL)currentNetworkStatus;

#pragma mark - 网络请求
/**
 网络请求方法, block回调
 
 @param type 请求类型   GET = 0 / POST = 1
 @param subMethod 请求地址
 @param parameters 请求参数
 @param showHUD 是否显示加载菊花 YES / OR
 @param successBlock 成功回调block
 @param failureBlock 失败回调block
 @return task
 */
+ (LXURLSessionTask *)lx_requestWithType:(LXHttpRequestType)type
                           withSubMethod:(NSString *)subMethod
                          withParameters:(NSMutableDictionary *)parameters
                                 showHUD:(BOOL)showHUD
                        withSuccessBlock:(LXResponseSuccess)successBlock
                        withFailureBlock:(LXResponseFail)failureBlock;

/**
 网络请求方法, block回调 带有模型转换
 
 @param type 请求类型   GET = 0 / POST = 1
 @param subMethod 请求地址
 @param parameters 请求参数
 @param showHUD 是否显示加载菊花 YES / OR
 @param modelClassStr 模型类名 字符串形式 传nil = 不需要转 / 模型名称 = 转模型,返回json字典
 @param successBlock 成功回调block
 @param failureBlock 失败回调block
 @return task
 */
+ (LXURLSessionTask *)lx_requestWithType:(LXHttpRequestType)type
                           withSubMethod:(NSString *)subMethod
                          withParameters:(NSMutableDictionary *)parameters
                                 showHUD:(BOOL)showHUD
                             modeleClass:(NSString *)modelClassStr
                        withSuccessBlock:(LXResponseSuccess)successBlock
                        withFailureBlock:(LXResponseFail)failureBlock;

/**
 网络请求方法, block回调 带有模型转换 请求超时时间
 
 @param type 请求类型   GET = 0 / POST = 1
 @param urlStr 请求地址
 @param parameters 请求参数
 @param showHUD 是否显示加载菊花 YES / OR
 @param timeOut 超时时间 默认20s
 @param modelClassStr 模型类名 字符串形式 传nil = 不需要转 / 模型名称 = 转模型,返回json字典
 @param successBlock 成功回调block
 @param failureBlock 失败回调block
 @return task
 */
+ (LXURLSessionTask *)lx_requestWithType:(LXHttpRequestType)type
                           withSubMethod:(NSString *)urlStr
                          withParameters:(NSMutableDictionary *)parameters
                                 showHUD:(BOOL)showHUD
                                 timeOut:(NSTimeInterval)timeOut
                             modeleClass:(NSString *)modelClassStr
                        withSuccessBlock:(LXResponseSuccess)successBlock
                        withFailureBlock:(LXResponseFail)failureBlock;


#pragma mark - 上传图片文件
/**
 单个图片上传
 
 @param urlStr 请求地址
 @param parameters 请求参数
 @param image 图片
 @param showHUD 是否显示加载菊花 YES / OR
 @param name 图片名称 可为nil
 @param fileName 文件名称 可为nil
 @param mimeType MIMETYPE 不填默认为image/jpeg
 @param progress 上传进度
 @param successBlock 成功回调
 @param failureBlock 失败回调
 @return task
 */
+ (LXURLSessionTask *)lx_uploadImageWithURL:(NSString *)urlStr
                                 parameters:(NSDictionary *)parameters
                                     images:(UIImage *)image
                                    showHUD:(BOOL)showHUD
                                       name:(NSString *)name
                                   fileName:(NSString *)fileName
                                   mimeType:(NSString *)mimeType
                                   progress:(LXHttpProgress)progress
                                    success:(LXResponseSuccess)successBlock
                                    failure:(LXResponseFail)failureBlock;

/**
 多图片上传
 
 @param urlStr 请求地址
 @param parameters 请求参数
 @param images 图片数组
 @param showHUD 是否显示加载菊花 YES / OR
 @param name 图片名称 可为nil
 @param fileName 文件名称 可为nil
 @param mimeType MIMETYPE 不填默认为image/jpeg
 @param progress 上传进度
 @param successBlock 成功回调
 @param failureBlock 失败回调
 @return task
 */
+ (LXURLSessionTask *)lx_uploadImagesWithURL:(NSString *)urlStr
                                  parameters:(NSDictionary *)parameters
                                      images:(NSArray<UIImage *> *)images
                                     showHUD:(BOOL)showHUD
                                        name:(NSString *)name
                                    fileName:(NSString *)fileName
                                    mimeType:(NSString *)mimeType
                                    progress:(LXHttpProgress)progress
                                     success:(LXResponseSuccess)successBlock
                                     failure:(LXResponseFail)failureBlock;


#pragma mark - 下载文件
/**
 文件下载
 
 @param URL 请求地址
 @param fileDir 下载到沙盒中Cache目录中文件夹名称, 不填默认为Download
 @param progress 下载进度
 @param successBlock 成功回调
 @param failureBlock 失败回调
 @return task
 */
+ (LXURLSessionTask *)lx_downloadWithURL:(NSString *)URL
                                 fileDir:(NSString *)fileDir
                                progress:(LXHttpProgress)progress
                                 success:(LXResponseSuccess)successBlock
                                 failure:(LXResponseFail)failureBlock;

#pragma mark - 网络请求任务处理
/**
 当前请求任务集合

 @return 字典集合
 */
+ (NSMutableDictionary *)allTasks;

/**
 根据请求地址取消当前请求

 @param urlStr 请求地址
 */
+ (void)cancelCurrentRequest:(NSString *)urlStr;

/**
 取消当前所有网络请求
 */
+ (void)cancelAllRequset;





@end









