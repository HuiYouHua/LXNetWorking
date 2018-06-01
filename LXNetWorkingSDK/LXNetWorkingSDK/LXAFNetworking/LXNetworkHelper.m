//
//  LXNetworkHelper.m
//  LXNetWorkingSDK
//
//  Created by 华惠友 on 2018/3/21.
//  Copyright © 2018年 华惠友. All rights reserved.
//

#import "LXNetworkHelper.h"
#import "LXAFNetworking.h"
#import "LXAFNetworkActivityIndicatorManager.h"


#ifdef DEBUG
#define NSLog(...) NSLog(@"%s 第%d行 \n %@\n\n",__func__,__LINE__,[NSString stringWithFormat:__VA_ARGS__])
#else
#define NSLog(...)
#endif

/** 网络请求任务池 */
static NSMutableDictionary   *requestTasksPool;
/** 超时时间 */
static NSTimeInterval   requestTimeout = 20.f;

@implementation LXNetworkHelper

static NetworkStatusbBlock _status;
static BOOL _isNetwork;

///**
// *  获得全局唯一的网络请求实例单例方法
// *
// *  @return 网络请求类LXNetworkHelper单例
// */
//+ (instancetype)sharedManager {
//    static LXNetworkHelper *manager = nil;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        manager = [[self alloc] init];
//    });
//    return manager;
//}

+ (LXAFHTTPSessionManager *)sharedAFManager {
    
    //打开状态栏的等待菊花
    [LXAFNetworkActivityIndicatorManager sharedManager].enabled = YES;
    
    static LXAFHTTPSessionManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [LXAFHTTPSessionManager manager];
        
        // 设置超时时间
        manager.requestSerializer = [LXAFJSONRequestSerializer serializer];
        [manager.requestSerializer willChangeValueForKey:@"timeoutInterval"];
        manager.requestSerializer.timeoutInterval = 20.0f;
        [manager.requestSerializer didChangeValueForKey:@"timeoutInterval"];

        /*! 设置相应的缓存策略 */
        manager.requestSerializer.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        [manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        
        manager.responseSerializer = [LXAFJSONResponseSerializer serializer];
        /*! 设置响应数据的基本了类型 */
        manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json",
                                                             @"text/json",
                                                             @"text/javascript",
                                                             @"text/html",
                                                             @"text/css",
                                                             @"text/xml",
                                                             @"text/plain",
                                                             @"application/javascript", nil];
        
        /*! 2.设置非校验证书模式 */
        manager.securityPolicy = [LXAFSecurityPolicy policyWithPinningMode:LXAFSSLPinningModeNone];
        manager.securityPolicy.allowInvalidCertificates = YES;
        [manager.securityPolicy setValidatesDomainName:NO];
        
        
        /**
         校验证书模式
         manager.securityPolicy.SSLPinningMode = LXAFSSLPinningModeCertificate;
         //设置证书模式
         NSString * cerPath = [[NSBundle mainBundle] pathForResource:@"xxx" ofType:@"cer"];
         NSData * cerData = [NSData dataWithContentsOfFile:cerPath];
         manager.securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate withPinnedCertificates:[[NSSet alloc] initWithObjects:cerData, nil]];
         // 客户端是否信任非法证书
         mgr.securityPolicy.allowInvalidCertificates = YES;
         // 是否在证书域字段中验证域名
         [mgr.securityPolicy setValidatesDomainName:NO];
         
         */
        
    });
    
    return manager;
}

#pragma mark - 开始监听网络
+ (void)startMonitoringNetwork
{
    LXAFNetworkReachabilityManager *manager = [LXAFNetworkReachabilityManager sharedManager];
    
    [manager setReachabilityStatusChangeBlock:^(LXAFNetworkReachabilityStatus status) {
        switch (status)
        {
            case LXAFNetworkReachabilityStatusUnknown:
                _status ? _status(LXNetworkStatusUnknown) : nil;
                _isNetwork = NO;
                NSLog(@"未知网络");
                break;
            case LXAFNetworkReachabilityStatusNotReachable:
                _status ? _status(LXNetworkStatusNotReachable) : nil;
                _isNetwork = NO;
                NSLog(@"无网络");
                break;
            case LXAFNetworkReachabilityStatusReachableViaWWAN:
                _status ? _status(LXNetworkStatusReachableViaWWAN) : nil;
                _isNetwork = YES;
                NSLog(@"手机自带网络");
                break;
            case LXAFNetworkReachabilityStatusReachableViaWiFi:
                _status ? _status(LXNetworkStatusReachableViaWiFi) : nil;
                _isNetwork = YES;
                NSLog(@"WIFI");
                break;
        }
    }];
    [manager startMonitoring];
    
}

