//
//  LXSocketManager.m
//  LXNetWorkingSDK
//
//  Created by 华惠友 on 2018/3/20.
//  Copyright © 2018年 华惠友. All rights reserved.
//

#import "LXSocketManager.h"
#import "LXSRWebSocket.h"
#import "LXAFNetworkReachabilityManager.h"

NSString *const  WebSocketNeedReconnectNotification = @"WebSocketNeedReconnectNotification";

//打印log
#if 1
#define DefLog(format,...) NSLog(format,##__VA_ARGS__)
#else
#define DefLog(format,...)
#endif

#define DSystemVersion          ([[[UIDevice currentDevice] systemVersion] doubleValue])
#define ksystemMoreThanEight (DSystemVersion>=8.2 ? YES : NO)

#define dispatch_main_async_safe(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}

#define WeakSelf(type)  __weak typeof(type) weak##type = type;

@interface LXSocketManager()<LXSRWebSocketDelegate> {
    NSTimer *_heartBeat; // 心跳
    NSTimeInterval _reConnectTime; //  重连时间
}

@property (nonatomic,strong) LXSRWebSocket *socket;
@property (nonatomic, copy) void (^readyStateBlock)(LXSRReadyState state); // 当发送消息时,Socket断掉重连后,继续发送未发送的消息

@end

@implementation LXSocketManager



+ (instancetype)shareInstance {
    static LXSocketManager *manager = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[LXSocketManager alloc]init];
        [manager addAppStateNotification];
        
    });
    return manager;
}

// 开始连接
- (void)connect {
    // 如果Socket连接存在 return
    if (self.socket) {
        return;
    }
    
    // 连接成功了, return
    if(self.socket.readyState == LXSR_OPEN){
        return;
    }
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:self.urlString]];
    self.socket = [[LXSRWebSocket alloc] initWithURLRequest:request];
    self.socket.delegate = self;   //实现这个 SRWebSocketDelegate 协议
    [self.socket open];     //open 就是直接连接了
}

// 断开连接
- (void)close {
    if (self.socket){
        [self.socket close];
        self.socket.delegate = nil;
        self.socket = nil;
        //断开连接时销毁心跳
        [self destoryHeartBeat];
        // 连接成功后,开始网络监听

        NSLog(@"************************** socket 断开连接************************** ");
    }
}

// 重连机制 state: 重连失败成功回调
- (void)reConnect:(void(^)(LXSRReadyState state))readyStateBlock {
    [self close];
    // 重连8次
    if (_reConnectTime > 128*2) {
        //您的网络状况不是很好，请检查网络后重试
        return;
    }
    WeakSelf(self)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_reConnectTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        weakself.socket = nil;
        [weakself connect];
        if (readyStateBlock) {
            weakself.readyStateBlock = readyStateBlock;
        }
        NSLog(@"socket重连");
    });
    
    // 重连时间2的指数级增长
    if (_reConnectTime == 0) {
        _reConnectTime = 2;
    }else{
        _reConnectTime *= 2;
    }
    
}

#pragma mark - LXSRWebSocketDelegate

/*
    连接成功
    登录服务器
    开启心跳
 */
- (void)webSocketDidOpen:(LXSRWebSocket *)webSocket {
    // 每次正常连接的时候清零重连时间
    _reConnectTime = 0;
    // 重连成功, 返回结果
    if (self.readyStateBlock) {
        self.readyStateBlock(self.socket.readyState);
    }

    // 回调到外面通知socket连接状态
    if (self.socketStateBlock) {
        self.socketStateBlock(self.socketState);
    }
    
    // 开启心跳
    [self initHeartBeat];
    if (webSocket == self.socket) {
        NSLog(@"************************** socket 连接成功************************** ");
    }
}

/*
    连接失败
    判断网络环境,是否需要发起重连(如果还有场景判断则还可加上场景)
    重连次数限制
 */
- (void)webSocket:(LXSRWebSocket *)webSocket didFailWithError:(NSError *)error {
    // 重连成功, 返回结果
    if (self.readyStateBlock) {
        // 重连失败, 返回结果
        self.readyStateBlock(self.socket.readyState);
    }
    
    // 回调到外面通知socket连接状态
    if (self.socketStateBlock) {
        self.socketStateBlock(self.socketState);
    }
    
    BOOL reachable = [LXAFNetworkReachabilityManager sharedManager].networkReachabilityStatus;
    if (!reachable) { // 当前网络不通
        return;
    }
    if (webSocket == self.socket) {
        NSLog(@"************************** socket 连接失败************************** ");
        _socket = nil;
        //连接失败就重连
        [self reConnect:nil];
    }
}

/*
    连接关闭
    注意连接关闭不是连接断开，关闭是 [socket close] 客户端主动关闭，断开可能是断网了，被动断开的。
 */
- (void)webSocket:(LXSRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    // 回调到外面通知socket连接状态
    if (self.socketStateBlock) {
        self.socketStateBlock(self.socketState);
    }
    
    if (webSocket == self.socket) {
        NSLog(@"socket被关闭连接，code:%ld,reason:%@,wasClean:%d",(long)code,reason,wasClean);
        [self close];
    }
}

/*
 该函数是接收服务器发送的pong消息，其中最后一个是接受pong消息的，
 在这里就要提一下心跳包，一般情况下建立长连接都会建立一个心跳包，
 用于每隔一段时间通知一次服务端，客户端还是在线，这个心跳包其实就是一个ping消息，
 我的理解就是建立一个定时器，每隔十秒或者十五秒向服务端发送一个ping消息，这个消息可是是空的
 */
