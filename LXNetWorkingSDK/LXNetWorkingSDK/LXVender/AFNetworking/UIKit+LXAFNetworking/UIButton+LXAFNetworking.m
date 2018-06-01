// UIButton+LXAFNetworking.m
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

#import "UIButton+LXAFNetworking.h"

#import <objc/runtime.h>

#if TARGET_OS_IOS || TARGET_OS_TV

#import "UIImageView+LXAFNetworking.h"
#import "LXAFImageDownloader.h"

@interface UIButton (_LXAFNetworking)
@end

@implementation UIButton (_LXAFNetworking)

#pragma mark -

static char LXAFImageDownloadReceiptNormal;
static char LXAFImageDownloadReceiptHighlighted;
static char LXAFImageDownloadReceiptSelected;
static char LXAFImageDownloadReceiptDisabled;

static const char * lxaf_imageDownloadReceiptKeyForState(UIControlState state) {
    switch (state) {
        case UIControlStateHighlighted:
            return &LXAFImageDownloadReceiptHighlighted;
        case UIControlStateSelected:
            return &LXAFImageDownloadReceiptSelected;
        case UIControlStateDisabled:
            return &LXAFImageDownloadReceiptDisabled;
        case UIControlStateNormal:
        default:
            return &LXAFImageDownloadReceiptNormal;
    }
}

- (LXAFImageDownloadReceipt *)lxaf_imageDownloadReceiptForState:(UIControlState)state {
    return (LXAFImageDownloadReceipt *)objc_getAssociatedObject(self, lxaf_imageDownloadReceiptKeyForState(state));
}

- (void)lxaf_setImageDownloadReceipt:(LXAFImageDownloadReceipt *)imageDownloadReceipt
                           forState:(UIControlState)state
{
    objc_setAssociatedObject(self, lxaf_imageDownloadReceiptKeyForState(state), imageDownloadReceipt, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark -

static char LXAFBackgroundImageDownloadReceiptNormal;
static char LXAFBackgroundImageDownloadReceiptHighlighted;
static char LXAFBackgroundImageDownloadReceiptSelected;
static char LXAFBackgroundImageDownloadReceiptDisabled;

static const char * lxaf_backgroundImageDownloadReceiptKeyForState(UIControlState state) {
    switch (state) {
        case UIControlStateHighlighted:
            return &LXAFBackgroundImageDownloadReceiptHighlighted;
        case UIControlStateSelected:
            return &LXAFBackgroundImageDownloadReceiptSelected;
        case UIControlStateDisabled:
            return &LXAFBackgroundImageDownloadReceiptDisabled;
        case UIControlStateNormal:
        default:
            return &LXAFBackgroundImageDownloadReceiptNormal;
    }
}

- (LXAFImageDownloadReceipt *)lxaf_backgroundImageDownloadReceiptForState:(UIControlState)state {
    return (LXAFImageDownloadReceipt *)objc_getAssociatedObject(self, lxaf_backgroundImageDownloadReceiptKeyForState(state));
}

- (void)lxaf_setBackgroundImageDownloadReceipt:(LXAFImageDownloadReceipt *)imageDownloadReceipt
                                     forState:(UIControlState)state
{
    objc_setAssociatedObject(self, lxaf_backgroundImageDownloadReceiptKeyForState(state), imageDownloadReceipt, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#pragma mark -

@implementation UIButton (LXAFNetworking)

+ (LXAFImageDownloader *)sharedImageDownloader {

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
    return objc_getAssociatedObject(self, @selector(sharedImageDownloader)) ?: [LXAFImageDownloader defaultInstance];
#pragma clang diagnostic pop
}

+ (void)setSharedImageDownloader:(LXAFImageDownloader *)imageDownloader {
    objc_setAssociatedObject(self, @selector(sharedImageDownloader), imageDownloader, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark -

- (void)setImageForState:(UIControlState)state
                 withURL:(NSURL *)url
{
    [self setImageForState:state withURL:url placeholderImage:nil];
}

- (void)setImageForState:(UIControlState)state
                 withURL:(NSURL *)url
        placeholderImage:(UIImage *)placeholderImage
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];

    [self setImageForState:state withURLRequest:request placeholderImage:placeholderImage success:nil failure:nil];
}

- (void)setImageForState:(UIControlState)state
          withURLRequest:(NSURLRequest *)urlRequest
        placeholderImage:(nullable UIImage *)placeholderImage
                 success:(nullable void (^)(NSURLRequest *request, NSHTTPURLResponse * _Nullable response, UIImage *image))success
                 failure:(nullable void (^)(NSURLRequest *request, NSHTTPURLResponse * _Nullable response, NSError *error))failure
{
    if ([self isActiveTaskURLEqualToURLRequest:urlRequest forState:state]) {
        return;
    }

    [self cancelImageDownloadTaskForState:state];

    LXAFImageDownloader *downloader = [[self class] sharedImageDownloader];
    id <LXAFImageRequestCache> imageCache = downloader.imageCache;

    //Use the image from the image cache if it exists
    UIImage *cachedImage = [imageCache imageforRequest:urlRequest withAdditionalIdentifier:nil];
    if (cachedImage) {
        if (success) {
            success(urlRequest, nil, cachedImage);
        } else {
            [self setImage:cachedImage forState:state];
        }
        [self lxaf_setImageDownloadReceipt:nil forState:state];
    } else {
        if (placeholderImage) {
            [self setImage:placeholderImage forState:state];
        }

        __weak __typeof(self)weakSelf = self;
        NSUUID *downloadID = [NSUUID UUID];
        LXAFImageDownloadReceipt *receipt;
        receipt = [downloader
                   downloadImageForURLRequest:urlRequest
                   withReceiptID:downloadID
                   success:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nullable response, UIImage * _Nonnull responseObject) {
                       __strong __typeof(weakSelf)strongSelf = weakSelf;
                       if ([[strongSelf lxaf_imageDownloadReceiptForState:state].receiptID isEqual:downloadID]) {
                           if (success) {
                               success(request, response, responseObject);
                           } else if(responseObject) {
                               [strongSelf setImage:responseObject forState:state];
                           }
                           [strongSelf lxaf_setImageDownloadReceipt:nil forState:state];
                       }

                   }
                   failure:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nullable response, NSError * _Nonnull error) {
                       __strong __typeof(weakSelf)strongSelf = weakSelf;
                       if ([[strongSelf lxaf_imageDownloadReceiptForState:state].receiptID isEqual:downloadID]) {
                           if (failure) {
                               failure(request, response, error);
                           }
                           [strongSelf  lxaf_setImageDownloadReceipt:nil forState:state];
                       }
                   }];

        [self lxaf_setImageDownloadReceipt:receipt forState:state];
    }
}

#pragma mark -

- (void)setBackgroundImageForState:(UIControlState)state
                           withURL:(NSURL *)url
{
    [self setBackgroundImageForState:state withURL:url placeholderImage:nil];
}

- (void)setBackgroundImageForState:(UIControlState)state
                           withURL:(NSURL *)url
                  placeholderImage:(nullable UIImage *)placeholderImage
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];

    [self setBackgroundImageForState:state withURLRequest:request placeholderImage:placeholderImage success:nil failure:nil];
}

