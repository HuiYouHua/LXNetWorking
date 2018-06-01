// UIWebView+LXAFNetworking.m
// Copyright (c) 2011–2016 Alamofire Software Foundation ( http://alamofire.org/ )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "UIWebView+LXAFNetworking.h"

#import <objc/runtime.h>

#if TARGET_OS_IOS

#import "LXAFHTTPSessionManager.h"
#import "LXAFURLResponseSerialization.h"
#import "LXAFURLRequestSerialization.h"

@interface UIWebView (_AFNetworking)
@property (readwrite, nonatomic, strong, setter = lxaf_setURLSessionTask:) NSURLSessionDataTask *lxaf_URLSessionTask;
@end

@implementation UIWebView (_LXAFNetworking)

- (NSURLSessionDataTask *)lxaf_URLSessionTask {
    return (NSURLSessionDataTask *)objc_getAssociatedObject(self, @selector(lxaf_URLSessionTask));
}

- (void)lxaf_setURLSessionTask:(NSURLSessionDataTask *)lxaf_URLSessionTask {
    objc_setAssociatedObject(self, @selector(lxaf_URLSessionTask), lxaf_URLSessionTask, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#pragma mark -

@implementation UIWebView (LXAFNetworking)

- (LXAFHTTPSessionManager  *)sessionManager {
    static LXAFHTTPSessionManager *_lxaf_defaultHTTPSessionManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _lxaf_defaultHTTPSessionManager = [[LXAFHTTPSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        _lxaf_defaultHTTPSessionManager.requestSerializer = [LXAFHTTPRequestSerializer serializer];
        _lxaf_defaultHTTPSessionManager.responseSerializer = [LXAFHTTPResponseSerializer serializer];
    });

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
    return objc_getAssociatedObject(self, @selector(sessionManager)) ?: _lxaf_defaultHTTPSessionManager;
#pragma clang diagnostic pop
}

- (void)setSessionManager:(LXAFHTTPSessionManager *)sessionManager {
    objc_setAssociatedObject(self, @selector(sessionManager), sessionManager, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (LXAFHTTPResponseSerializer <LXAFURLResponseSerialization> *)responseSerializer {
    static LXAFHTTPResponseSerializer <LXAFURLResponseSerialization> *_lxaf_defaultResponseSerializer = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _lxaf_defaultResponseSerializer = [LXAFHTTPResponseSerializer serializer];
    });

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
    return objc_getAssociatedObject(self, @selector(responseSerializer)) ?: _lxaf_defaultResponseSerializer;
#pragma clang diagnostic pop
}

- (void)setResponseSerializer:(LXAFHTTPResponseSerializer<LXAFURLResponseSerialization> *)responseSerializer {
    objc_setAssociatedObject(self, @selector(responseSerializer), responseSerializer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark -

- (void)loadRequest:(NSURLRequest *)request
           progress:(NSProgress * _Nullable __autoreleasing * _Nullable)progress
            success:(NSString * (^)(NSHTTPURLResponse *response, NSString *HTML))success
            failure:(void (^)(NSError *error))failure
{
    [self loadRequest:request MIMEType:nil textEncodingName:nil progress:progress success:^NSData *(NSHTTPURLResponse *response, NSData *data) {
        NSStringEncoding stringEncoding = NSUTF8StringEncoding;
        if (response.textEncodingName) {
            CFStringEncoding encoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef)response.textEncodingName);
            if (encoding != kCFStringEncodingInvalidId) {
                stringEncoding = CFStringConvertEncodingToNSStringEncoding(encoding);
            }
        }

        NSString *string = [[NSString alloc] initWithData:data encoding:stringEncoding];
        if (success) {
            string = success(response, string);
        }

        return [string dataUsingEncoding:stringEncoding];
    } failure:failure];
}

- (void)loadRequest:(NSURLRequest *)request
           MIMEType:(NSString *)MIMEType
   textEncodingName:(NSString *)textEncodingName
           progress:(NSProgress * _Nullable __autoreleasing * _Nullable)progress
            success:(NSData * (^)(NSHTTPURLResponse *response, NSData *data))success
            failure:(void (^)(NSError *error))failure
{
    NSParameterAssert(request);

    if (self.lxaf_URLSessionTask.state == NSURLSessionTaskStateRunning || self.lxaf_URLSessionTask.state == NSURLSessionTaskStateSuspended) {
        [self.lxaf_URLSessionTask cancel];
    }
    self.lxaf_URLSessionTask = nil;

    __weak __typeof(self)weakSelf = self;
    NSURLSessionDataTask *dataTask;
    dataTask = [self.sessionManager
            GET:request.URL.absoluteString
            parameters:nil
            progress:nil
            success:^(NSURLSessionDataTask * _Nonnull task, id  _Nonnull responseObject) {
                __strong __typeof(weakSelf) strongSelf = weakSelf;
                if (success) {
                    success((NSHTTPURLResponse *)task.response, responseObject);
                }
                [strongSelf loadData:responseObject MIMEType:MIMEType textEncodingName:textEncodingName baseURL:[task.currentRequest URL]];

                if ([strongSelf.delegate respondsToSelector:@selector(webViewDidStartLoad:)]) {
                    [strongSelf.delegate webViewDidFinishLoad:strongSelf];
                }
            }
            failure:^(NSURLSessionDataTask * _Nonnull task, NSError * _Nonnull error) {
                if (failure) {
                    failure(error);
                }
            }];
    self.lxaf_URLSessionTask = dataTask;
    if (progress != nil) {
        *progress = [self.sessionManager downloadProgressForTask:dataTask];
    }
    [self.lxaf_URLSessionTask resume];

    if ([self.delegate respondsToSelector:@selector(webViewDidStartLoad:)]) {
        [self.delegate webViewDidStartLoad:self];
    }
}

@end

#endif
