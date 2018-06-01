//
//   Copyright 2012 Square Inc.
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.
//

#import <Foundation/Foundation.h>
#import <Security/SecCertificate.h>

/**
 CONNECTING：值为0，表示正在连接。
 OPEN：值为1，表示连接成功，可以通信了。
 CLOSING：值为2，表示连接正在关闭。
 CLOSED：值为3，表示连接已经关闭，或者打开连接失败。
 */
typedef NS_ENUM(NSInteger, LXSRReadyState) {
    LXSR_CONNECTING   = 0,
    LXSR_OPEN         = 1,
    LXSR_CLOSING      = 2,
    LXSR_CLOSED       = 3,
};

typedef enum LXSRStatusCode : NSInteger {
    LXSRStatusCodeNormal = 1000,
    LXSRStatusCodeGoingAway = 1001,
    LXSRStatusCodeProtocolError = 1002,
    LXSRStatusCodeUnhandledType = 1003,
    // 1004 reserved.
    LXSRStatusNoStatusReceived = 1005,
    // 1004-1006 reserved.
    LXSRStatusCodeInvalidUTF8 = 1007,
    LXSRStatusCodePolicyViolated = 1008,
    LXSRStatusCodeMessageTooBig = 1009,
} LXSRStatusCode;

@class LXSRWebSocket;

extern NSString *const LXSRWebSocketErrorDomain;
extern NSString *const LXSRHTTPResponseErrorKey;

#pragma mark - LXSRWebSocketDelegate

@protocol LXSRWebSocketDelegate;

#pragma mark - LXSRWebSocket

@interface LXSRWebSocket : NSObject <NSStreamDelegate>

@property (nonatomic, weak) id <LXSRWebSocketDelegate> delegate;

@property (nonatomic, readonly) LXSRReadyState readyState;
@property (nonatomic, readonly, retain) NSURL *url;

// This returns the negotiated protocol.
// It will be nil until after the handshake completes.
@property (nonatomic, readonly, copy) NSString *protocol;

// Protocols should be an array of strings that turn into Sec-WebSocket-Protocol.
- (id)initWithURLRequest:(NSURLRequest *)request protocols:(NSArray *)protocols;
- (id)initWithURLRequest:(NSURLRequest *)request;

// Some helper constructors.
- (id)initWithURL:(NSURL *)url protocols:(NSArray *)protocols;
- (id)initWithURL:(NSURL *)url;

// Delegate queue will be dispatch_main_queue by default.
// You cannot set both OperationQueue and dispatch_queue.
- (void)setDelegateOperationQueue:(NSOperationQueue*) queue;
- (void)setDelegateDispatchQueue:(dispatch_queue_t) queue;

// By default, it will schedule itself on +[NSRunLoop SR_networkRunLoop] using defaultModes.
- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode;
- (void)unscheduleFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode;

// LXSRWebSockets are intended for one-time-use only.  Open should be called once and only once.
- (void)open;

- (void)close;
- (void)closeWithCode:(NSInteger)code reason:(NSString *)reason;

// Send a UTF8 String or Data.
- (void)send:(id)data;

// Send Data (can be nil) in a ping message.
- (void)sendPing:(NSData *)data;

@end

#pragma mark - LXSRWebSocketDelegate

@protocol LXSRWebSocketDelegate <NSObject>

// message will either be an NSString if the server is using text
// or NSData if the server is using binary.
- (void)webSocket:(LXSRWebSocket *)webSocket didReceiveMessage:(id)message;

@optional

- (void)webSocketDidOpen:(LXSRWebSocket *)webSocket;
- (void)webSocket:(LXSRWebSocket *)webSocket didFailWithError:(NSError *)error;
- (void)webSocket:(LXSRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;
- (void)webSocket:(LXSRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload;

@end

#pragma mark - NSURLRequest (CertificateAdditions)

@interface NSURLRequest (CertificateAdditions)

@property (nonatomic, retain, readonly) NSArray *LXSR_SSLPinnedCertificates;

@end

#pragma mark - NSMutableURLRequest (CertificateAdditions)

@interface NSMutableURLRequest (CertificateAdditions)

@property (nonatomic, retain) NSArray *LXSR_SSLPinnedCertificates;

@end

#pragma mark - NSRunLoop (LXSRWebSocket)

@interface NSRunLoop (LXSRWebSocket)

+ (NSRunLoop *)LXSR_networkRunLoop;

@end