- (void)setBackgroundImageForState:(UIControlState)state
                    withURLRequest:(NSURLRequest *)urlRequest
                  placeholderImage:(nullable UIImage *)placeholderImage
                           success:(nullable void (^)(NSURLRequest *request, NSHTTPURLResponse * _Nullable response, UIImage *image))success
                           failure:(nullable void (^)(NSURLRequest *request, NSHTTPURLResponse * _Nullable response, NSError *error))failure
{
    if ([self isActiveBackgroundTaskURLEqualToURLRequest:urlRequest forState:state]) {
        return;
    }

    [self cancelBackgroundImageDownloadTaskForState:state];

    LXAFImageDownloader *downloader = [[self class] sharedImageDownloader];
    id <LXAFImageRequestCache> imageCache = downloader.imageCache;

    //Use the image from the image cache if it exists
    UIImage *cachedImage = [imageCache imageforRequest:urlRequest withAdditionalIdentifier:nil];
    if (cachedImage) {
        if (success) {
            success(urlRequest, nil, cachedImage);
        } else {
            [self setBackgroundImage:cachedImage forState:state];
        }
        [self lxaf_setBackgroundImageDownloadReceipt:nil forState:state];
    } else {
        if (placeholderImage) {
            [self setBackgroundImage:placeholderImage forState:state];
        }

        __weak __typeof(self)weakSelf = self;
        NSUUID *downloadID = [NSUUID UUID];
        LXAFImageDownloadReceipt *receipt;
        receipt = [downloader
                   downloadImageForURLRequest:urlRequest
                   withReceiptID:downloadID
                   success:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nullable response, UIImage * _Nonnull responseObject) {
                       __strong __typeof(weakSelf)strongSelf = weakSelf;
                       if ([[strongSelf lxaf_backgroundImageDownloadReceiptForState:state].receiptID isEqual:downloadID]) {
                           if (success) {
                               success(request, response, responseObject);
                           } else if(responseObject) {
                               [strongSelf setBackgroundImage:responseObject forState:state];
                           }
                           [strongSelf lxaf_setBackgroundImageDownloadReceipt:nil forState:state];
                       }

                   }
                   failure:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nullable response, NSError * _Nonnull error) {
                       __strong __typeof(weakSelf)strongSelf = weakSelf;
                       if ([[strongSelf lxaf_backgroundImageDownloadReceiptForState:state].receiptID isEqual:downloadID]) {
                           if (failure) {
                               failure(request, response, error);
                           }
                           [strongSelf  lxaf_setBackgroundImageDownloadReceipt:nil forState:state];
                       }
                   }];

        [self lxaf_setBackgroundImageDownloadReceipt:receipt forState:state];
    }
}

#pragma mark -

- (void)cancelImageDownloadTaskForState:(UIControlState)state {
    LXAFImageDownloadReceipt *receipt = [self lxaf_imageDownloadReceiptForState:state];
    if (receipt != nil) {
        [[self.class sharedImageDownloader] cancelTaskForImageDownloadReceipt:receipt];
        [self lxaf_setImageDownloadReceipt:nil forState:state];
    }
}

- (void)cancelBackgroundImageDownloadTaskForState:(UIControlState)state {
    LXAFImageDownloadReceipt *receipt = [self lxaf_backgroundImageDownloadReceiptForState:state];
    if (receipt != nil) {
        [[self.class sharedImageDownloader] cancelTaskForImageDownloadReceipt:receipt];
        [self lxaf_setBackgroundImageDownloadReceipt:nil forState:state];
    }
}

- (BOOL)isActiveTaskURLEqualToURLRequest:(NSURLRequest *)urlRequest forState:(UIControlState)state {
    LXAFImageDownloadReceipt *receipt = [self lxaf_imageDownloadReceiptForState:state];
    return [receipt.task.originalRequest.URL.absoluteString isEqualToString:urlRequest.URL.absoluteString];
}

- (BOOL)isActiveBackgroundTaskURLEqualToURLRequest:(NSURLRequest *)urlRequest forState:(UIControlState)state {
    LXAFImageDownloadReceipt *receipt = [self lxaf_backgroundImageDownloadReceiptForState:state];
    return [receipt.task.originalRequest.URL.absoluteString isEqualToString:urlRequest.URL.absoluteString];
}


@end

#endif