- (void)webSocket:(LXSRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload {
//    NSString *reply = [[NSString alloc] initWithData:pongPayload encoding:NSUTF8StringEncoding];
}

/*
    收到服务器发来的数据
    由于message是 id类型的
    所以其数据类型需要跟服务器协商返回的是什么类型的, 再进行解析
 */
- (void)webSocket:(LXSRWebSocket *)webSocket didReceiveMessage:(id)message {
    if (webSocket == self.socket) {
        //        NSLog(@"************************** socket收到数据了************************** ");
        //        NSLog(@"socket:%@",message);
        if(!message){
            return;
        }
        self.didReceiveMessage ? self.didReceiveMessage(message) : nil;
    }
}

#pragma mark - 心跳
- (void)initHeartBeat {
    dispatch_main_async_safe(^{
        [self destoryHeartBeat];
        if (!self.heartTime) {
            self.heartTime = 5.0f;
        }
        _heartBeat = [NSTimer timerWithTimeInterval:self.heartTime target:self selector:@selector(sendPing) userInfo:nil repeats:YES];
        //和服务端约定好发送什么作为心跳标识，尽可能的减小心跳包大小
        [[NSRunLoop currentRunLoop] addTimer:_heartBeat forMode:NSRunLoopCommonModes];
    })
}


// 取消心跳
- (void)destoryHeartBeat {
    dispatch_main_async_safe(^{
        if (_heartBeat) {
            if ([_heartBeat respondsToSelector:@selector(isValid)]){
                if ([_heartBeat isValid]){
                    [_heartBeat invalidate];
                    _heartBeat = nil;
                }
            }
        }
    })
}

// 发送心跳
- (void)sendPing {
    if (self.socket.readyState == LXSR_OPEN) {
        NSData *datas = [[NSData alloc] initWithBase64EncodedString:@"#" options:0];
        [self.socket sendPing:datas];
        NSLog(@"socket发送心跳");
    }
}

// 当前socket连接状态
- (LXSRSocketState)socketState{
    return (LXSRSocketState)self.socket.readyState;
}

#pragma mark - 发送消息
- (void)sendData:(id)sendData {
    WeakSelf(self);
    dispatch_queue_t queue =  dispatch_queue_create("zy", NULL);
    
    dispatch_async(queue, ^{
        if (weakself.socket != nil) {
            // 只有 SR_OPEN 开启状态才能调 send 方法啊，不然要崩
            if (weakself.socket.readyState == LXSR_OPEN) {
                [weakself.socket send:sendData];    // 发送数据
                
            } else if (weakself.socket.readyState == LXSR_CONNECTING) {
                NSLog(@"正在连接中，重连后其他方法会去自动同步数据");
                [weakself reConnect:^(LXSRReadyState state) {
                    // 重连成功后发送数据
                    if (state == LXSR_OPEN) {
                        [weakself.socket send:sendData];
                    }
                }];
                
            } else if (weakself.socket.readyState == LXSR_CLOSING || weakself.socket.readyState == LXSR_CLOSED) {
                // websocket 断开了，调用 reConnect 方法重连
                NSLog(@"socket断开重连");
                [weakself reConnect:^(LXSRReadyState state) {
                    // 重连成功后发送数据
                    if (state == LXSR_OPEN) {
                        [weakself.socket send:sendData];
                    }
                }];
            }
        }
    });
}

#pragma mark - 注册监听
-(void)addAppStateNotification{
    
    if (ksystemMoreThanEight) {
        if (@available(iOS 8.2, *)) {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(WillResignActive:) name:NSExtensionHostWillResignActiveNotification object:nil];
        } else {
            // Fallback on earlier versions
        }
        if (@available(iOS 8.2, *)) {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(DidBecomeActive:) name:NSExtensionHostDidBecomeActiveNotification object:nil];
        } else {
            // Fallback on earlier versions
        }
    } else{
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(WillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(DidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkingReachabilityDidChange:) name:LXAFNetworkingReachabilityDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(webSocketNeedReconnectAction:) name:WebSocketNeedReconnectNotification object:nil];
}


/* 进入后台 */
-(void)WillResignActive:(NSNotification *)notification{
    [self.socket closeWithCode:LXSRStatusCodeNormal reason:@"ApplicationWillResignActive"];
}

/* 进入前台 */
-(void)DidBecomeActive:(NSNotification *)notification{
    //判断用户是否在线，如果用户在线，需要重连
    [self reConnect:nil];
    
}

/*
 网络环境发生变化
 有网的时候重连
 没网的时候关闭连接和资源
 */
-(void)networkingReachabilityDidChange:(NSNotification *)notification{
    LXAFNetworkReachabilityStatus status = [notification.userInfo[LXAFNetworkingReachabilityNotificationStatusItem] integerValue];
    if (status == LXAFNetworkReachabilityStatusReachableViaWiFi || status == LXAFNetworkReachabilityStatusReachableViaWWAN) {
        if (self.socket == nil || self.socket.readyState != LXSR_CONNECTING) {
            // 判断用户是否在线，如果用户在线，需要重连, 重置超时时间
            _reConnectTime = 0;
            [self reConnect:nil];
        }
    }else{
        [self close];
    }
}

/* 当需要重连时发送通知 */
-(void)webSocketNeedReconnectAction:(NSNotification *)notification{
    if (self.socket == nil || self.socket.readyState != LXSR_CONNECTING) {
        // 判断用户是否在线，如果用户在线，需要重连
        _reConnectTime = 0;
        [self reConnect:nil];

    }
}

- (void)networkReachabilityStartMonitoring {
    [[LXAFNetworkReachabilityManager sharedManager] startMonitoring];
}

- (void)networkReachabilityStopMonitoring {
    [[LXAFNetworkReachabilityManager sharedManager] stopMonitoring];
}


@end
