+ (void)checkNetworkStatusWithBlock:(NetworkStatusbBlock)status
{
    status ? _status = status : nil;
}

+ (BOOL)currentNetworkStatus
{
    return _isNetwork;
}

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
                      withFailureBlock:(LXResponseFail)failureBlock {
    return [self lx_requestWithType:type withSubMethod:subMethod withParameters:parameters showHUD:showHUD modeleClass:nil withSuccessBlock:successBlock withFailureBlock:failureBlock];
}

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
                      withFailureBlock:(LXResponseFail)failureBlock {
    return [self lx_requestWithType:type withSubMethod:subMethod withParameters:parameters showHUD:showHUD timeOut:requestTimeout modeleClass:modelClassStr withSuccessBlock:successBlock withFailureBlock:failureBlock];
}

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
                      withFailureBlock:(LXResponseFail)failureBlock {
    
    LXAFHTTPSessionManager *manager = [self sharedAFManager];
    // 设置超时时间
    [manager.requestSerializer setTimeoutInterval:timeOut];
    
    if (showHUD) {
        // 开始发起网络请求, 显示加载视图菊花转
        [LXCommonHelp showProgressHUD];
    }
    
    // 在这里可以进行加密或拼接url以及参数处理
    // TODO...
    
    
    LXURLSessionTask *sessionTask = nil;
    switch (type) {
        case LXHttpRequestTypeGet: { // GET 请求
            
            sessionTask = [manager GET:urlStr parameters:parameters progress:^(NSProgress * _Nonnull downloadProgress) {
                
            } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                
                if (showHUD) {
                    [LXCommonHelp hideProgressHUD];
                }
                
                // 有模型 转模型
                if (modelClassStr.length > 0) {
                    id objClass = [[NSClassFromString(modelClassStr) alloc] initWithDictionary:responseObject error:nil];
                    successBlock ? successBlock(objClass) : nil;
                    return ;
                }
                
                successBlock ? successBlock(responseObject) : nil;
                
                [[self allTasks] removeObjectForKey:urlStr];
                
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                
                if (showHUD) {
                    [LXCommonHelp hideProgressHUD];
                }
                
                failureBlock ? failureBlock(error) : nil;

                [[self allTasks] removeObjectForKey:urlStr];
            }];
            
        }
            break;
        case LXHttpRequestTypePost: { // POST 请求
            sessionTask = [manager POST:urlStr parameters:parameters progress:^(NSProgress * _Nonnull uploadProgress) {
                
            } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                
                if (showHUD) {
                    [LXCommonHelp hideProgressHUD];
                }
                
                // 有模型 转模型
                if (modelClassStr.length > 0) {
                    id objClass = [[NSClassFromString(modelClassStr) alloc] initWithDictionary:responseObject error:nil];
                    successBlock ? successBlock(objClass) : nil;
                    return ;
                }
                
                successBlock ? successBlock(responseObject) : nil;
                
                [[self allTasks] removeObjectForKey:urlStr];
                
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                
                if (showHUD) {
                    [LXCommonHelp hideProgressHUD];
                }
                
                failureBlock ? failureBlock(error) : nil;
                
                [[self allTasks] removeObjectForKey:urlStr];
                
            }];
        }
            break;
        default:
            break;
    }
    
    if (sessionTask) {
        [[self allTasks] setObject:sessionTask forKey:urlStr];
    }
    return sessionTask;
}

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
                                  failure:(LXResponseFail)failureBlock {
    
    LXAFHTTPSessionManager *manager = [self sharedAFManager];
    
    if (showHUD) {
        // 开始发起网络请求, 显示加载视图菊花转
        [LXCommonHelp showProgressHUD];
    }
    
    LXURLSessionTask *sessionTask = nil;
    sessionTask = [manager POST:urlStr parameters:parameters constructingBodyWithBlock:^(id<LXAFMultipartFormData>  _Nonnull formData) {
        
        //压缩-添加-上传图片
        NSData *imageData = UIImageJPEGRepresentation(image, 0.5);
        [formData appendPartWithFileData:imageData name:name fileName:[NSString stringWithFormat:@"%@1.%@",fileName,mimeType?mimeType:@"jpeg"] mimeType:[NSString stringWithFormat:@"image/%@",mimeType?mimeType:@"jpeg"]];
        
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        //上传进度
        progress ? progress(uploadProgress) : nil;
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        if (showHUD) {
            [LXCommonHelp hideProgressHUD];
        }
        
        successBlock ? successBlock(responseObject) : nil;
        
        [[self allTasks] removeObjectForKey:urlStr];
        
        NSLog(@"responseObject = %@",responseObject);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        if (showHUD) {
            [LXCommonHelp hideProgressHUD];
        }
        
        failureBlock ? failureBlock(error) : nil;
        
        [[self allTasks] removeObjectForKey:urlStr];
        
        NSLog(@"error = %@",error);
    }];
    
    if (sessionTask) {
        [[self allTasks] setObject:sessionTask forKey:urlStr];
    }
    return sessionTask;
}


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
                                   failure:(LXResponseFail)failureBlock {
    
    LXAFHTTPSessionManager *manager = [self sharedAFManager];
    
    if (showHUD) {
        // 开始发起网络请求, 显示加载视图菊花转
        [LXCommonHelp showProgressHUD];
    }
    
    LXURLSessionTask *sessionTask = nil;
    sessionTask = [manager POST:urlStr parameters:parameters constructingBodyWithBlock:^(id<LXAFMultipartFormData>  _Nonnull formData) {
        
        //压缩-添加-上传图片
        [images enumerateObjectsUsingBlock:^(UIImage * _Nonnull image, NSUInteger idx, BOOL * _Nonnull stop) {
            
            NSData *imageData = UIImageJPEGRepresentation(image, 0.5);
            [formData appendPartWithFileData:imageData name:name fileName:[NSString stringWithFormat:@"%@%lu.%@",fileName,(unsigned long)idx,mimeType?mimeType:@"jpeg"] mimeType:[NSString stringWithFormat:@"image/%@",mimeType?mimeType:@"jpeg"]];
        }];
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        //上传进度
        progress ? progress(uploadProgress) : nil;
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        if (showHUD) {
            [LXCommonHelp hideProgressHUD];
        }
        
        successBlock ? successBlock(responseObject) : nil;
        
        [[self allTasks] removeObjectForKey:urlStr];
        
        NSLog(@"responseObject = %@",responseObject);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        if (showHUD) {
            [LXCommonHelp hideProgressHUD];
        }
        
        failureBlock ? failureBlock(error) : nil;
        
        [[self allTasks] removeObjectForKey:urlStr];
        
        NSLog(@"error = %@",error);
    }];
    
    if (sessionTask) {
        [[self allTasks] setObject:sessionTask forKey:urlStr];
    }
    return sessionTask;
}

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
                               failure:(LXResponseFail)failureBlock {
    LXAFHTTPSessionManager *manager = [self sharedAFManager];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:URL]];
    
    NSURLSessionDownloadTask *downloadTask = nil;
    downloadTask = [manager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
        //下载进度
        progress ? progress(downloadProgress) : nil;
        NSLog(@"下载进度:%.2f%%",100.0*downloadProgress.completedUnitCount/downloadProgress.totalUnitCount);
        
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        
        //拼接缓存目录
        NSString *downloadDir = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:fileDir ? fileDir : @"Download"];
        //打开文件管理器
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        //创建Download目录
        [fileManager createDirectoryAtPath:downloadDir withIntermediateDirectories:YES attributes:nil error:nil];
        
        //拼接文件路径
        NSString *filePath = [downloadDir stringByAppendingPathComponent:response.suggestedFilename];
        
        NSLog(@"downloadDir = %@",downloadDir);
        
        //返回文件位置的URL路径
        return [NSURL fileURLWithPath:filePath];
        
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        
        [[self allTasks] removeObjectForKey:URL];
        
        NSString *path = [[filePath.absoluteString componentsSeparatedByString:@"file://"] lastObject];
        successBlock && filePath ? successBlock(path) : nil;

        failureBlock && error ? failureBlock(error) : nil;
        
    }];
    
    //开始下载
    [downloadTask resume];

    if (downloadTask) {
        [[self allTasks] setObject:downloadTask forKey:URL];
    }
    return downloadTask;
    
}

#pragma mark - 网络请求任务处理
// 当前任务集合
+ (NSMutableDictionary *)allTasks {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!requestTasksPool)
            requestTasksPool = [NSMutableDictionary dictionary];
    });
    
    return requestTasksPool;
}

// 取消当前请求
+ (void)cancelCurrentRequest:(NSString *)urlStr {
    LXURLSessionTask *task = [[self allTasks] objectForKey:urlStr];
    [task cancel];

//    [[self allTasks] removeObjectForKey:url];
    
}

// 取消所有请求
+ (void)cancelAllRequset {
    for (NSString *urlStr in [self allTasks]) {
        LXURLSessionTask *task = [[self allTasks] objectForKey:urlStr];
        [task cancel];
    }
    
//    [[self allTasks] removeAllObjects];
}




@end
