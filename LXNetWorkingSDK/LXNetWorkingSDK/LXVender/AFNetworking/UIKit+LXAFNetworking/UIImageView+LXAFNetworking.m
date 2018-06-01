// UIImageView+LXAFNetworking.m
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

#import "UIImageView+LXAFNetworking.h"

#import <objc/runtime.h>

#if TARGET_OS_IOS || TARGET_OS_TV

#import "LXAFImageDownloader.h"

@interface UIImageView (_LXAFNetworking)
@property (readwrite, nonatomic, strong, setter = lxaf_setActiveImageDownloadReceipt:) LXAFImageDownloadReceipt *lxaf_activeImageDownloadReceipt;
@end

@implementation UIImageView (_LXAFNetworking)

- (LXAFImageDownloadReceipt *)lxaf_activeImageDownloadReceipt {
    return (LXAFImageDownloadReceipt *)objc_getAssociatedObject(self, @selector(lxaf_activeImageDownloadReceipt));
}

- (void)lxaf_setActiveImageDownloadReceipt:(LXAFImageDownloadReceipt *)imageDownloadReceipt {
    objc_setAssociatedObject(self, @selector(lxaf_activeImageDownloadReceipt), imageDownloadReceipt, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#pragma mark -

@implementation UIImageView (LXAFNetworking)

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

- (void)setImageWithURL:(NSURL *)url {
    [self setImageWithURL:url placeholderImage:nil];
}

- (void)setImageWithURL:(NSURL *)url
       placeholderImage:(UIImage *)placeholderImage
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];

    [self setImageWithURLRequest:request placeholderImage:placeholderImage success:nil failure:nil];
}

- (void)setImageWithURLRequest:(NSURLRequest *)urlRequest
              placeholderImage:(UIImage *)placeholderImage
                       success:(void (^)(NSURLRequest *request, NSHTTPURLResponse * _Nullable response, UIImage *image))success
                       failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse * _Nullable response, NSError *error))failure
{

    if ([urlRequest URL] == nil) {
        [self cancelImageDownloadTask];
        self.image = placeholderImage;
        return;
    }

    if ([self isActiveTaskURLEqualToURLRequest:urlRequest]){
        return;
    }

    [self cancelImageDownloadTask];

    LXAFImageDownloader *downloader = [[self class] sharedImageDownloader];
    id <LXAFImageRequestCache> imageCache = downloader.imageCache;

    //Use the image from the image cache if it exists
    UIImage *cachedImage = [imageCache imageforRequest:urlRequest withAdditionalIdentifier:nil];
    if (cachedImage) {
        if (success) {
            success(urlRequest, nil, cachedImage);
        } else {
            self.image = cachedImage;
        }
        [self clearActiveDownloadInformation];
    } else {
        if (placeholderImage) {
            self.image = placeholderImage;
        }

        __weak __typeof(self)weakSelf = self;
        NSUUID *downloadID = [NSUUID UUID];
        LXAFImageDownloadReceipt *receipt;
        receipt = [downloader
                   downloadImageForURLRequest:urlRequest
                   withReceiptID:downloadID
                   success:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nullable response, UIImage * _Nonnull responseObject) {
                       __strong __typeof(weakSelf)strongSelf = weakSelf;
                       if ([strongSelf.lxaf_activeImageDownloadReceipt.receiptID isEqual:downloadID]) {
                           if (success) {
                               success(request, response, responseObject);
                           } else if(responseObject) {
                               strongSelf.image = responseObject;
                           }
                           [strongSelf clearActiveDownloadInformation];
                       }

                   }
                   failure:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nullable response, NSError * _Nonnull error) {
                       __strong __typeof(weakSelf)strongSelf = weakSelf;
                        if ([strongSelf.lxaf_activeImageDownloadReceipt.receiptID isEqual:downloadID]) {
                            if (failure) {
                                failure(request, response, error);
                            }
                            [strongSelf clearActiveDownloadInformation];
                        }
                   }];

        self.lxaf_activeImageDownloadReceipt = receipt;
    }
}

- (void)cancelImageDownloadTask {
    if (self.lxaf_activeImageDownloadReceipt != nil) {
        [[self.class sharedImageDownloader] cancelTaskForImageDownloadReceipt:self.lxaf_activeImageDownloadReceipt];
        [self clearActiveDownloadInformation];
     }
}

- (void)clearActiveDownloadInformation {
    self.lxaf_activeImageDownloadReceipt = nil;
}

- (BOOL)isActiveTaskURLEqualToURLRequest:(NSURLRequest *)urlRequest {
    return [self.lxaf_activeImageDownloadReceipt.task.originalRequest.URL.absoluteString isEqualToString:urlRequest.URL.absoluteString];
}

@end

#endif
