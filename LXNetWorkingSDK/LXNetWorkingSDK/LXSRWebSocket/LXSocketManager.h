//
//  LXSocketManager.h
//  LXNetWorkingSDK
//
//  Created by 华惠友 on 2018/3/20.
//  Copyright © 2018年 华惠友. All rights reserved.
//

/**
    Socket连接
    - 建立该Socket 连接,需要先初始化本单例类
    - 设置Socket 连接完整URL地址
    - 调用connect 建立连接
    - 通过didReceiveMessage 回调收到服务器回复的消息
    - 通过sendData: 发送消息
    - 通过close 断开连接
 
    Socket连接有心跳和重连机制:
    心跳默认为5秒一次
    重连次数为8次, 按2的2次方时间递增
 
    当超过最大重连次数后, 切换网络环境时能够实现重连 则需要实现networkReachabilityStartMonitoring 方法
 */

#import <UIKit/UIKit.h>


/**
 CONNECTING：值为0，表示正在连接。
 OPEN：值为1，表示连接成功，可以通信了。
 CLOSING：值为2，表示连接正在关闭。
 CLOSED：值为3，表示连接已经关闭，或者打开连接失败。
 */
typedef NS_ENUM(NSInteger, LXSRSocketState) {
    LXSRSocket_CONNECTING   = 0,
    LXSRSocket_OPEN         = 1,
    LXSRSocket_CLOSING      = 2,
    LXSRSocket_CLOSED       = 3,
};

/* 如果想要立即重连,发送该通知即可 */
extern NSString *const  WebSocketNeedReconnectNotification;

@interface LXSocketManager : NSObject

/**
 Socket连接完整地址
 协议头://主机地址:端口号?参数1=值1&参数2=值2...
 */
@property (nonatomic, copy) NSString *urlString;


/**
 心跳时间 默认5s
 */
@property (nonatomic, assign) NSTimeInterval heartTime;

/**
 Socket连接状态
 
 0，表示正在连接。
 1，表示连接成功，可以通信了。
 2，表示连接正在关闭。
 3，表示连接已经关闭，或者打开连接失败。
 */
@property (nonatomic, assign) LXSRSocketState socketState;


/**
 socket连接状态回调
 
 @param  socketState    0，表示正在连接。
                        1，表示连接成功，可以通信了。
                        2，表示连接正在关闭。
                        3，表示连接已经关闭，或者打开连接失败。
 */
@property (nonatomic, copy) void (^socketStateBlock)(LXSRSocketState socketState);

/**
 Socket收到的消息
 */
@property (nonatomic, copy) void (^didReceiveMessage)(id message);

/**
 单例实例化

 @return 对象
 */
+ (instancetype)shareInstance;

/**
 开始连接
 */
- (void)connect;

/**
 断开连接
 */
- (void)close;

/**
 发送数据

 @param sendData 发送的数据
 */
- (void)sendData:(id)sendData;

/**
 开始网络监听
 */
- (void)networkReachabilityStartMonitoring;

/**
 停止网络监听
 */
- (void)networkReachabilityStopMonitoring;


@end






